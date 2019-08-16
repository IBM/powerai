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

