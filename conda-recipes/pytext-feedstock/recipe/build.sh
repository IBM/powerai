#!/usr/bin/env bash
set -ex
echo $PWD
PYTHON_VERSION=$(python -V 2>&1 | cut -d ' ' -f 2 | cut -d '.' -f 1,2)
PACKAGE_PATH=$PREFIX/lib/python${PYTHON_VERSION}/site-packages/

python setup.py install --single-version-externally-managed --record=record.txt

#put scripts into the bin dir
cp $RECIPE_DIR/scripts/pytext-install-samples $PREFIX/bin
cp $RECIPE_DIR/scripts/pytext-test $PREFIX/bin/

#copy docs to the PREFIX area so they are included in our package
mkdir -p $PREFIX/pytext/doc
cp $PWD/README.md $PREFIX/pytext/doc
cp $PWD/CONTRIBUTING.md $PREFIX/pytext/doc
cp -R ${SRC_DIR}/pytext/docs/source/*.rst ${PREFIX}/pytext/doc

mkdir -p  $PACKAGE_PATH/pytext/
cp -Rf $PWD/tests $PACKAGE_PATH/pytext
cp -Rf $PWD/demo $PACKAGE_PATH/pytext/demo

mkdir -p $PACKAGE_PATH/pytext/data/test
cp -R $PWD/data/test/data $PACKAGE_PATH/pytext/data/test
