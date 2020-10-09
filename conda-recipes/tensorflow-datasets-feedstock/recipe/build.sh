#!/bin/bash
#
# (C) Copyright IBM Corp. 2018, 2019. All Rights Reserved.
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

# Install the downloaded pip package
python -m pip install . --no-deps --ignore-installed --no-cache-dir -vvv

# We need to clone source code here just to copy test data required to run python tests
CUR_DIR=$(pwd)
git clone https://github.com/tensorflow/datasets.git
cd datasets

echo ${PKG_VERSION}
TAGNAME=$(git tag --list | grep "v${PKG_VERSION}")
git checkout ${TAGNAME}

SYS_PYTHON_MAJOR=$(python -c "import sys;print(sys.version_info.major)")
SYS_PYTHON_MINOR=$(python -c "import sys;print(sys.version_info.minor)")

INSTALLED_DIR="${PREFIX}/lib/python${SYS_PYTHON_MAJOR}.${SYS_PYTHON_MINOR}/site-packages/tensorflow_datasets"

TEST_DATA_DIR_SRC=./tensorflow_datasets/testing/test_data
TEST_DATA_DIR_DEST="${INSTALLED_DIR}/testing"
cp -R ${TEST_DATA_DIR_SRC} ${TEST_DATA_DIR_DEST}

cp -R ./tensorflow_datasets/image_classification/*.txt ${INSTALLED_DIR}/image_classification/
cp -R ./tensorflow_datasets/video/*.txt ${INSTALLED_DIR}/video/
cp -R ./tensorflow_datasets/url_checksums/*.txt ${INSTALLED_DIR}/url_checksums

cd ..
rm -rf datasets

# Install the test script
mkdir -p "${PREFIX}"/bin
cp ../../../recipe/tensorflow-datasets-test "${PREFIX}"/bin
