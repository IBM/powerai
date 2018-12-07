#!/bin/bash

set -e

mkdir -p ${PREFIX}/powerpc64le-conda_cos7-linux-gnu/usr
RPMS=$(find "${SRC_DIR}"/binary -name "*.rpm" -exec printf "." \; | wc -c | tr -d " ")
THE_RPM=$(find "${SRC_DIR}"/binary -name "*.rpm")
TOTAL=$(find "${SRC_DIR}"/binary -type f -exec printf "." \; | wc -c | tr -d " ")
pushd ${PREFIX}/powerpc64le-conda_cos7-linux-gnu/ > /dev/null 2>&1
  if [[ ${RPMS} == 1 ]] && [[ ${TOTAL} == 1 ]] && [[ -f ${THE_RPM} ]]; then
    "${RECIPE_DIR}"/rpm2cpio "${THE_RPM}" | cpio -idmv
  else
    cp -Rf "${SRC_DIR}"/binary/* ./usr
  fi
popd > /dev/null 2>&1
if [ -f ${SRC_DIR}/tzdata/*.rpm ]; then
  pushd ${SRC_DIR}/tzdata/ > /dev/null 2>&1
    ${RECIPE_DIR}/rpm2cpio *.rpm | cpio -idm
    mv usr/share ./
  popd > /dev/null 2>&1
fi
find ${PREFIX} -name "tzdb.dat" -exec cp --remove-destination ${SRC_DIR}/tzdata/share/javazi-1.8/tzdb.dat {} \;

mkdir -p ${PREFIX}/powerpc64le-conda_cos7-linux-gnu/etc/pki/java/cacerts
