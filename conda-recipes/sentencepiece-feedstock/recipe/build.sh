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
cmake -DCMAKE_INSTALL_PREFIX=${CONDA_INSTALL_DIR} .. -DSPM_BUILD_TEST=ON -DSPM_ENABLE_TENSORFLOW_SHARED=ON
make -j $(nproc)
make install
ldconfig -v
export PKG_CONFIG_PATH=$PKG_CONFIG_PATH:${CONDA_INSTALL_DIR}/lib/pkgconfig
export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:${CONDA_INSTALL_DIR}/lib

cd ../python
python setup.py install
cd ../tensorflow
python setup.py install
