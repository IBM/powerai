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
export BAZEL_LINKOPTS="-static-libstdc++ -static-libgcc"
export BAZEL_LINKLIBS="-l%:libstdc++.a"

bash compile.sh
mkdir -p $PREFIX/bin
mv output/bazel $PREFIX/bin

