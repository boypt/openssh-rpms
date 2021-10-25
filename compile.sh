#!/usr/bin/env bash
# Bash3 Boilerplate. Copyright (c) 2014, kvz.io

set -o errexit
set -o pipefail
set -o nounset
# set -o xtrace

trap 'echo -e "Aborted, error $? in command: $BASH_COMMAND"; trap ERR; exit 1' ERR

# Set magic variables for current file & dir
__dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
__file="${__dir}/$(basename "${BASH_SOURCE[0]}")"
__base="$(basename ${__file} .sh)"
__root="$(cd "$(dirname "${__dir}")" && pwd)" # <-- change this as it depends on your app

rpmtopdir="${1:-}"

# trap 'echo Signal caught, cleaning up >&2; cd /tmp; /bin/rm -rfv "$TMP"; exit 15' 1 2 3 15
# allow command fail:
# fail_command || true

if [[ -z $rpmtopdir ]]; then
    VAREL=$(rpm --eval '%{?dist}')
    case $VAREL in
        .el7)
            rpmtopdir=el7
            ;;
        .el6)
            rpmtopdir=el6
            ;;
        .el5)
            rpmtopdir=el5
            ;;
        *)
            echo "rpm dist undefined, please specify: el5 el6 el7"
            exit 1
            ;;
    esac
fi


if [[ ! -d $rpmtopdir ]]; then 
  echo "only work in el5/el6/el7"
  echo "eg: ${0} el7"
  exit 1
fi

source version.env
CHECKEXISTS() {
  if [[ ! -f $__dir/downloads/$1 ]];then
    echo "$1 not found, run 'downloadsrc.sh', or manually put it in the downloads dir."
    exit 1
  fi
}

# on centos5, it's prefered to use gcc44
if yum --disablerepo=* list installed gcc44; then 
  export CC=gcc44
fi

SOURCES=( $OPENSSHSRC \
          $OPENSSLSRC \
          $ASKPASSSRC \
)

pushd $rpmtopdir
for fn in ${SOURCES[@]}; do
  CHECKEXISTS $fn
  install -v -m666 $__dir/downloads/$fn ./SOURCES/
done

rpmbuild -ba SPECS/openssh.spec --target $(uname -m) --define "_topdir $PWD"
popd
