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

#!/usr/bin/env bash

THISDIR="$( cd "$( dirname "$0" )" >/dev/null && pwd )"
PROVIDER_DIR="$(basename $THISDIR)"

FEEDSTOCK_ROOT=$(cd "$(dirname "$0")/.."; pwd;)
RECIPE_ROOT=$FEEDSTOCK_ROOT/recipe

docker info

config=$(cat <<CONDARC

channels:
 - conda-forge
 - defaults

conda-build:
 root-dir: /feedstock_root/build_artefacts

show_channel_urls: true

CONDARC
)

# In order for the conda-build process in the container to write to the mounted
# volumes, we need to run with the same id as the host machine, which is
# normally the owner of the mounted volumes, or at least has write permission
export HOST_USER_ID=$(id -u)
# Check if docker-machine is being used (normally on OSX) and get the uid from
# the VM
if hash docker-machine 2> /dev/null && docker-machine active > /dev/null; then
    HOST_USER_ID=$(docker-machine ssh $(docker-machine active) id -u)
fi

ARTIFACTS="$FEEDSTOCK_ROOT/build_artifacts"
mkdir -p "$ARTIFACTS"
DONE_CANARY="$ARTIFACTS/conda-forge-build-done-${CONFIG}"
rm -f "$DONE_CANARY"
# Enable running in interactive mode attached to a tty
DOCKER_RUN_ARGS=" -it "

docker run ${DOCKER_RUN_ARGS} \
                        -v "${RECIPE_ROOT}":/home/conda/recipe_root:ro,z \
                        -v "${FEEDSTOCK_ROOT}":/home/conda/feedstock_root:rw,z \
                        -e CONFIG \
                        -e HOST_USER_ID \
                        -e UPLOAD_PACKAGES \
                        -e CI \
                        -e CONDA_PY="${CONDA_PY}" \
                        -a stdin -a stdout -a stderr \
                        condaforge/linux-anvil-ppc64le \
                        bash \
                        /home/conda/feedstock_root/${PROVIDER_DIR}/build_steps.sh

# double-check that the build got to the end
# see https://github.com/conda-forge/conda-smithy/pull/337
# for a possible fix

test -f "$DONE_CANARY"
