#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail

DOCKER_BUILD_DIR=/BUILD
mkdir -p "$DOCKER_BUILD_DIR"

ELDIR=${BUILD_TOPDIR:-$(./compile.sh GETEL)}
if [[ ! -d $ELDIR ]]; then
	echo "RPM build tree not found: $ELDIR" >&2
	exit 1
fi

rpm_dist=$(rpm --eval '%{?dist}')
rpm_dist=${rpm_dist#.}
if [[ -z $rpm_dist ]]; then
	rpm_dist=${RPM_DIST_OVERRIDE:-}
fi
if [[ -n ${EXPECTED_RPM_DIST:-} && $rpm_dist != "$EXPECTED_RPM_DIST" ]]; then
	echo "Unexpected RPM dist: expected $EXPECTED_RPM_DIST, got ${rpm_dist:-<empty>}" >&2
	exit 1
fi

if ! rpm -q openssl-devel >/dev/null; then
	WITH_OPENSSL=2
fi

if [[ -z ${WITH_OPENSSL+x} ]]; then
	openssl_major=$(rpm -q openssl --qf '%{VERSION}' 2>/dev/null | cut -d. -f1 || true)
	if [[ $openssl_major =~ ^[0-9]+$ && $openssl_major -ge 3 ]]; then
		export WITH_OPENSSL=1
	else
		export WITH_OPENSSL=2
	fi
fi

cp -r "$ELDIR" "$DOCKER_BUILD_DIR"
./compile.sh "$DOCKER_BUILD_DIR/$ELDIR"
