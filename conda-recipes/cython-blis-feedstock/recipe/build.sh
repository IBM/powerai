#!/usr/bin/env bash

export BLIS_COMPILER="$GCC"
export BLIS_ARCH="generic"
if [[ "$(uname)" == "Linux" ]]; then
    $PYTHON -m pip install . --no-deps -vv --global-option="build_ext" --global-option="-lrt"
else
    $PYTHON -m pip install . --no-deps -vv 
fi
