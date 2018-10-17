#!/bin/bash
set -e -x
export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/usr/local/cuda/lib64:/usr/local/lib

# Needed for pygdf.concat(), avoids "OSError: library nvvm not found"
export NUMBAPRO_NVVM=/usr/local/cuda/nvvm/lib64/libnvvm.so
export NUMBAPRO_LIBDEVICE=/usr/local/cuda/nvvm/libdevice/

export CC=5
export CXX=5

# LibGDF build/install
export CC=/usr/bin/gcc-${CC}
export CXX=/usr/bin/g++-${CXX}
export HASH_JOIN=ON
    mkdir -p libgdf/build
    cd libgdf/build 
    cmake .. 
    cmake .. -DHASH_JOIN=${HASH_JOIN}
    make -j install
    make copy_python
    python setup.py install
    cd ../..

# Arrow build install
export ARROW_BUILD_TYPE=release
export ARROW_HOME=${PREFIX}/repos/dist
export LD_LIBRARY_PATH=${PREFIX}/repos/dist/lib:$LD_LIBRARY_PATH

    mkdir -p repos/arrow/cpp/build
    cd repos/arrow/cpp/build
    cmake -DCMAKE_BUILD_TYPE=$ARROW_BUILD_TYPE \
          -DCMAKE_INSTALL_PREFIX=$ARROW_HOME \
          -DARROW_PYTHON=on \
          -DARROW_BUILD_TESTS=OFF \
          ..
    make -j4
    make install
    cd ../../../.. 

    # pyArrow build install
    cd repos/arrow/python
    python setup.py build_ext --build-type=$ARROW_BUILD_TYPE --inplace
    python setup.py install
    cd ../../.. 

# PyGDF build/install
    cd pygdf
    python setup.py install 
    cd .. 

# ensure that pygdf library path is set correctly during runtime
mkdir -p "${PREFIX}"/etc/conda/activate.d
mkdir -p "${PREFIX}"/etc/conda/deactivate.d
cp "${RECIPE_DIR}"/scripts/activate.sh "${PREFIX}"/etc/conda/activate.d/pygdf_path.sh
cp "${RECIPE_DIR}"/scripts/deactivate.sh "${PREFIX}"/etc/conda/deactivate.d/pygdf_path.sh
