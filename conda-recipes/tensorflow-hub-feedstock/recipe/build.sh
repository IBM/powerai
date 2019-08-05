# *****************************************************************
#
# Licensed Materials - Property of IBM
#
# (C) Copyright IBM Corp. 2018, 2019. All Rights Reserved.
#
# US Government Users Restricted Rights - Use, duplication or
# disclosure restricted by GSA ADP Schedule Contract with IBM Corp.
#
# *****************************************************************
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


