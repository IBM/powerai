#!/usr/bin/env sh

# restore pre-existing RSTUDIO_WHICH_R
if [[ ! -z ${RSTUDIO_WHICH_R_PREV+x} ]]; then
  export RSTUDIO_WHICH_R="$RSTUDIO_WHICH_R_PREV"
  unset RSTUDIO_WHICH_R_PREV
else
  unset RSTUDIO_WHICH_R
fi
