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
set -v -x

# useful for debugging:
#export BAZEL_BUILD_OPTS="--logging=6 --subcommands --verbose_failures"
#Linux - set flags for statically linking libstdc++
# xref: https://github.com/bazelbuild/bazel/blob/0.12.0/tools/cpp/unix_cc_configure.bzl#L257-L258
# xref: https://github.com/bazelbuild/bazel/blob/0.12.0/tools/cpp/lib_cc_configure.bzl#L25-L39
export BAZEL_LINKOPTS="-static-libgcc:-static-libstdc++:-l%:libstdc++.a:-lm:-Wl,--disable-new-dtags"

bash compile.sh
mkdir -p $PREFIX/bin
mv output/bazel $PREFIX/bin

# Run test here, because we lose $RECIPE_DIR in the test portion
cp -r ${RECIPE_DIR}/tutorial .
cd tutorial
bazel build "${BAZEL_BUILD_OPTS[@]}" //main:hello-world
bazel info | grep "java-home.*_embedded_binaries"

if [[ ${HOST} =~ .*linux.* ]]; then
    # libstdc++ should not be included in this listing as it is statically linked
    readelf -d $PREFIX/bin/bazel
fi
