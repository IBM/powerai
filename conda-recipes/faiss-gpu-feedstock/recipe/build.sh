#!/bin/bash

set -ex

ARCH=`uname -p`
if [[ "${ARCH}" == 'x86_64' ]]; then
    # Build avx2 version
    CXXFLAGS="-mavx2 -mf16c" ./configure --with-cuda=$PREFIX
    make -j $CPU_COUNT
    make -C python _swigfaiss_avx2.so
    make clean
fi

# Build vanilla version (no avx)
./configure --with-cuda=$PREFIX
make -j $CPU_COUNT
make -C python _swigfaiss.so

make -C python build

cd python

$PYTHON setup.py install --single-version-externally-managed --record=record.txt
