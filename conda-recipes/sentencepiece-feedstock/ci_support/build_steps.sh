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

set -xeuo pipefail
export PYTHONUNBUFFERED=1
export FEEDSTOCK_ROOT=/home/conda/feedstock_root
export RECIPE_ROOT=/home/conda/recipe_root
export CI_SUPPORT=/home/conda/feedstock_root/.ci_support
export CONFIG_FILE="${CI_SUPPORT}/${CONFIG}.yaml"

cat >~/.condarc <<CONDARC

conda-build:
 root-dir: /home/conda/feedstock_root/build_artifacts

CONDARC

/usr/bin/sudo -n yum install -y gcc-c++

conda config --prepend channels https://public.dhe.ibm.com/ibmdl/export/pub/software/server/ibm-ai/conda/
export IBM_POWERAI_LICENSE_ACCEPT=yes

conda install --yes --quiet conda-forge-ci-setup=2 conda-build=3.16 -c conda-forge

# patchelf from conda-forge (0.10) causes errors. Use 0.9 from defaults
conda install -y patchelf=0.9

# set up the condarc
setup_conda_rc "${FEEDSTOCK_ROOT}" "${RECIPE_ROOT}" "${CONFIG_FILE}"

# make the build number clobber
make_build_number "${FEEDSTOCK_ROOT}" "${RECIPE_ROOT}" "${CONFIG_FILE}"

conda build "${RECIPE_ROOT}" -m "${CI_SUPPORT}/${CONFIG}.yaml" \
    --clobber-file "${CI_SUPPORT}/clobber_${CONFIG}.yaml"

if [[ "${UPLOAD_PACKAGES}" != "False" ]]; then
    upload_package "${FEEDSTOCK_ROOT}" "${RECIPE_ROOT}" "${CONFIG_FILE}"
fi

touch "/home/conda/feedstock_root/build_artifacts/conda-forge-build-done-${CONFIG}"
