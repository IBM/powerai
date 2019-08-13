#!/bin/bash
# *****************************************************************
#
# Licensed Materials - Property of IBM
#
# (C) Copyright IBM Corp. 2019. All Rights Reserved.
#
# US Government Users Restricted Rights - Use, duplication or
# disclosure restricted by GSA ADP Schedule Contract with IBM Corp.
#
# *****************************************************************

set -ex

# Install the downloaded pip package
python -m pip install . --no-deps --ignore-installed --no-cache-dir -vvv

# We need to clone source code here just to copy test data required to run python tests
CUR_DIR=$(pwd)
git clone https://github.com/tensorflow/datasets.git
cd datasets

echo ${PKG_VERSION}
TAGNAME=$(git tag --list | grep "${PKG_VERSION}")
git checkout ${TAGNAME}

SYS_PYTHON_MAJOR=$(python -c "import sys;print(sys.version_info.major)")
SYS_PYTHON_MINOR=$(python -c "import sys;print(sys.version_info.minor)")

INSTALLED_DIR="${PREFIX}/lib/python${SYS_PYTHON_MAJOR}.${SYS_PYTHON_MINOR}/site-packages/tensorflow_datasets"

TEST_DATA_DIR_SRC=./tensorflow_datasets/testing/test_data
TEST_DATA_DIR_DEST="${INSTALLED_DIR}/testing"
cp -R ${TEST_DATA_DIR_SRC} ${TEST_DATA_DIR_DEST}

cp -R ./tensorflow_datasets/image/*.txt ${INSTALLED_DIR}/image/
cp -R ./tensorflow_datasets/video/*.txt ${INSTALLED_DIR}/video/
cd ..
rm -rf datasets

# Install the run examples scripts
mkdir -p "${PREFIX}"/bin
cp "${RECIPE_DIR}"/tensorflow-datasets-test "${PREFIX}"/bin
