#!/bin/sh

export SKIP_PYARROW_INSTALL=True
cd python
$PYTHON setup.py install
