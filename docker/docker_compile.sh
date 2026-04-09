#!/bin/bash
DOCKER_BUILD_DIR=/BUILD
mkdir -p $DOCKER_BUILD_DIR
ELDIR=$(./compile.sh GETEL)
[[ $ELDIR == el8 ]] && ELDIR=el7
cp -r $ELDIR $DOCKER_BUILD_DIR
./compile.sh $DOCKER_BUILD_DIR/$ELDIR
