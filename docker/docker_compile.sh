#!/bin/bash
DOCKER_BUILD_DIR=/BUILD
mkdir -p $DOCKER_BUILD_DIR
ELDIR=$(./compile.sh GETEL)
OPENSSLVER=$(rpm -q openssl --qf "%{VERSION}" | cut -d. -f1)

if [[ ${WITH_OPENSSL+x} == "" ]]; then
  if [[  $OPENSSLVER -ge 3 ]]; then
    export WITH_OPENSSL=1
  else
    export WITH_OPENSSL=2
  fi
fi

[[ $ELDIR == el8 ]] && ELDIR=el7
cp -r $ELDIR $DOCKER_BUILD_DIR
./compile.sh $DOCKER_BUILD_DIR/$ELDIR
