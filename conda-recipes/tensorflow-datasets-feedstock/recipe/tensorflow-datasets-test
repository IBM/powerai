#!/bin/bash
# *****************************************************************
#
# Licensed Materials - Property of IBM
#
# (C) Copyright IBM Corp. 2019. All Rights Reserved.
#
# US Government Users Restricted Rights - Use, duplication or
# disclosure restricted by GSA ADP Schedule Contract with IBM Corp.
#
# *****************************************************************

if [ -z "$CONDA_PREFIX" ]
then
    echo "CONDA_PREFIX not set. A conda environment must be activated"
    echo "before running this command. Run:"
    echo "conda activate [<env>]"
    exit 1
fi

SYS_PYTHON_MAJOR=$(python -c "import sys;print(sys.version_info.major)")
SYS_PYTHON_MINOR=$(python -c "import sys;print(sys.version_info.minor)")
COMPONENT="tensorflow_datasets"
TF_DS_PKG_PATH=${CONDA_PREFIX}/lib/python${SYS_PYTHON_MAJOR}.${SYS_PYTHON_MINOR}/site-packages/$COMPONENT

if [ ! -d "$TF_DS_PKG_PATH" ]
then
   echo "The directory $TF_DS_PKG_PATH does not exist. Make sure the correct conda"
   echo "environment is activated."
   exit 1
fi

TMP_WORKINGDIR=""

cleanup() {
   popd
   if [ "$TMP_WORKINGDIR" != "" ]; then
     rm -rf $TMP_WORKINGDIR
   fi
}

catch_ctrlc() {
    cleanup
    exit 2
}

conda_packages_to_install=""
pip_packages_to_install=""

check_if_installed() {
  package_name=$1
  package_installer=$2
  case $package_installer in
    "conda")
       cmd=$(conda list $package_name)
       if [[ ! "$cmd" =~ "$package_name" ]]; then
         conda_packages_to_install+=" $package_name"
       fi
     ;;
    "pip")
       cmd=$(pip show $package_name)
       if [[ ! "$cmd" =~ "$package_name" ]]; then
         pip_packages_to_install+=" $package_name"
       fi
     ;; 
  esac 
}

# initialise trap to call catch_ctrlc function
# when signal 2 (SIGINT) is received
trap "catch_ctrlc" 2

check_if_installed "matplotlib" "conda"
check_if_installed "opencv" "conda"
check_if_installed "pydub" "pip"
check_if_installed "pretty_midi" "pip"
check_if_installed "mwparserfromhell" "pip"
check_if_installed "ffprobe" "pip"
check_if_installed "ffmpeg" "conda"

if [[ "$conda_packages_to_install" != "" ]] ; then
    echo "The following packages are necessary to run the example programs:$conda_packages_to_install"
    echo "Run: 'conda install$conda_packages_to_install' to install the packages"
    exit 1
fi

if [[ "$pip_packages_to_install" != "" ]]; then
    echo "The following packages are necessary to run the example programs:$pip_packages_to_install"
    echo "Run: 'pip install$pip_packages_to_install' to install the packages"
    exit 1
fi

TMP_WORKINGDIR="$(mktemp -d -t tfdstest.XXXXXX)"
pushd $TMP_WORKINGDIR

echo "========================================================================================================"
echo "Tensorflow datasets tests ..."
echo "========================================================================================================"

all_python_files=`find ${TF_DS_PKG_PATH}/ -name "*_test.py"`

skipped_files=("gcs_utils_test.py" "dataset_builder_beam_test.py" "lsun_test.py" "eager_not_enabled_by_default_test.py") 
declare -i total_tests=0
declare -i successful_tests=0
declare -i failed_tests=0
declare -i skipped_tests=0
for file in $all_python_files; do

  filename=`basename $file`
  total_tests+=1
  if [[ ! -z $(echo "${skipped_files[@]}" | grep -w $filename) ]]; then
    skipped_tests+=1
    continue;
  fi
  
  echo "-----------------------------------------------------------------------------------------------------";
  echo $file;
  echo "-----------------------------------------------------------------------------------------------------";

  python $file
  if [[ $? = 0 ]]; then
    successful_tests+=1
  else
    failed_tests+=1
  fi
  echo "=====================================================================================================";
done

cleanup
echo "=======================================================================================================";
echo "================================= Test Results Summary ================================================"
echo "Total Tests:   $total_tests"
echo "Tests Passed:  $successful_tests"
echo "Tests Failed:  $failed_tests"
echo "Tests Skipped: $skipped_tests"
echo "======================================================================================================="

if [[ $failed_tests > 0 ]]; then
  exit 1
fi

