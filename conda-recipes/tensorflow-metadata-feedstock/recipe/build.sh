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
#!/bin/bash

set -vex

export BAZEL_OPTS="--batch "

bazel ${BAZEL_OPTS} build //tensorflow_metadata:build_pip_package

export BUILD_WORKSPACE_DIRECTORY=$(pwd) 

cd bazel-bin/tensorflow_metadata/build_pip_package.runfiles/tensorflow_metadata
sh ${BUILD_WORKSPACE_DIRECTORY}/tensorflow_metadata/build_pip_package.sh
cd ${BUILD_WORKSPACE_DIRECTORY}

SYS_PYTHON_MAJOR=$(python -c "import sys;print(sys.version_info.major)")
# install using pip from the whl file
pip install --no-deps $SRC_DIR/dist/*py${SYS_PYTHON_MAJOR}*.whl

bazel clean --expunge

