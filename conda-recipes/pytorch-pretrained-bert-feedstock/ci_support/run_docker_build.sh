# (C) Copyright IBM Corp. 2018, 2019. All Rights Reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

#!/usr/bin/env bash

THISDIR="$( cd "$( dirname "$0" )" >/dev/null && pwd )"
PROVIDER_DIR="$(basename $THISDIR)"

FEEDSTOCK_ROOT=$(cd "$(dirname "$0")/.."; pwd;)
RECIPE_ROOT=$FEEDSTOCK_ROOT/recipe

docker info

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
test -t 1 && USE_TTY="-t"
DOCKER_RUN_ARGS=" -i ${USE_TTY} "

if [ -z "${DOCKER_IMAGE}" ]; then
  echo "WARNING: DOCKER_IMAGE variable not set. Falling back to condaforge/linux-anvil-ppc64le"
  DOCKER_IMAGE="condaforge/linux-anvil-ppc64le"
fi

docker run ${DOCKER_RUN_ARGS} \
                        -v "${RECIPE_ROOT}":/home/conda/recipe_root:ro,z \
                        -v "${FEEDSTOCK_ROOT}":/home/conda/feedstock_root:rw,z \
                        -e CONFIG \
                        -e BINSTAR_TOKEN \
                        -e HOST_USER_ID \
                        -e UPLOAD_PACKAGES \
                        -e CI \
                        -a stdin -a stdout -a stderr -u root \
                        $DOCKER_IMAGE \
                        bash \
                        /home/conda/feedstock_root/${PROVIDER_DIR}/build_steps.sh

# double-check that the build got to the end
# see https://github.com/conda-forge/conda-smithy/pull/337
# for a possible fix

test -f "$DONE_CANARY"
