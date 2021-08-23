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

reldir="${1:-}"

# trap 'echo Signal caught, cleaning up >&2; cd /tmp; /bin/rm -rfv "$TMP"; exit 15' 1 2 3 15
# allow command fail:
# fail_command || true

if [[ ! -d $reldir ]]; then 
	echo "only work in el5/el6/el7"
	echo "eg: ${0} el7"
	exit 1
fi

source version.env

NPROC=2
if command -v nproc &> /dev/null; then NPROC=$(nproc); fi

SSLSRC="openssl-${OPENSSLVER}.tar.gz"
SSLDIR=
COMPILE_SSL() {
  if [[ ! -f $SSLSRC ]]; then 
	  echo "no ssl src"
	  exit 1
  fi
  local _ssldir=$(tar tf "$__dir/$SSLSRC"| head -n1) || true
  local _ssldir=${_ssldir%/}
  tar xfz "$__dir/$SSLSRC" -C $__dir/$reldir/SOURCES/
  SSLDIR=$__dir/$reldir/SOURCES/$_ssldir
  pushd $SSLDIR
  ./config shared zlib -fPIC
  make -j${NPROC}
  popd
}

COMPILE_SSL


#----------------COMPILE-------------
SSHSRC="openssh-${OPENSSHVER}.tar.gz"
if [[ -f $SSHSRC ]]; then
  rm -f $reldir/SOURCES/$SSHSRC || true
  ln -s $__dir/$SSHSRC $reldir/SOURCES/
fi

pushd $reldir
mkdir -p SOURCES SPECS BUILD SRPMS RPMS
popd
rpmbuild -ba $reldir/SPECS/openssh.spec --define "_topdir $__dir/$reldir" --define "openssl_dir $SSLDIR"

