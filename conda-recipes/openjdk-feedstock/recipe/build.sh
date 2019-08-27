#!/bin/bash -euo

chmod +x bin/*
mkdir -p $PREFIX/bin
mv bin/* $PREFIX/bin/
ls -la $PREFIX/bin

mkdir -p $PREFIX/include
mv include/* $PREFIX/include
if [ -e ./lib/jspawnhelper ]; then
    chmod +x ./lib/jspawnhelper
fi

mkdir -p $PREFIX/lib
mv lib/* $PREFIX/lib

mkdir -p $PREFIX/jre
mv jre/* $PREFIX/jre

mkdir -p $PREFIX/man
mv man/* $PREFIX/man

# Copy the [de]activate scripts to $PREFIX/etc/conda/[de]activate.d.
# This will allow them to be run on environment activation.
for CHANGE in "activate" "deactivate"
do
    mkdir -p "${PREFIX}/etc/conda/${CHANGE}.d"
    cp "${RECIPE_DIR}/scripts/${CHANGE}.sh" "${PREFIX}/etc/conda/${CHANGE}.d/${PKG_NAME}_${CHANGE}.sh"
done
