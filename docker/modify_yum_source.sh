#!/bin/bash
# Mirror switching for CentOS 5/6/7 yum repositories.
# Set MIRROR=0 to use official mirrors, otherwise use Chinese mirrors (default).

RELEASE_VER=$(rpm --eval '%{?dist}')
[ -z "$RELEASE_VER" ] && RELEASE_VER=".el5"

# aarch64 builds use the altarch (CentOS AltArch) vault tree
ALTARCH=""
[ "$(uname -m)" = "aarch64" ] && ALTARCH="/altarch"

# CentOS 5 does not support HTTPS, always use archive.kernel.org over HTTP
if [ "$RELEASE_VER" != ".el5" ]; then
    if [ "$MIRROR" != "0" ]; then
        CENTOS_MIRROR="https://mirrors.ustc.edu.cn/centos-vault"
        EPEL_MIRROR="http://mirrors.aliyun.com/epel-archive"
    else
        CENTOS_MIRROR="https://archive.kernel.org/centos-vault"
        EPEL_MIRROR="http://archives.fedoraproject.org/pub/archive/epel"
    fi
else
    # EL5 Python 2.4 cannot handle HTTPS redirects, use HTTP mirrors only
    if [ "$MIRROR" != "0" ]; then
        CENTOS_MIRROR="http://archive.kernel.org/centos-vault"
        EPEL_MIRROR="http://mirrors.aliyun.com/epel-archive"
    else
        CENTOS_MIRROR="http://archive.kernel.org/centos-vault"
        EPEL_MIRROR="http://mirrors.aliyun.com/epel-archive"
    fi
fi

disable_fastestmirror() {
    sed -e 's|enabled=1|enabled=0|' -i /etc/yum/pluginconf.d/fastestmirror.conf 2>/dev/null || true
}

modify_el7() {
    disable_fastestmirror
    sed -e '/^mirrorlist=/s|^|#|g' \
        -e "s|^#baseurl=http://mirror.centos.org/centos/\$releasever/|baseurl=${CENTOS_MIRROR}${ALTARCH}/7.9.2009/|g" \
        -i.bak /etc/yum.repos.d/CentOS-*.repo
    yum install -y epel-release
    sed -e '/^mirrorlist=/s|^|#|g' \
        -e 's|^metalink|#metalink|' \
        -e "s|^#baseurl=http://download.fedoraproject.org/pub/epel/7/|baseurl=${EPEL_MIRROR}/7/|g" \
        -i.bak /etc/yum.repos.d/epel*.repo
    rm -rf /var/cache/yum/
    yum makecache fast
}

modify_el6() {
    disable_fastestmirror
    sed -e "s|^mirrorlist=|#mirrorlist=|g" \
        -e "s|^#baseurl=http://mirror.centos.org/centos/\$releasever|baseurl=${CENTOS_MIRROR}/6.10|g" \
        -e "s|^#baseurl=http://mirror.centos.org/\$contentdir/\$releasever|baseurl=${CENTOS_MIRROR}/6.10|g" \
        -i.bak /etc/yum.repos.d/CentOS-*.repo
    yum install -y epel-release centos-release-scl-rh centos-release-scl
    sed -e "s|^mirrorlist=|#mirrorlist=|g" \
        -e 's|^metalink|#metalink|' \
        -e "s|^# *baseurl=http://mirror.centos.org/centos/6/sclo|baseurl=${CENTOS_MIRROR}/6.10/sclo|g" \
        -e "s|^#baseurl=http://download.fedoraproject.org/pub/epel/6/|baseurl=${EPEL_MIRROR}/6/|g" \
        -i.bak /etc/yum.repos.d/epel*.repo /etc/yum.repos.d/*scl*.repo
    rm -rf /var/cache/yum/
    yum makecache fast
}

modify_el5() {
    disable_fastestmirror
    sed -e "s|^mirrorlist=|#mirrorlist=|g" \
        -e "s|^#baseurl=http://mirror.centos.org/centos/\$releasever|baseurl=${CENTOS_MIRROR}/5.11|g" \
        -e "s|^#baseurl=http://mirror.centos.org/\$contentdir/\$releasever|baseurl=${CENTOS_MIRROR}/5.11|g" \
        -i.bak /etc/yum.repos.d/*.repo
    yum install -y epel-release
    sed -e "/^mirrorlist/s|^|#|g" \
        -e 's|^metalink|#metalink|' \
        -e "s|^#baseurl=.\+\$|baseurl=${EPEL_MIRROR}/5/\$basearch|g" \
        -i.bak /etc/yum.repos.d/epel*.repo
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