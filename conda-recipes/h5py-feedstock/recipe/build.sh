#!/bin/bash

mpi_arg=""
if [[ "$mpi" != "nompi" ]]; then
  mpi_arg="--mpi"
fi

"${PYTHON}" setup.py configure $mpi_arg --hdf5="${PREFIX}"
"${PYTHON}" -m pip install . --no-deps --ignore-installed --no-cache-dir -vvv
