#!/bin/bash

# Author: Rex Chow
# Modified: 2024-07-08 09:29:45
# Description: This script will modify yum repositories to Tsinghua University mirror.
# Copyright: Copyright © 2024 Rex Zhou. All rights reserved.

RELEASE_VER=$(rpm --eval '%{?dist}')
[ -z "$RELEASE_VER" ] && RELEASE_VER=".el5"

function modify_el() {
  if [ "$MIRROR" != "0" ]; then
    # Using 163 mirror, which is much useful for Chinese users.
    MIRROR_URL="mirrors.163.com/centos-vault";
  else
    # Default mirror, the nsc mirror link.
    MIRROR_URL="mirror.nsc.liu.se/centos-store";
  fi

  sed -e "s|mirror.nsc.liu.se/centos-store|${MIRROR_URL}|g" \
      /etc/yum.repos.d/CentOS-*.repo && \
  rm -rf /var/cache/yum/ && \
  yum makecache
}

function modify_amzn() {
  if [ "$MIRROR" != "0" ]; then
    # Using USTC mirror, which is much useful for Chinese users.
    AWS_DOMAIN="amazonaws.com.cn"
    AWS_REGION="cn-northwest-1"
  else
    # Default mirror, the official mirror link.
    AWS_DOMAIN="amazonaws.com"
    AWS_REGION="us-east-2"
  fi

  [ -d /etc/yum/vars ] && echo "$AWS_DOMAIN" > /etc/yum/vars/awsdomain && echo "$AWS_REGION" > /etc/yum/vars/awsregion
  [ -d /etc/dnf/vars ] && echo "$AWS_DOMAIN" > /etc/dnf/vars/awsdomain && echo "$AWS_REGION" > /etc/dnf/vars/awsregion
}

case $RELEASE_VER in
  .el*)
    modify_el
    ;;
  .amzn*)
    modify_amzn
    ;;
  *)
    echo "rpm dist undefined, please specify: el5 el6 el7 el8"
    exit 1
    ;;
esac