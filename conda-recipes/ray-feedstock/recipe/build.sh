#!/bin/sh

export SKIP_PYARROW_INSTALL=True
cd python
$PYTHON setup.py install --single-version-externally-managed --record=record.txt
