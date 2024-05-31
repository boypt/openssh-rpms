#!/bin/bash

# Author: Rex Chow
# Modified: 2024/2/5 08:49
# Description: This script will modify yum repositories to Tsinghua University mirror.
# Copyright: Copyright © 2024 Rex Zhou. All rights reserved.

RELEASE_VER=$(rpm --eval '%{?dist}')
[ -z "$RELEASE_VER" ] && RELEASE_VER=".el5"
MIRROR_URL="http://mirrors.tuna.tsinghua.edu.cn"
AWS_REGION="cn-northwest-1"

case $RELEASE_VER in
  .el8)
    sed -e "s|^mirrorlist=|#mirrorlist=|g" \
        -e "s|^baseurl=https://vault.centos.org|baseurl=${MIRROR_URL}/centos-vault|g" \
        -i.bak /etc/yum.repos.d/CentOS-*.repo && \
    rm -rf /var/cache/yum/ && \
    yum makecache timer
    ;;
  .el7)
    sed -e 's|^mirrorlist=|#mirrorlist=|g' \
        -e "s|^#baseurl=http://mirror.centos.org/centos|baseurl=${MIRROR_URL}/centos|g" \
        -i.bak /etc/yum.repos.d/CentOS-*.repo && \
    rm -rf /var/cache/yum/ && \
    yum makecache fast
    ;;
  .el6)
    sed -e "s|^mirrorlist=|#mirrorlist=|g" \
        -e "s|^#baseurl=http://mirror.centos.org/centos/\$releasever|baseurl=${MIRROR_URL}/centos-vault/6.10|g" \
        -e "s|^#baseurl=http://mirror.centos.org/\$contentdir/\$releasever|baseurl=${MIRROR_URL}/centos-vault/6.10|g" \
        -i.bak /etc/yum.repos.d/CentOS-*.repo && \
    rm -rf /var/cache/yum/ && \
    yum makecache fast
    ;;
  .el5)
    sed -e "s|^mirrorlist=|#mirrorlist=|g" \
        -e "s|^baseurl=http://archive.kernel.org|baseurl=${MIRROR_URL}|g" \
        -i.bak /etc/yum.repos.d/*.repo && \
    rm -rf /var/cache/yum/ && \
    yum makecache fast
    ;;
  .amzn1)
    echo "amazonaws.com.cn" > /etc/yum/vars/awsdomain
    echo "$AWS_REGION" > /etc/yum/vars/awsregion
    ;;
  .amzn2)
    echo "amazonaws.com.cn" > /etc/yum/vars/awsdomain
    echo "$AWS_REGION" > /etc/yum/vars/awsregion
    ;;
  .amzn2023)
    echo "Amazon Linux 2023 is NOT need to change any settings."
    ;;
  *)
    echo "rpm dist undefined, please specify: el5 el6 el7"
    exit 1
    ;;
esac