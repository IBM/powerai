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

mkdir build
cd build
cmake -DCMAKE_INSTALL_PREFIX=${PREFIX} .. -DSPM_BUILD_TEST=ON -DSPM_ENABLE_TENSORFLOW_SHARED=ON
make -j $(nproc)
export PKG_CONFIG_PATH=${PREFIX}/lib/pkgconfig:${PKG_CONFIG_PATH}
export LD_LIBRARY_PATH=${PREFIX}/lib:${LD_LIBRARY_PATH}
SYS_PYTHON_MAJOR=$(python -c "import sys;print(sys.version_info.major)")
SYS_PYTHON_MINOR=$(python -c "import sys;print(sys.version_info.minor)")

patchelf --set-rpath $LD_LIBRARY_PATH $PREFIX/lib/python${SYS_PYTHON_MAJOR}.${SYS_PYTHON_MINOR}/_sentencepiece.cpython-${CONDA_PY}m-powerpc64le-linux-gnu.so
make install
cd ../python
python setup.py install
cd ../tensorflow
python setup.py install
