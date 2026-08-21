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
# join_baseurls helper to turn an array + suffix into the "baseurl=..." lines
# that the sed substitutions expect.

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
# EPEL archive mirrors (plain HTTP for all EL, 7/6/5 share)
# shellcheck disable=SC2034
EPEL=(
	"http://archives.fedoraproject.org/pub/archive/epel"
	"http://mirrors.aliyun.com/epel-archive"
	"http://ftp.iij.ad.jp/pub/linux/Fedora/archive/epel"
	"http://mirrors.sindad.cloud/epel-archive"
	"http://ftp.yandex.ru/epel-archive"
	"http://debian.sbor.net/epel-archive"
)

disable_fastestmirror() {
	sed -e 's|enabled=1|enabled=0|' -i /etc/yum/pluginconf.d/fastestmirror.conf 2>/dev/null || true
}

# Join array elements into "baseurl=<mirror><suffix>" lines separated by \n
# (the literal \n is interpreted as a newline by GNU sed in the replacement).
# Usage: join_baseurls <suffix> <array_name>
#   e.g. join_baseurls "/7.9.2009" VAULT
# Uses eval instead of a nameref so it works on bash 4.2 (CentOS 7).
join_baseurls() {
	local suffix="$1"
	local arr_name="$2"
	local arr
	eval "arr=(\"\${${arr_name}[@]}\")"
	local out=""
	local sep=""
	for m in "${arr[@]}"; do
		out+="${sep}baseurl=${m}${suffix}"
		sep="\n"
	done
	printf '%s' "$out"
}

modify_el8() {
	disable_fastestmirror
	local vault
	vault=$(join_baseurls "" VAULT)
	sed -e 's|^mirrorlist=|#mirrorlist=|g' \
		-e "s|^#baseurl=http://mirror.centos.org/\$contentdir|${vault}|g" \
		-i.bak /etc/yum.repos.d/CentOS-*.repo
}

modify_el7() {
	disable_fastestmirror
	local baseurl alturl epelurl
	baseurl=$(join_baseurls "${ALTARCH}/7.9.2009/" VAULT)
	alturl=$(join_baseurls "/altarch/7.9.2009/" VAULT)
	epelurl=$(join_baseurls "/7/" EPEL)
	sed -e '/^mirrorlist=/s|^|#|g' \
		-e "s|^#baseurl=http://mirror.centos.org/centos/\$releasever/|${baseurl}|g" \
		-e "s|^#baseurl=http://mirror.centos.org/altarch/\$releasever/|${alturl}|g" \
		-i.bak /etc/yum.repos.d/CentOS-*.repo
	yum install -y epel-release
	sed -e '/^mirrorlist=/s|^|#|g' \
		-e 's|^metalink|#metalink|' \
		-e "s|^#baseurl=http://download.fedoraproject.org/pub/epel/7/|${epelurl}|g" \
		-i.bak /etc/yum.repos.d/epel*.repo 2>/dev/null || true
	rm -rf /var/cache/yum/
	yum makecache fast
}

modify_el6() {
	disable_fastestmirror
	local baseurl sclo epel
	baseurl=$(join_baseurls "/6.10" VAULT_HTTP)
	sclo=$(join_baseurls "/6.10/sclo" VAULT_HTTP)
	epel=$(join_baseurls "/6/" EPEL)
	sed -e "s|^mirrorlist=|#mirrorlist=|g" \
		-e "s|^#baseurl=http://mirror.centos.org/centos/\$releasever|${baseurl}|g" \
		-e "s|^#baseurl=http://mirror.centos.org/\$contentdir/\$releasever|${baseurl}|g" \
		-i.bak /etc/yum.repos.d/CentOS-*.repo
	yum install -y epel-release centos-release-scl-rh centos-release-scl
	sed -e "s|^mirrorlist=|#mirrorlist=|g" \
		-e 's|^metalink|#metalink|' \
		-e "s|^# *baseurl=http://mirror.centos.org/centos/6/sclo|${sclo}|g" \
		-e "s|^#baseurl=http://download.fedoraproject.org/pub/epel/6/|${epel}|g" \
		-i.bak /etc/yum.repos.d/epel*.repo /etc/yum.repos.d/*scl*.repo 2>/dev/null || true
	rm -rf /var/cache/yum/
	yum makecache fast
}

modify_el5() {
	disable_fastestmirror
	local baseurl epel
	baseurl=$(join_baseurls "/5.11" VAULT_HTTP)
	epel=$(join_baseurls "/5/\$basearch" EPEL)
	sed -e "s|^mirrorlist=|#mirrorlist=|g" \
		-e "s|^#baseurl=http://mirror.centos.org/centos/\$releasever|${baseurl}|g" \
		-e "s|^#baseurl=http://mirror.centos.org/\$contentdir/\$releasever|${baseurl}|g" \
		-i.bak /etc/yum.repos.d/*.repo
	yum install -y epel-release
	sed -e "/^mirrorlist/s|^|#|g" \
		-e 's|^metalink|#metalink|' \
		-e "s|^#baseurl=.\+\$|${epel}|g" \
		-i.bak /etc/yum.repos.d/epel*.repo 2>/dev/null || true
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
