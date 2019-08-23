#!/bin/bash

mkdir -p ${PREFIX}/ppc64le-conda_cos7-linux-gnu/sysroot/usr
pushd ${PREFIX}/ppc64le-conda_cos7-linux-gnu/sysroot/usr > /dev/null 2>&1
cp -Rf "${SRC_DIR}"/binary/* .
