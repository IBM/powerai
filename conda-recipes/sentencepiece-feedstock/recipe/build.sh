#!/bin/bash
#
# (C) Copyright IBM Corp. 2019. All Rights Reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
# *****************************************************************

set -ex

build_tf_wrapper() {
  if [ "$1" != "" ]; then
    pkg_name="==$1"
  fi

  export IBM_POWERAI_LICENSE_ACCEPT=yes
  conda create -n tf$1 -y python=3.6

  conda activate tf$1
  conda config --prepend channels https://public.dhe.ibm.com/ibmdl/export/pub/software/server/ibm-ai/conda/
  conda config --prepend channels https://public.dhe.ibm.com/ibmdl/export/pub/software/server/ibm-ai/conda-early-access/

  # Builds _sentencepiece_processor_ops.so
  conda install -y tensorflow${pkg_name}

  LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/usr/lib/${ARCH_SO_NAME}-linux-gnu

  TF_CFLAGS=( $(python -c 'import tensorflow as tf; print(" ".join(tf.sysconfig.get_compile_flags()))') )
  TF_LFLAGS=( $(python -c 'import tensorflow as tf; print(" ".join(tf.sysconfig.get_link_flags()))') )
  TF_VERSION=( $(python -c 'import tensorflow as tf; print(tf.__version__)') )

  echo TF_CFLAGS=${TF_CFLAGS[@]}
  echo TF_LFLAGS=${TF_LFLAGS[@]}
  echo TF_VERSION=${TF_VERSION}
  CUR_DIR=$(pwd)
  echo "Current dir: $CUR_DIR"

  conda deactivate
  
  $CXX -std=c++11 -shared \
    -I../src \
    -fPIC ${TF_CFLAGS[@]} -O2 \
    -Wl,--whole-archive \
    ${PREFIX}/lib/libsentencepiece.a \
    -Wl,--no-whole-archive \
    ../tensorflow/sentencepiece_processor_ops.cc \
    -o ../tensorflow/tf_sentencepiece/_sentencepiece_processor_ops.so.${TF_VERSION} \
    ${TF_LFLAGS[@]}

  $STRIP ../tensorflow/tf_sentencepiece/_sentencepiece_processor_ops.so.${TF_VERSION}
  conda env remove -n tf$1
}

ARCH=`uname -p`
if [[ "${ARCH}" == 'ppc64le' ]]; then
    ARCH_SO_NAME="powerpc64le"
else
    ARCH_SO_NAME=${ARCH}
fi

PAGE_SIZE=`getconf PAGE_SIZE`

mkdir build
cd build
cmake -DCMAKE_INSTALL_PREFIX=${PREFIX} .. -DSPM_BUILD_TEST=ON -DSPM_ENABLE_TENSORFLOW_SHARED=ON -DCMAKE_AR=$GCC_AR -DSPM_USE_BUILTIN_PROTOBUF=OFF
make -j $(nproc)

export PKG_CONFIG_PATH=${PREFIX}/lib/pkgconfig:${PKG_CONFIG_PATH}
export LD_LIBRARY_PATH=${PREFIX}/lib:${LD_LIBRARY_PATH}
make install

#build_tf_wrapper "1.13.1" # WML CE 1.6.0 / protobuf 3.6.1
#build_tf_wrapper "1.14.0" # WML CE 1.6.1 / protobuf 3.7.1
build_tf_wrapper "1.15.0" # WML CE 1.6.2 / protobuf 3.8.0
build_tf_wrapper "2.1.0" # WML CE 1.7.0 / protobuf 3.8.0

cd ../python

python setup.py install

SYS_PYTHON_MAJOR=$(python -c "import sys;print(sys.version_info.major)")
SYS_PYTHON_MINOR=$(python -c "import sys;print(sys.version_info.minor)")
patchelf --page-size ${PAGE_SIZE} --set-rpath $LD_LIBRARY_PATH $PREFIX/lib/python${SYS_PYTHON_MAJOR}.${SYS_PYTHON_MINOR}/site-packages/sentencepiece-$PKG_VERSION-py${SYS_PYTHON_MAJOR}.${SYS_PYTHON_MINOR}-linux-${ARCH}.egg/_sentencepiece.cpython-${CONDA_PY}m-${ARCH_SO_NAME}-linux-gnu.so

cd ../tensorflow
python setup.py install
