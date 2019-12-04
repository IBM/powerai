#!/bin/bash

"${PYTHON}" setup.py configure --hdf5="${PREFIX}"
"${PYTHON}" -m pip install . --no-deps --ignore-installed -vvv
