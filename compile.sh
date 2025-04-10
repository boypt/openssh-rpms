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

# trap 'echo Signal caught, cleaning up >&2; cd /tmp; /bin/rm -rfv "$TMP"; exit 15' 1 2 3 15
# allow command fail:
# fail_command || true
#

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
	[[ $dist == "el9" ]] && dist="el7"
	[[ $dist == "el8" ]] && dist="el7"
	[[ $dist == "an7" ]] && dist="el7"
	[[ $dist == "an8" ]] && dist="el7"


        [[ -n $dist ]] && echo $dist && return 0

	local glibcver=$(ldd --version | head -n1 | grep -Eo '[0-9]+' | tr -d '\n')

	# centos 5 uses glibc 2.5
	[[ $glibcver -eq 25 ]] && echo 'el5' && return 0

	# centos 6 uses glibc 2.12
	[[ $glibcver -eq 212 ]] && echo 'el6' && return 0

	# centos 7 uses glibc 2.17
	[[ $glibcver -eq 217 ]] && echo 'el7' && return 0

	# centos 8 uses glibc 2.28, not yet to be in a seprate dir
	#[[ $glibcver -eq 228 ]] && echo 'el8' && return 0

	# some centos-like dists ships higher version of glibc, fallback to el7
	[[ $glibcver -gt 217 ]] && echo 'el7' && return 0
}

BUILD_RPM() {

	source version.env
	local SOURCES=( $OPENSSHSRC \
		  $OPENSSLSRC \
		  $ASKPASSSRC \
		)
	local RPMBUILDOPTS=( \
		--define "opensslver ${OPENSSLVER}" \
		--define "opensshver ${OPENSSHVER}" \
		--define "opensshpkgrel ${PKGREL}" \
		--define 'no_gtk2 1' \
		--define 'skip_gnome_askpass 1' \
		--define 'skip_x11_askpass 1' \
		)

	# only on EL5, perl source is needed.
	[[ $rpmtopdir == "el5" ]] && \
		SOURCES+=($PERLSRC) && \
		RPMBUILDOPTS+=('--define' "perlver ${PERLVER}"
			       '--define' 'dist .el5')

	# add dist variable if not defined
	[[ $rpmtopdir == "el7" ]] && \
		[[ -z $(rpm --eval '%{?dist}') ]] && \
	 	RPMBUILDOPTS+=('--define' "dist .$(rpm -q glibc | rev | cut -d. -f2 | rev)")

	pushd $rpmtopdir
	RPMBUILDOPTS+=('--define' "_topdir $PWD")
	for fn in ${SOURCES[@]}; do
	  CHECKEXISTS $fn && \
	    install -v -m666 $__dir/downloads/$fn ./SOURCES/
	done
	rpmbuild -ba ./SPECS/openssh.spec "${RPMBUILDOPTS[@]}"
	popd
}

LIST_RPMDIR(){
    local DISTVER=$(GUESS_DIST)
    local RPMDIR=$__dir/$(GUESS_DIST)/RPMS/$(rpm --eval '%{_arch}')
    [[ -d $RPMDIR ]] && echo $RPMDIR
}

LIST_RPMS() {
    local RPMDIR=$(LIST_RPMDIR)
    [[ -d $RPMDIR ]] && find $RPMDIR -type f -name '*.rpm' ! -name '*debug*'
}

# sub cmds
case $arg1 in
	GETEL)
		GUESS_DIST && exit 0
		;;
	GETRPM)
		LIST_RPMS && exit 0
		;;
	RPMDIR)
		LIST_RPMDIR && exit 0
		;;
esac


# manual specified dist
[[ -n $arg1 && -d $__dir/$arg1 ]] && rpmtopdir=$arg1 && BUILD_RPM && exit 0

# auto detect distro
if [[ -z $arg1 ]]; then
    DISTVER=$(GUESS_DIST)
    case $DISTVER in
        amzn1)
            rpmtopdir=amzn1
            ;;
        amzn2)
            rpmtopdir=amzn2
            ;;
        amzn2023)
            rpmtopdir=amzn2023
            ;;
        el7)
            rpmtopdir=el7
            ;;
        el6)
            rpmtopdir=el6
            ;;
        el5)
            rpmtopdir=el5
            # on centos5, it's prefered to use gcc44
	    rpm -q gcc44 && export CC=gcc44
            ;;
        *)
            echo "Distro undefined, please specify manually: el5 el6 el7 amzn1 amzn2 amzn2023"
	    echo -e "\nCurrent OS:"
	    [[ -f /etc/os-release ]] && cat /etc/os-release
	    [[ -f /etc/redhat-release ]] && cat /etc/redhat-release 
	    [[ -f /etc/system-release ]] && cat /etc/system-release
	    echo -e "Current OS vendor: $(rpm --eval '%{?_vendor}') \n"
            ;;
    esac
fi

if [[ ! -d $rpmtopdir ]]; then 
  echo "This script works only in el5/el6/el7/amzn1/amzn2/amzn2023"
  echo "eg: ${0} el7"
  exit 1
fi

[[ -d $rpmtopdir ]] && BUILD_RPM

