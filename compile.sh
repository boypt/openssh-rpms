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
__base="$(basename "${__file}" .sh)"
__root="$(cd "$(dirname "${__dir}")" && pwd)" # <-- change this as it depends on your app

arg1="${1:-}"
rpmtopdir=

# WITH_OPENSSL=
# Control openssl dependency
# 0: build without openssl
# 1: use system openssl
# 2: build openssl statically

CHECKEXISTS() {
	if [[ ! -f $__dir/downloads/$1 ]]; then
		echo "$1 not found, run 'pullsrc.sh', or manually put it in the downloads dir."
		exit 1
	fi
}

GUESS_DIST() {
	# will not work if rpm cmd not exists
	if ! type -p rpm >/dev/null; then
		echo 'unknown'
		return 0
	fi

	local dist
	dist=$(rpm --eval '%{?dist}' | tr -d '.')

	# Only el5/el6 have dedicated spec dirs; EL7+ (incl. EL-like rebuilds)
	# all share the el7 systemd layout.
	case $dist in
		el5) echo 'el5' && return 0 ;;
		el6) echo 'el6' && return 0 ;;
		el*) echo 'el7' && return 0 ;;
	esac

	# fallback via glibc version when %{?dist} is undefined:
	# el5 uses glibc 2.5, el6 uses 2.12, anything newer maps to el7
	local glibcver
	glibcver=$(ldd --version | head -n1 | grep -Eo '[0-9]+' | tr -d '\n')
	case $glibcver in
		25) echo 'el5' ;;
		212) echo 'el6' ;;
		*) echo 'el7' ;;
	esac
}

# Map GUESS_DIST output to the spec dir and set per-dist build defaults.
# Sets globals: rpmtopdir; WITH_OPENSSL (el7 only, unless already set)
TOPDIR_SELECT() {
	rpmtopdir=$(GUESS_DIST)
	if [[ ! -d $rpmtopdir ]]; then
		echo "Distro undefined, please specify manually: el5 el6 el7"
		echo "eg: ${0} el7"
		echo -e "\nCurrent OS:"
		[[ -f /etc/os-release ]] && cat /etc/os-release
		[[ -f /etc/redhat-release ]] && cat /etc/redhat-release
		[[ -f /etc/system-release ]] && cat /etc/system-release
		echo -e "Current OS vendor: $(rpm --eval '%{?_vendor}') \n"
		return 1
	fi
	# default WITH_OPENSSL for el7: system openssl >=3 -> 1, else static(2);
	# el5/el6 stay unset, BUILD_RPM defaults them to static(2)
	if [[ $rpmtopdir == el7 && -z ${WITH_OPENSSL+x} ]]; then
		local opensslver
		opensslver=$(rpm -q openssl --qf "%{VERSION}" 2>/dev/null | cut -d. -f1)
		[[ $opensslver -ge 3 ]] && WITH_OPENSSL=1 || WITH_OPENSSL=2
	fi
}

BUILD_RPM() {

	# shellcheck disable=SC1091
	source version.env
	# shellcheck disable=SC1091
	[[ -f version-local.env ]] && source version-local.env

	local SOURCES=("$OPENSSHSRC"
		"$OPENSSLSRC"
		"$ASKPASSSRC"
	)
	# UOS20 build: prefix PKGREL with "uos20." so the resulting RPMs are
	# distinguishable from the standard build (e.g. PKGREL `1` becomes
	# `uos20.1`, not `uos201`), and pass `uos20 1` to the spec to enable
	# the kernel-panic patch.
	# NOTE: RPM does not allow '-' in the Release field (it is the
	# Version/Release delimiter), so '.' is used as the separator.
	local _pkgrel="${PKGREL:-1}"
	if [[ ${UOS20:-0} == 1 ]]; then
		_pkgrel="uos20.${_pkgrel}"
	fi
	local RPMBUILDOPTS=(
		--define "with_openssl ${WITH_OPENSSL:-2}"
		--define "opensslver ${OPENSSLVER}"
		--define "opensshver ${OPENSSHVER}"
		--define "opensshpkgrel ${_pkgrel}"
		--define 'debug_package %{nil}'
		--define 'no_gtk2 1'
		--define 'skip_gnome_askpass 1'
		--define 'skip_x11_askpass 1'
	)
	[[ ${UOS20:-0} == 1 ]] && RPMBUILDOPTS+=('--define' 'uos20 1')

	# EL5 dist fixes
	if [[ $rpmtopdir == *el5 ]]; then
		SOURCES+=("$PERLSRC")

		# Hack: fake the perl src when perl is ready already(docker images)
		[[ $(perl -e 'print $] >= 5.010 ? 1 : 0') -eq 1 ]] \
			&& touch ./downloads/"$PERLSRC"

		RPMBUILDOPTS+=('--define' "perlver ${PERLVER}")
		local dist
		dist=$(rpm --eval '%{?dist}')
		[[ -n $dist ]] || RPMBUILDOPTS+=('--define' 'dist .el5')
		export CC=gcc44
	fi

	# add dist variable if not defined
	[[ $rpmtopdir == *el7 ]] && [[ -z $(rpm --eval '%{?dist}') ]] \
		&& RPMBUILDOPTS+=('--define' "dist .$(rpm -q glibc | rev | cut -d. -f2 | rev)")

	pushd $rpmtopdir
	# ensure the rpmbuild _topdir tree exists (fresh clone has no empty dirs)
	mkdir -p BUILD RPMS SRPMS SOURCES SPECS
	RPMBUILDOPTS+=('--define' "_topdir $PWD")
	for fn in "${SOURCES[@]}"; do
		CHECKEXISTS "$fn" \
			&& install -v -m666 "$__dir"/downloads/"$fn" ./SOURCES/
	done

	if [[ ${M32:-0} != 0 ]]; then
		local SETARCH="setarch i386"
		RPMBUILDOPTS+=('--target' i686)
		export CFLAGS="${CFLAGS:-} -m32" LDFLAGS="${LDFLAGS:-} -m32"
	fi

	if ! ${SETARCH:-} rpmbuild -bb ./SPECS/"${SPECFILE:-openssh.spec}" "${RPMBUILDOPTS[@]}"; then
		echo "Error: rpmbuild failed with exit code $?"
		exit 1
	fi

	mkdir -p "$__dir"/output
	find ./RPMS -type f -name '*.rpm' -exec install -v -m644 {} "$__dir"/output/ \;
	popd
}

LIST_RPMDIR() {
	local RPMDIR
	RPMDIR=$__dir/${rpmtopdir}/RPMS/$(rpm --eval '%{_arch}')
	[[ -d $RPMDIR ]] && echo "$RPMDIR"
}

LIST_RPMS() {
	local RPMDIR
	RPMDIR=$(LIST_RPMDIR)
	[[ -d $RPMDIR ]] && find "$RPMDIR" -type f -name '*.rpm'
}

# entry points
case $arg1 in
	GETEL)
		GUESS_DIST
		;;
	GETRPM)
		TOPDIR_SELECT
		LIST_RPMS
		;;
	RPMDIR)
		TOPDIR_SELECT
		LIST_RPMDIR
		;;
	"")
		# auto select dist
		TOPDIR_SELECT
		BUILD_RPM
		;;
	*)
		# manual specified dist dir
		if [[ ! -d $arg1 ]]; then
			echo -e "Subcmd: $arg1 not found.\n GETEL, GETRPM, RPMDIR"
			exit 1
		fi
		rpmtopdir=$arg1
		BUILD_RPM
		;;
esac
