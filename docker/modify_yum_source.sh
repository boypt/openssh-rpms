#!/bin/bash

# Author: Rex Chow
# Modified: 2024-07-08 09:29:45
# Description: This script will modify yum repositories to Tsinghua University mirror.
# Copyright: Copyright © 2024 Rex Zhou. All rights reserved.

RELEASE_VER=$(rpm --eval '%{?dist}')
[ -z "$RELEASE_VER" ] && RELEASE_VER=".el5"

# Cent OS 5 is NOT support modern SSL protocol, so use plain HTTP protocol.
if [ "$RELEASE_VER" != ".el5" ]; then
  if [ "$CHINA_MIRROR" != "0" ]; then
    # Using USTC mirror, which is much useful for Chinese users.
    MIRROR_URL="https://mirrors.ustc.edu.cn/centos-vault";
    AWS_DOMAIN="amazonaws.com.cn"
    AWS_REGION="cn-northwest-1"
  else
    # Default mirror, the official mirror link.
    MIRROR_URL="https://vault.centos.org/";
    AWS_DOMAIN="amazonaws.com"
    AWS_REGION="us-east-2"
  fi
  else
    MIRROR_URL="http://linuxsoft.cern.ch"
fi

# For ARM platform, the mirror url needs a suffix `altarch`
if [ "$(uname -m)" = "aarch64" ]; then
  OS_KEY="altarch"
  if [ "$RELEASE_VER" != ".el8" ]; then
    MIRROR_URL="$MIRROR_URL/$OS_KEY";
  fi
else
  OS_KEY="centos"
fi

function modify_el8() {
  sed -e "s|^mirrorlist=|#mirrorlist=|g" \
      -e "s|^#baseurl=http://mirror.centos.org/\$contentdir/\$releasever|baseurl=${MIRROR_URL}/8.5.2111|g" \
      -i.bak /etc/yum.repos.d/CentOS-*.repo && \
  rm -rf /var/cache/yum/ && \
  yum makecache timer
}

function modify_el7() {
  sed -e 's|^mirrorlist=|#mirrorlist=|g' \
  -e "s@^#baseurl=http://mirror.centos.org/$OS_KEY/\$releasever@baseurl=${MIRROR_URL}/7.9.2009@g" \
  -e "s|^#baseurl=http://mirror.centos.org/\$contentdir/\$releasever|baseurl=${MIRROR_URL}/7.9.2009|g" \
      -i.bak /etc/yum.repos.d/CentOS-*.repo && \
  rm -rf /var/cache/yum/ && \
  yum makecache fast
}

function modify_el6() {
  sed -e "s|^mirrorlist=|#mirrorlist=|g" \
      -e "s|^#baseurl=http://mirror.centos.org/$OS_KEY/\$releasever|baseurl=${MIRROR_URL}/6.10|g" \
      -e "s|^#baseurl=http://mirror.centos.org/\$contentdir/\$releasever|baseurl=${MIRROR_URL}/6.10|g" \
      -i.bak /etc/yum.repos.d/CentOS-*.repo && \
  rm -rf /var/cache/yum/ && \
  yum makecache fast
}

function modify_el5() {
  sed -e "s|^mirrorlist=|#mirrorlist=|g" \
      -e "s|^#baseurl=http://mirror.centos.org/centos/\$releasever|baseurl=${MIRROR_URL}/centos-vault/5.11|g" \
      -e "s|^#baseurl=http://mirror.centos.org/\$contentdir/\$releasever|baseurl=${MIRROR_URL}/centos-vault/5.11|g" \
      -i.bak /etc/yum.repos.d/*.repo && \
  rm -rf /var/cache/yum/ && \
  yum makecache fast
}

case $RELEASE_VER in
  .el8)
    modify_el8
    ;;
  .el7)
    modify_el7
    ;;
  .el6)
    modify_el6
    ;;
  .el5)
    modify_el5
    ;;
  .amzn1)
    echo "$AWS_DOMAIN" > /etc/yum/vars/awsdomain
    echo "$AWS_REGION" > /etc/yum/vars/awsregion
    ;;
  .amzn2)
    echo "$AWS_DOMAIN" > /etc/yum/vars/awsdomain
    echo "$AWS_REGION" > /etc/yum/vars/awsregion
    ;;
  .amzn2023)
    echo "$AWS_DOMAIN" > /etc/dnf/vars/awsdomain
    echo "$AWS_REGION" > /etc/dnf/vars/awsregion
    ;;
  *)
    echo "rpm dist undefined, please specify: el5 el6 el7"
    exit 1
    ;;
esac