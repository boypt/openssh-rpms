#!/bin/bash
# Rewrite yum repository baseurls to use multiple (failover) mirrors.
# yum/dnf try each baseurl in order, so listing several provides resilience.
# EL5/EL6 use plain HTTP mirrors only (Python 2.4 / old curl cannot handle
# HTTPS redirects); EL7 keeps HTTPS mirrors.

RELEASE_VER=$(rpm --eval '%{?dist}')
[ -z "$RELEASE_VER" ] && RELEASE_VER=".el5"

# aarch64 builds use the altarch (CentOS AltArch) vault tree
ALTARCH=""
[ "$(uname -m)" = "aarch64" ] && ALTARCH="/altarch"

disable_fastestmirror() {
	sed -e 's|enabled=1|enabled=0|' -i /etc/yum/pluginconf.d/fastestmirror.conf 2>/dev/null || true
}

modify_el7() {
	disable_fastestmirror
	local baseurl="baseurl=https://archive.kernel.org/centos-vault${ALTARCH}/7.9.2009/\nbaseurl=https://mirrors.ustc.edu.cn/centos-vault${ALTARCH}/7.9.2009/"
	local alturl="baseurl=https://archive.kernel.org/centos-vault/altarch/7.9.2009/\nbaseurl=https://mirrors.ustc.edu.cn/centos-vault/altarch/7.9.2009/"
	local epelurl="baseurl=http://archives.fedoraproject.org/pub/archive/epel/7/\nbaseurl=http://mirrors.aliyun.com/epel-archive/7/"
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
	local baseurl="baseurl=http://ftp.iij.ad.jp/pub/linux/centos-vault/6.10\nbaseurl=http://mirrors.aliyun.com/centos-vault/6.10\nbaseurl=http://ftp.yandex.ru/centos/6.10\nbaseurl=http://ftp.pasteur.fr/mirrors/centos-vault/6.10"
	local sclourl="baseurl=http://ftp.iij.ad.jp/pub/linux/centos-vault/6.10/sclo\nbaseurl=http://mirrors.aliyun.com/centos-vault/6.10/sclo\nbaseurl=http://ftp.yandex.ru/centos/6.10/sclo\nbaseurl=http://ftp.pasteur.fr/mirrors/centos-vault/6.10/sclo"
	local epelurl="baseurl=http://mirrors.aliyun.com/epel-archive/6/\nbaseurl=http://ftp.iij.ad.jp/pub/linux/Fedora/archive/epel/6/\nbaseurl=http://mirrors.sindad.cloud/epel-archive/6/\nbaseurl=http://ftp.yandex.ru/epel-archive/6/\nbaseurl=http://debian.sbor.net/epel-archive/6/"
	sed -e "s|^mirrorlist=|#mirrorlist=|g" \
		-e "s|^#baseurl=http://mirror.centos.org/centos/\$releasever|${baseurl}|g" \
		-e "s|^#baseurl=http://mirror.centos.org/\$contentdir/\$releasever|${baseurl}|g" \
		-i.bak /etc/yum.repos.d/CentOS-*.repo
	yum install -y epel-release centos-release-scl-rh centos-release-scl
	sed -e "s|^mirrorlist=|#mirrorlist=|g" \
		-e 's|^metalink|#metalink|' \
		-e "s|^# *baseurl=http://mirror.centos.org/centos/6/sclo|${sclourl}|g" \
		-e "s|^#baseurl=http://download.fedoraproject.org/pub/epel/6/|${epelurl}|g" \
		-i.bak /etc/yum.repos.d/epel*.repo /etc/yum.repos.d/*scl*.repo 2>/dev/null || true
	rm -rf /var/cache/yum/
	yum makecache fast
}

modify_el5() {
	disable_fastestmirror
	local baseurl="baseurl=http://ftp.iij.ad.jp/pub/linux/centos-vault/5.11\nbaseurl=http://mirrors.aliyun.com/centos-vault/5.11\nbaseurl=http://ftp.yandex.ru/centos/5.11\nbaseurl=http://ftp.pasteur.fr/mirrors/centos-vault/5.11"
	local epelurl="baseurl=http://mirrors.aliyun.com/epel-archive/5/\$basearch\nbaseurl=http://ftp.iij.ad.jp/pub/linux/Fedora/archive/epel/5/\$basearch\nbaseurl=http://mirrors.sindad.cloud/epel-archive/5/\$basearch\nbaseurl=http://ftp.yandex.ru/epel-archive/5/\$basearch\nbaseurl=http://debian.sbor.net/epel-archive/5/\$basearch"
	sed -e "s|^mirrorlist=|#mirrorlist=|g" \
		-e "s|^#baseurl=http://mirror.centos.org/centos/\$releasever|${baseurl}|g" \
		-e "s|^#baseurl=http://mirror.centos.org/\$contentdir/\$releasever|${baseurl}|g" \
		-i.bak /etc/yum.repos.d/*.repo
	yum install -y epel-release
	sed -e "/^mirrorlist/s|^|#|g" \
		-e 's|^metalink|#metalink|' \
		-e "s|^#baseurl=.\+\$|${epelurl}|g" \
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
	*)
		echo "Unsupported dist: $RELEASE_VER, expected el5/el6/el7"
		exit 1
		;;
esac
