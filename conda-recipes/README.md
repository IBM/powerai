## PowerAI Supplementary Channel

This directory contains community built recipes for additional conda packages often needed for running deep learning and machine learning python code on ppc64le and amd64. These recipes are automatically built on travis-ci.org (https://travis-ci.org/IBM/powerai). 

Packages that are built are published to https://anaconda.org/powerai/

Community PRs are welcome.  This is not an offical IBM product. Support is community based.

### How to enable the channel

Since the WML CE Supplementary channel is hosted on anaconda.org, it's simple to enable and use. Use one of two ways:
 - add `powerai` to your .condarc file
 - add `-c powerai` to the conda install command to indicate you'd like this channel enabled during the installation.

The first method is recommended as you can clearly control the channel priorities (top most channel is top priority)

### Recipe Requests
To request a package recipe to be created and be built, open an issue with the following formatting.

 - Name of package: 
 - URL of package source code: 
 - License of package: 
 - List of package dependencies:
 - Short description of package and use case(s):

Folks who would also like to see this pacakge in the supplementary channel, please thumbs-up so the developers can know which requests to prioritize.

And if you'd like to contribute the package recipe (thank you!), see the instructions below.

## How to add a recipe to the repo

Recipes in this directory are modeled after the conda-forge build environment. Travis CI is used as the build service.

### Step 1) Create the recipe
First it's good to consider if the package belongs in the Supplementary Channel. The main goals of Supplementary are:
* Provide value-add, or add-on packages along side the WML CE main channel
* Provide a place for packages that are otherwise hard or impossible to support
* Provide a place for client teams and/or clients to help themselves get more value out of WML CE
* Easy to maintain

Packages with a lot of native (C/C++) code, for example, often have more strict or more extensive dependency sets. Complex packages are likely better off in WML CE, AD, or conda-forge, so they can be more closely looked after. The community-run conda-forge channel does have ppc64le support now and maintains support going forward. If recipes exist there, effort should be made to consider enabling ppc64le builds instead of adding them to Supplementary.

Next, determine if the recipe should be marked `noarch` or if it should be python or architecture dependent. Noarch packages are compatible with all platforms and architectures. Information on conda's [noarch packages](https://www.anaconda.com/condas-new-noarch-packages/) including the requirements that must be met to be able to use `noarch` are found on [conda.io](https://docs.conda.io/projects/conda/en/latest/user-guide/concepts/packages.html#noarch-packages).

If a package is *not* `noarch`, then we'd like a version for each python version and platform version supported by WML CE (exceptions apply).

| Python Versions | Platform |
|:----------------|----------:|
| 3.6 | ppc64le |
| 3.7 | ppc64le |
| 3.6 | x86_64 |
| 3.7 | x86_64 |

Exceptions: If either conda-forge or AD have the exact package and version already for a specific platform and python version, it can be omitted from the recipe.

The recipe itself can be created in one of three ways:
1. By hand from scratch
2. By using `conda skeleton` for a package already located in pypi (python) or CRAN (R).
3. By extending and rebuilding a recipe that already exists in conda-forge or AD. Note if this is the case, first consider trying to get the package enabled in conda-forge.

Check the [docs](https://docs.conda.io/projects/conda-build/en/latest/user-guide/tutorials/build-pkgs-skeleton.html#building-conda-packages-with-conda-skeleton) for creating a recipe using conda skeleton.

A recipe should not be accepted that does not include tests. Simple "import" tests are ok, but ideally the test would cover a bit more. Look at other recipes to get an idea of the scope for testing. If a package has upstream unit tests, those are ideal to run in the test section. If a unit test fails and is blocking the addition of the package to Supplementary, there are a few  options:
1. Fix the test upstream; merge it upstream
2. Fix the test upstream; provide a patch in the recipe
3. provide a patch in the recipe to xfail the test (or similar, depending on test framework used)

**Licenses**
Each recipe should include **two** license files:
1. For the code in the package
2. For the recipe itself

For the license of the code in the package, if the code checkout/download that is referenced in the meta.yaml includes a copy of the license, then that file can be referenced directly in the `meta.yaml` file in the about` section:

```
about:
  home: https://github.com/tensorflow/mesh
  license: Apache License 2.0
  license_family: Apache
  license_file: 'LICENSE'
```

If the code checkout/download **does not** include the license file, it must be located and placed in the /recipe directory along with the meta.yaml file and then referenced in the meta.yaml file.

The license for the recipe itself should be in the top level directory of the recipe and be BSD or Apache-2.
A sample BSD license:

```
BSD 3-clause license
Copyright (c) 2015-2019, conda-forge, IBM
All rights reserved.

Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:

1. Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.

2. Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.

3. Neither the name of the copyright holder nor the names of its contributors may be used to endorse or promote products derived from this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
```

### Step 2) Add CI scripts to the recipe

Your new recipe should include a `ci_support` directory with a `run_docker_build.sh` script. The only thing that may change here is the condarc defines for channel enablement. This directory should also include a `build_steps.sh` script. This one should not change much from existing ones aside from perhaps some slight customization.

The `build_steps.sh` script references a configuration file. Existing recipes have these in a `.ci_support` directory. An example configuration may look like:
```
c_compiler:
- gcc
c_compiler_version:
- '8'
channel_sources:
- powerai,defaults,conda-forge
channel_targets:
- powerai main
docker_image:
- condaforge/linux-anvil-ppc64le
pin_run_as_build:
  python:
    min_pin: x.x
    max_pin: x.x
python:
- '3.6'
```

These defines are used to define the build envionment, source channels and upload targets. The example above shows a configuration for a python 3.6 package that needs a C compiler and has dependencies that may be available in the Supplementary channel, AD or conda-forge. This also shows this package will be for ppc64le arch as the ppc64le anvil image is being used.

### Step 3) Modify the Travis-ci hook to build your recipe.

Since all of the recipe are directories inside the `powerai` repository, they do not have individual event hooks. The hook is located in top level travis.yml file (https://github.com/IBM/powerai/blob/master/.travis.yml). This file includes the secure tokens and the job list. The secure token is used by Travis to decrypt an upload script that contains the anaconda.org key. The actual key is not retrievable any other way. The job list should be updated in your PR to include only the various configurations for your project. For example the Travis hook file below will build the Spacy recipe for python 3.6 and 3.7 for both ppc64le and x86_64.

```
env:
  global:
    # The BINSTAR Token for uploading to anaconda.org/powerai
    - secure: 
       "BigLongTokenDontChangeMe"

matrix:
  include:
    - env: CONFIG=linux_ppc64le_python3.6 UPLOAD_PACKAGES=True DOCKER_IMAGE=condaforge/linux-anvil-ppc64le
      os: linux-ppc64le
      arch: ppc64le
      language: generic
  
    - env: CONFIG=linux_ppc64le_python3.7 UPLOAD_PACKAGES=True DOCKER_IMAGE=condaforge/linux-anvil-ppc64le
      os: linux-ppc64le
      arch: ppc64le
      language: generic

    - env: CONFIG=linux_python3.6 UPLOAD_PACKAGES=True DOCKER_IMAGE=condaforge/linux-anvil-comp7
      os: linux-64
      arch: amd64
      language: generic

    - env: CONFIG=linux_python3.7 UPLOAD_PACKAGES=True DOCKER_IMAGE=condaforge/linux-anvil-comp7
      os: linux-64
      arch: amd64
      language: generic

script:
  -  cd conda-recipes/spacy-feedstock
  -  ./ci_support/run_docker_build.sh
```

A `noarch` package configuration may look like:
```
env:
  global:
    # The BINSTAR Token for uploading to anaconda.org/powerai
    - secure: 
       "BigLongTokenDontChangeMe"

matrix:
  include:
    - env: CONFIG=linux_noarch UPLOAD_PACKAGES=True DOCKER_IMAGE=condaforge/linux-anvil-ppc64le
      os: linux-ppc64le
      language: generic

      script:
          -  cd conda-recipes/mesh-tensorflow-feedstock
          -  ./ci_support/run_docker_build.sh
```

In either case, the `script` section should change into the `ci_support` directory of your recipe and execute the `run_docker_build.sh` script. 
Change this to only do your additional package (or fix). There is no need to run other recipes for publish if no changes are made there. Leave the secure tokens as is.


### Step 4) Building
Travis is configured to build these recipes on Pull Requests. Packages will only be published, however, on code merges.
travis-ci.org does have build limits current (around 50mins or so), so long building recipes may be aborted.

The builds are hosted on `https://travis-ci.org/IBM/powerai/`.


### Secure uploads

You may have some questions. Like how do we secure uploads to the anaconda.org channel? I see the BINSTAR token there, what is that? Is it secure to have out in the open like that? Some information points:

* The "BINSTAR token"  is an encrypted command sequence.
 
* BINSTAR is encrypted with the public Travis key found here:
 curl https://api.travis-ci.org/repos/IBM/powerai/key
 
* Only Travis-ci has the private key needed to decrypt the BINSTAR. And it will only do that for merge triggers from github.com/powerai. The BINSTAR token is not decrypted for PRs, so uploads do not take place on PR builds.
 
* Once decrypted, BINSTAR becomes a script that sets an environment variable with the anaconda.org/power upload token. Only then can a package be securely uploaded to anaconda.org/powerai.
 
The above is the documented process for using Travis to build, but still having secure uploads. More information at this link: https://docs.travis-ci.com/user/encryption-keys/
