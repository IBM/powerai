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

#!/bin/bash

set -vex

bazel ${BAZEL_OPTS} build tensorflow_hub/pip_package:build_pip_package

# build a whl file
mkdir -p $SRC_DIR/tensorflow_hub_pkg
bazel-bin/tensorflow_hub/pip_package/build_pip_package $SRC_DIR/tensorflow_hub_pkg

ls -l $SRC_DIR/tensorflow_hub_pkg

# install using pip from the whl file
pip install --no-deps $SRC_DIR/tensorflow_hub_pkg/*.whl

echo "PREFIX: $PREFIX"
echo "RECIPE_DIR: $RECIPE_DIR"


