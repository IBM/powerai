#!/bin/bash

CUDA_LIBPATH=/usr/local/cuda/lib64/stubs
if [ ! -f ${CUDA_LIBPATH}/libcuda.so.1 ] && [ -f ${CUDA_LIBPATH}/libcuda.so ]
then
    ln -s ${CUDA_LIBPATH}/libcuda.so ${CUDA_LIBPATH}/libcuda.so.1
elif [ ! -f ${CUDA_LIBPATH}/libcuda.so ]
then
    echo "Missing Cuda library libcuda.so"
    exit -1
fi

export NCCL_LIB_DIR="${PREFIX}/lib"
export NCCL_INCLUDE_DIR="${PREFIX}/include"

export CFLAGS+=" -I/usr/include/powerpc64le-linux-gnu -I/usr/local/cuda/include -I/usr/include "

# Add path to find libcuda.so, libcudnn.so etc.,
export LDFLAGS=" -L/usr/local/cuda/lib64/stubs -L/usr/lib/powerpc64le-linux-gnu ${LDFLAGS} "

python setup.py install --single-version-externally-managed --record record.txt

# ensure that CUDA library path is set correctly during runtime
mkdir -p "${PREFIX}"/etc/conda/activate.d
mkdir -p "${PREFIX}"/etc/conda/deactivate.d
cp "${RECIPE_DIR}"/scripts/activate.sh "${PREFIX}"/etc/conda/activate.d/cuda_path.sh
cp "${RECIPE_DIR}"/scripts/deactivate.sh "${PREFIX}"/etc/conda/deactivate.d/cuda_path.sh
