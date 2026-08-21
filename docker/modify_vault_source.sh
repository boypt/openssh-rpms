#!/bin/bash
# Rewrite yum repository baseurls to use multiple (failover) mirrors.
# yum/dnf try each baseurl in order, so listing several provides resilience.
# EL5/EL6 use plain HTTP mirrors only (Python 2.4 / old curl cannot handle
# HTTPS redirects); EL7/EL8 keep HTTPS mirrors. EL8-stream is also EOL and lives
# in the vault, so it is handled here too. EL7 and EL8 share the VAULT array
# (yandex has no altarch tree, but the earlier failover mirrors cover aarch64).
# VAULT is ordered official-first (the canonical CentOS vault, then the kernel.org
# archive) so GitHub CI uses the canonical source; the remaining mirrors are
# failover only. Only EL5/EL6 fall back to VAULT_HTTP (plain HTTP) due to the
# Python 2.4 TLS limitation; EL7/EL8 always use the HTTPS VAULT array.
# EPEL archive mirrors (EPEL array) are plain HTTP and shared by EL7/EL6/EL5.
#
# Mirror base URLs are kept in the arrays below (no version suffix, no trailing
# slash) so they are easy to add/remove when a mirror goes stale. Use the
# join_baseurls / rewrite_baseurls helpers to turn an array + suffix into a
# SINGLE "baseurl=<url1> <url2> ..." line (DNF 4.x `baseurl` is `list` type:
# space-separated URLs on ONE line; repeated `baseurl=` keys overwrite — only
# the last survives — see dnf.readthedocs.io/conf_ref.html. YUM also accepts
# this form.)

RELEASE_VER=$(rpm --eval '%{?dist}')
[ -z "$RELEASE_VER" ] && RELEASE_VER=".el5"

# aarch64 builds use the altarch (CentOS AltArch) vault tree
ALTARCH=""
[ "$(uname -m)" = "aarch64" ] && ALTARCH="/altarch"

# CentOS vault mirrors - official-first HTTPS, shared by el7/el7-altarch/el8
# Criteria: hosts 7.9.2009, altarch/7.9.2009 (aarch64) and 8-stream; HTTPS valid
# (cert OK, no forced http->https 302, good for GitHub CI TLS); official priority
# (canonical CentOS vault, then kernel.org archive)
# shellcheck disable=SC2034
VAULT=(
	"https://vault.centos.org"
	"https://archive.kernel.org/centos-vault"
	"https://mirrors.aliyun.com/centos-vault"
	"https://ftp.iij.ad.jp/pub/linux/centos-vault"
)
# CentOS vault mirrors - plain HTTP for EL5/6 (hosts 5.11, 6.10 and 6.10/sclo;
# http only, no forced https redirect, avoids EL5 Python 2.4 / old curl TLS 1.0 failure)
# shellcheck disable=SC2034
VAULT_HTTP=(
	"http://ftp.iij.ad.jp/pub/linux/centos-vault"
	"http://mirrors.aliyun.com/centos-vault"
	"http://ftp.yandex.ru/centos"
	"http://ftp.pasteur.fr/mirrors/centos-vault"
)
# EPEL archive mirrors (plain HTTP for all EL, 7/6/5 share).
# archives.fedoraproject.org is excluded: it 302-redirects http->https, which
# EL5 Python 2.4 / M2Crypto cannot follow (uncaught SSLError aborts yum before
# mirror failover). All remaining mirrors serve plain HTTP without redirect.
# shellcheck disable=SC2034
EPEL=(
	"http://mirrors.aliyun.com/epel-archive"
	"http://ftp.iij.ad.jp/pub/linux/Fedora/archive/epel"
	"http://mirrors.sindad.cloud/epel-archive"
	"http://ftp.yandex.ru/epel-archive"
	"http://debian.sbor.net/epel-archive"
)

disable_fastestmirror() {
	sed -e 's|enabled=1|enabled=0|' -i /etc/yum/pluginconf.d/fastestmirror.conf 2>/dev/null || true
}

# Join array elements into a SINGLE "baseurl=<url1> <url2> ..." line
# (DNF 4.x `baseurl` is `list` type: space-or-comma-separated on ONE line;
# repeated `baseurl=` keys overwrite — only the last survives — see
# dnf.readthedocs.io/conf_ref.html. YUM also accepts this form.)
# Usage: join_baseurls <suffix> <array_name>
#   e.g. join_baseurls "/7.9.2009" VAULT
# Uses eval instead of a nameref so it works on bash 4.2 (CentOS 7).
join_baseurls() {
	local suffix="$1"
	local arr_name="$2"
	local arr
	eval "arr=(\"\${${arr_name}[@]}\")"
	local out="baseurl="
	local sep=""
	for m in "${arr[@]}"; do
		out+="${sep}${m}${suffix}"
		sep=" "
	done
	printf '%s' "$out"
}

# For every "baseurl=<prefix>..." line (whatever its content or comment
# format): comment the original line out by prepending "#", then add our own
# SINGLE active "baseurl=<url1> <url2> ..." line right below it. This makes
# the rewrite independent of how the repo file wrote the line ("#baseurl=",
# "# baseurl=", or an active "baseurl="). DNF 4.x `baseurl` is `list` type:
# space-separated URLs on ONE line; repeated `baseurl=` keys overwrite — only
# the last survives — so our added line wins (see dnf.readthedocs.io/
# conf_ref.html. YUM also accepts this form). Each added URL keeps the
# remainder after <prefix>; <suffix> is inserted between mirror and remainder
# (e.g. the vault version). Works on bash 3.2 (el5).
# Usage: rewrite_baseurls <glob> <prefix> <suffix> <array_name>
#   e.g. rewrite_baseurls "/etc/yum.repos.d/CentOS-*.repo" \
#        "http://mirror.centos.org/\$contentdir" "" VAULT
rewrite_baseurls() {
	local glob="$1" prefix="$2" suffix="$3" arr_name="$4"
	local arr out line rest m file urls sep
	eval "arr=(\"\${${arr_name}[@]}\")"
	for file in $glob; do
		out=""
		while IFS= read -r line || [ -n "$line" ]; do
			if [[ $line == *"baseurl=$prefix"* ]]; then
				rest="${line##*"$prefix"}"
				urls=""
				sep=""
				for m in "${arr[@]}"; do
					urls+="${sep}${m}${suffix}${rest}"
					sep=" "
				done
				out+="#${line}\nbaseurl=${urls}\n"
			else
				out+="$line\n"
			fi
		done <"$file"
		printf '%b' "$out" >"$file"
	done
}

modify_el8() {
	disable_fastestmirror
	sed -e 's|^mirrorlist=|#mirrorlist=|g' \
		-e 's|^metalink|#metalink|' \
		-i.bak /etc/yum.repos.d/CentOS-*.repo
	# EL8 GA repos use "$contentdir/$releasever" and EL8-stream repos use
	# "$contentdir/$stream"; the remainder after the prefix (which contains
	# $releasever or $stream) is preserved, so one rewrite covers both. Emits a
	# single baseurl= line with space-separated URLs (DNF `list` type).
	rewrite_baseurls "/etc/yum.repos.d/CentOS-*.repo" "http://mirror.centos.org/\$contentdir" "" VAULT
}

modify_el7() {
	disable_fastestmirror
	sed -e '/^mirrorlist=/s|^|#|g' \
		-e 's|^metalink|#metalink|' \
		-i.bak /etc/yum.repos.d/CentOS-*.repo
	rewrite_baseurls "/etc/yum.repos.d/CentOS-*.repo" "http://mirror.centos.org/centos/\$releasever" "${ALTARCH}/7.9.2009" VAULT
	rewrite_baseurls "/etc/yum.repos.d/CentOS-*.repo" "http://mirror.centos.org/altarch/\$releasever" "/altarch/7.9.2009" VAULT
	yum install -y epel-release
	sed -e '/^mirrorlist=/s|^|#|g' \
		-e 's|^metalink|#metalink|' \
		-i.bak /etc/yum.repos.d/epel*.repo 2>/dev/null || true
	rewrite_baseurls "/etc/yum.repos.d/epel*.repo" "http://download.fedoraproject.org/pub/epel/7" "/7" EPEL
	rm -rf /var/cache/yum/
	yum makecache fast
}

modify_el6() {
	disable_fastestmirror
	sed -e "s|^mirrorlist=|#mirrorlist=|g" \
		-e 's|^metalink|#metalink|' \
		-i.bak /etc/yum.repos.d/CentOS-*.repo
	rewrite_baseurls "/etc/yum.repos.d/CentOS-*.repo" "http://mirror.centos.org/centos/\$releasever" "/6.10" VAULT_HTTP
	rewrite_baseurls "/etc/yum.repos.d/CentOS-*.repo" "http://mirror.centos.org/\$contentdir/\$releasever" "/6.10" VAULT_HTTP
	yum install -y epel-release centos-release-scl-rh centos-release-scl
	sed -e "s|^mirrorlist=|#mirrorlist=|g" \
		-e 's|^metalink|#metalink|' \
		-i.bak /etc/yum.repos.d/epel*.repo /etc/yum.repos.d/*scl*.repo 2>/dev/null || true
	rewrite_baseurls "/etc/yum.repos.d/*scl*.repo" "http://mirror.centos.org/centos/6/sclo" "/6.10/sclo" VAULT_HTTP
	rewrite_baseurls "/etc/yum.repos.d/epel*.repo" "http://download.fedoraproject.org/pub/epel/6" "/6" EPEL
	rm -rf /var/cache/yum/
	yum makecache fast
}

modify_el5() {
	disable_fastestmirror
	sed -e "s|^mirrorlist=|#mirrorlist=|g" \
		-e 's|^metalink|#metalink|' \
		-i.bak /etc/yum.repos.d/*.repo
	rewrite_baseurls "/etc/yum.repos.d/*.repo" "http://mirror.centos.org/centos/\$releasever" "/5.11" VAULT_HTTP
	rewrite_baseurls "/etc/yum.repos.d/*.repo" "http://mirror.centos.org/\$contentdir/\$releasever" "/5.11" VAULT_HTTP
	yum install -y epel-release
	sed -e "/^mirrorlist/s|^|#|g" \
		-e 's|^metalink|#metalink|' \
		-i.bak /etc/yum.repos.d/epel*.repo 2>/dev/null || true
	rewrite_baseurls "/etc/yum.repos.d/epel*.repo" "http://download.fedoraproject.org/pub/epel/5" "/5" EPEL
	rm -rf /var/cache/yum/
	yum makecache
}

case $RELEASE_VER in
	.el7)
		modify_el7
		;;
	.el6)
		modify_el6
		;;
	.el5)
		modify_el5
		;;
	.el8)
		modify_el8
		;;
	*)
		echo "Unsupported dist: $RELEASE_VER, expected el5/el6/el7/el8"
		exit 1
		;;
esac
