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
rpmtopdir=

# WITH_OPENSSL=
# Control openssl dependency
# 0: build without openssl
# 1: use system openssl
# 2: build openssl statically

CHECKEXISTS() {
  if [[ ! -f $__dir/downloads/$1 ]];then
    echo "$1 not found, run 'pullsrc.sh', or manually put it in the downloads dir."
    exit 1
  fi
}


GUESS_DIST() {
    # will not work if rpm cmd not exists
    if ! type -p rpm > /dev/null;then
      echo 'unknown' && return 0
    fi

    local dist=$(rpm --eval '%{?dist}' | tr -d '.')

    # fallback to el7
    [[ $dist == "el9" ]] && dist="el8"
    [[ $dist == "el8" ]] && dist="el8"
    [[ $dist == "an8" ]] && dist="el8" # Anolis 8
    [[ $dist == "an7" ]] && dist="el7" # Anolis 7
    [[ $dist == uel* ]] && dist="el8"  # UOS20+

    [[ -n $dist ]] && echo $dist && return 0

    local glibcver=$(ldd --version | head -n1 | grep -Eo '[0-9]+' | tr -d '\n')

    # centos 5 uses glibc 2.5
    [[ $glibcver -eq 25 ]] && echo 'el5' && return 0

    # centos 6 uses glibc 2.12
    [[ $glibcver -eq 212 ]] && echo 'el6' && return 0

    # centos 7 uses glibc 2.17
    [[ $glibcver -eq 217 ]] && echo 'el7' && return 0

    # centos 8 uses glibc 2.28, not yet to be in a seprate dir
    [[ $glibcver -eq 228 ]] && echo 'el8' && return 0

    # some centos-like dists ships higher version of glibc, fallback to el7
    [[ $glibcver -gt 217 ]] && echo 'el8' && return 0
}

TOPDIR_SELECT() {
    local DISTVER=$(GUESS_DIST)
    case $DISTVER in
        el8)
            rpmtopdir=el7
            WITH_OPENSSL=${WITH_OPENSSL:-1}
            ;;
        el7)
            rpmtopdir=el7
            WITH_OPENSSL=${WITH_OPENSSL:-2}
            ;;
        el6)
            rpmtopdir=el6
            WITH_OPENSSL=${WITH_OPENSSL:-2}
            ;;
        el5)
            rpmtopdir=el5
            WITH_OPENSSL=${WITH_OPENSSL:-2}
            ;;
        *)
            echo "Distro undefined, please specify manually: el5 el6 el7"
            echo -e "\nCurrent OS:"
            [[ -f /etc/os-release ]] && cat /etc/os-release
            [[ -f /etc/redhat-release ]] && cat /etc/redhat-release 
            [[ -f /etc/system-release ]] && cat /etc/system-release
            echo -e "Current OS vendor: $(rpm --eval '%{?_vendor}') \n"
            return 1
            ;;
    esac
}

BUILD_RPM() {

    source version.env
    [[ -f version-local.env ]] && source version-local.env

    local SOURCES=( $OPENSSHSRC \
          $OPENSSLSRC \
          $ASKPASSSRC \
        )
    local RPMBUILDOPTS=( \
        --define "with_openssl ${WITH_OPENSSL:-2}" \
        --define "opensslver ${OPENSSLVER}" \
        --define "opensshver ${OPENSSHVER}" \
        --define "opensshpkgrel ${PKGREL:-1}" \
        --define 'debug_package %{nil}' \
        --define 'no_gtk2 1' \
        --define 'skip_gnome_askpass 1' \
        --define 'skip_x11_askpass 1' \
        )

    # EL5 dist fixes
    if [[ $rpmtopdir == *el5 ]]; then
        SOURCES+=($PERLSRC)

        # Hack: fake the perl src when perl is ready already(docker images)
        [[ $(perl -e 'print $] >= 5.010 ? 1 : 0') -eq 1 ]] && \
    	    touch ./downloads/$PERLSRC
    
        RPMBUILDOPTS+=('--define' "perlver ${PERLVER}" '--define' 'dist .el5')
        export CC=gcc44
    fi

    # add dist variable if not defined
    [[ $rpmtopdir == *el7 ]] && [[ -z $(rpm --eval '%{?dist}') ]] && \
         RPMBUILDOPTS+=('--define' "dist .$(rpm -q glibc | rev | cut -d. -f2 | rev)")

    pushd $rpmtopdir
    RPMBUILDOPTS+=('--define' "_topdir $PWD")
    for fn in ${SOURCES[@]}; do
      CHECKEXISTS $fn && \
        install -v -m666 $__dir/downloads/$fn ./SOURCES/
    done

    if [[ ${M32:-0} != 0 ]]; then
        local SETARCH="setarch i386"
        RPMBUILDOPTS+=('--target' i686)
        export CFLAGS=-m32 LDFLAGS=-m32
    fi

    ${SETARCH:-} \
    rpmbuild -bb ./SPECS/${SPECFILE:-openssh.spec} "${RPMBUILDOPTS[@]}"
    
    if [[ $? -ne 0 ]]; then
        echo "Error: rpmbuild failed with exit code $?"
        exit 1
    fi

    mkdir -p $__dir/output
    find ./RPMS -type f -name '*.rpm' -exec install -v -m644 {} $__dir/output/ \;
    popd
}

LIST_RPMDIR(){
    local RPMDIR=$__dir/${rpmtopdir}/RPMS/$(rpm --eval '%{_arch}')
    [[ -d $RPMDIR ]] && echo $RPMDIR
}

LIST_RPMS() {
    local RPMDIR=$(LIST_RPMDIR)
    [[ -d $RPMDIR ]] && find $RPMDIR -type f -name '*.rpm'
}

# sub cmds
case $arg1 in
    GETEL)
        GUESS_DIST
        exit 0
        ;;
    GETRPM)
        TOPDIR_SELECT
        LIST_RPMS
        exit 0
        ;;
    RPMDIR)
        TOPDIR_SELECT
        LIST_RPMDIR
        exit 0
        ;;
    *)
        if [[ -n $arg1 && ! -d $arg1 ]]; then
            echo -e "Subcmd: $arg1 not found.\n GETEL, GETRPM, RPMDIR"
            exit 1
        fi
        ;;
esac

# manual specified dist
if [[ -n $arg1 && -d $arg1 ]]; then
    rpmtopdir=$arg1
    BUILD_RPM
    exit 0
fi

# auto select dist
TOPDIR_SELECT
if [[ ! -d $rpmtopdir ]]; then 
  echo "This script works only in el5/el6/el7"
  echo "eg: ${0} el7"
  exit 1
fi

if [[ -d $rpmtopdir ]]; then
    BUILD_RPM
fi
