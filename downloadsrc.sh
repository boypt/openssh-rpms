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

arg1="${1:-}"

# trap 'echo Signal caught, cleaning up >&2; cd /tmp; /bin/rm -rfv "$TMP"; exit 15' 1 2 3 15
# allow command fail:
# fail_command || true

source version.env	

mkdir -p downloads
pushd downloads
if [[ ! -f $OPENSSLSRC ]]; then
  wget https://www.openssl.org/source/openssl-${OPENSSLVER}.tar.gz
fi

if [[ ! -f $OPENSSHSRC  ]]; then
  wget https://cdn.openbsd.org/pub/OpenBSD/OpenSSH/portable/openssh-${OPENSSHVER}.tar.gz
fi

