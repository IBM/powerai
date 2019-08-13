## PowerAI Supplementary Channel

This directory contains community built recipes for additional conda packages often needed for running deep learning and machine learning python code on POWER. These recipes are automatically built on ppc64le arch from travis-ci.org (https://travis-ci.org/IBM/powerai). 

Packages that are built are published to https://anaconda.org/powerai/

Community PRs are welcome.

### Recipe Requests
To request a package recipe to be created and be built, open an issue with the following formatting.

 - Name of package: 
 - URL of package source code: 
 - License of package: 
 - List of package dependencies:
 - Short description of package and use case(s):

Folks who would also like to see this pacakge in the supplementary channel, please thumbs-up so the developers can know which requests to prioritize.

And if you'd like to contribute the package recipe (thank you!), see the instructions below.

### How to add a recipe to the repo

Recipes in this directory are modeled after the conda-forge build environment. Travis CI is used as the build service.

The top level travis.yml file (https://github.com/IBM/powerai/blob/master/.travis.yml) includes the secure tokens and the job list. The job list should be updated in your PR to include only your project. For example

```
jobs:
  include:

    # tensorflow-metadata recipe
    - stage: tensorflow-metadata
      language: generic

      os: linux-ppc64le

      env: CONFIG=linux_noarch UPLOAD_PACKAGES=True


      script:
          -  cd conda-recipes/tensorflow-metadata-feedstock
          -  ./ci_support/run_docker_build.sh
```

This is a job list adding in noarch package tensorflow-metadata on ppc64le. The `script` section should change into your directory and execute the `run_docker_build.sh` script.
Change this to only do your additional package (or fix). There is no need to run other recipes for publish if no changes are made there. Leave the secure tokens as is.

Your new recipe should include a `ci_support` directory with a `run_docker_build.sh` script. The only thing that may change here is the condarc defines for channel enablement. This directory should also include a `build_steps.sh` script. This one should not change much from existing ones aside from perhaps some slight customization.

The `build_steps.sh` script references a configuration file. Existing recipes have these in a `.ci_support` directory. An example configuration may look like:
```
c_compiler:
- gcc
c_compiler_version:
- '8'
channel_sources:
- conda-forge,defaults
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

These defines are used to define the build envionment, source channels and upload targets.

### Building
Travis is configured to build these recipes on Pull Requests. Packages will only be published, however, on code merges.
travis-ci.org does have build limits current (around 50mins or so), so long building recipes may be aborted.


