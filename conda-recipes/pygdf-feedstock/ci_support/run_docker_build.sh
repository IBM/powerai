#!/usr/bin/env bash

FEEDSTOCK_ROOT=$(cd "$(dirname "$0")/.."; pwd;)
RECIPE_ROOT=$FEEDSTOCK_ROOT/recipe

docker info

config=$(cat <<CONDARC

channels:
 - conda-forge
 - numba
 - defaults

conda-build:
 root-dir: /feedstock_root/build_artefacts

show_channel_urls: true

CONDARC
)

# In order for the conda-build process in the container to write to the mounted
# volumes, we need to run with the same id as the host machine, which is
# normally the owner of the mounted volumes, or at least has write permission
HOST_USER_ID=$(id -u)
# Check if docker-machine is being used (normally on OSX) and get the uid from
# the VM
if hash docker-machine 2> /dev/null && docker-machine active > /dev/null; then
    HOST_USER_ID=$(docker-machine ssh $(docker-machine active) id -u)
fi

rm -f "$FEEDSTOCK_ROOT/build_artefacts/conda-forge-build-done"

cat << EOF | docker run -i \
                        -v "${RECIPE_ROOT}":/recipe_root \
                        -v "${FEEDSTOCK_ROOT}":/feedstock_root \
                        -e HOST_USER_ID="${HOST_USER_ID}" \
                        -e CONDA_PY="${CONDA_PY}" \
                        -a stdin -a stdout -a stderr \
                        nvidia/cuda-ppc64le:9.2-cudnn7-devel-ubuntu16.04 \
                        bash || exit 1

set -e -x

apt-get update
apt-get install -y curl
curl -s -L https://repo.continuum.io/miniconda/Miniconda3-4.5.11-Linux-ppc64le.sh > miniconda.sh
chmod 755 miniconda.sh 
bash miniconda.sh -b -p /opt/conda
conda install --yes --quiet conda-build

export PYTHONUNBUFFERED=1
export PATH=/opt/conda/bin:$PATH

echo "$config" > ~/.condarc
# A lock sometimes occurs with incomplete builds. The lock file is stored in build_artefacts.
conda clean --lock

conda build /recipe_root --quiet || exit 1

ls /feedstock_root/build_artefacts/linux-ppc64le/${1}*.tar.bz2

touch /feedstock_root/build_artefacts/conda-forge-build-done
EOF

# double-check that the build got to the end
# see https://github.com/conda-forge/conda-smithy/pull/337
# for a possible fix
set -x
test -f "$FEEDSTOCK_ROOT/build_artefacts/conda-forge-build-done" || exit 1
