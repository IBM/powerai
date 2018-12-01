#!/bin/bash

input_file=powerai_1.5.4_requirements.txt
REPFILE="report_summary.rep"
LOGFILE="report_summary.log"
POWERAI_INSTALLED="NO"
POWERAI_LICENSE_ACCEPTED="NO"
LICENSE_BIN="/opt/DL/license/bin"



powerai_version=$(grep -Po "(?<=^powerai_version ).*" $input_file)
rhel_version=$(grep -Po "(?<=^rhel_version ).*" $input_file)
nvidia_version=$(grep -Po "(?<=^nvidia_version ).*" $input_file)
cuda_version=$(grep -Po "(?<=^cuda_version ).*" $input_file)
cudnn_version=$(grep -Po "(?<=^cudnn_version ).*" $input_file)
powerai_repo=$(grep -Po "(?<=^powerai_repo ).*" $input_file)
caffe_ver=$(grep -Po "(?<=^caffe_version ).*" $input_file)
tensorflow_ver=$(grep -Po "(?<=^tensorflow_version ).*" $input_file)
ddl_ver=$(grep -Po "(?<=^ddl_version ).*" $input_file)
snapml_ver=$(grep -Po "(?<=^snapml_version ).*" $input_file)
pytorch_ver=$(grep -Po "(?<=^pytorch_version ).*" $input_file)
anaconda_ver=$(grep -Po "(?<=^anaconda_version ).*" $input_file)

declare -r HELP_TEXT=\
"
  Usage: sh powerai_verification_tool.sh [<args>]
    This tool is to validate the pre-requisites of PowerAI (e.g. CUDA, NVIDIA driver, cuDNN) and
    verifies that PowerAI license is accepted.
    And, it also validates the installed frameworksas per the args passed in the command line..

Agruments:
  help           Display this help and exit
  caffe          Verifies caffe installation.
  tensorflow     Verifies tensorflow installation.
  pytroch        Verifies pytorch installation.
  ddl            Verifies ddl installation.
  snapml         Verifies snapml installation.
  all            Verifies all frameworks installation.  
"


if [[ "$#" -eq "0" || $1 = "help" ]]
then
    echo "${HELP_TEXT}"
    exit
else
    VALIDATE_FRAMEWORK=$1
fi

echo " #################################### Check Platform And OS ######################" 2>&1  >  "${LOGFILE}"
uname -a 2>&1 >> "${LOGFILE}"

PLATFORM_INFO=`uname -a`
IS_POWER=`uname -a | grep ppc64le | wc -l`
IS_POWER_ARCH="NO"
if [ "${IS_POWER}" != "0" ]
then
        echo " Power platform detected." 2>&1 | tee -a "${LOGFILE}"
        IS_POWER_ARCH="YES"
else
        echo "  Platform is not detected as power" 2>&1 | tee -a "${LOGFILE}"
        exit 1
fi

IS_X86=`uname -a | grep x86_64 | wc -l`
IS_X86_REP="NO"
if [ "${IS_X86}" != "0" ]
then
        echo " x86 platform detected." 2>&1 | tee -a "${LOGFILE}"
        IS_X86_REP="YES"
        exit 1
fi


echo " ################################### Check Operating System ##################################" 2>&1 >>  "${LOGFILE}"
OS_NAME=`cat /etc/*-release | grep "^NAME="`
OS_VERSION=`cat /etc/*-release | grep "^VERSION="`

if [[ $OS_NAME == *"Red Hat Enterprise Linux Server"* ]]; then
    echo " Detected RHEL operating system. Using yum to check packages." 2>&1 >> "${LOGFILE}"
fi

if [[ $OS_NAME == *"Ubuntu"* ]]; then
   echo " Detected Ubuntu operating system." 2>&1 >> "${LOGFILE}"
   exit 1
fi

if [[ $OS_VERSION != *$rhel_version* ]]; then
     echo " PowerAI Release $powerai_version requires Red Hat Enterprise Linux (RHEL) $rhel_version" 2>&1 | tee -a "${LOGFILE}"
     exit 1
fi

echo " ##################################### Check Number of Configured GPUs  ######################" 2>&1 >> "${LOGFILE}"

nv_ver=`modinfo nvidia|grep "^version:" | cut -f 1 -d '-' | sed 's/[^.,0-9]//g'`
NVIDIA_THERE=$?
echo "Nvidia-Version: $nv_ver" 2>&1 >> "${LOGFILE}" 

NVIDIA_THERE_REP="NO"
NUM_GPUS_ENABLED=0

if [ "${NVIDIA_THERE}" = "0" ]
then
    required_version=$nvidia_version
    installed_version=`nvidia-smi | grep NVIDIA-SMI | awk '{print $3}'`
        
    function version_ge() { test "$(echo "$@" | tr " " "\n" | sort -rV | head -n 1)" == "$1"; }
        
    if version_ge $installed_version $required_version; then
        echo " $installed_version is greater than or equal to $required_version." 2>&1 >> "${LOGFILE}"
    else
        echo " Installed version is less than $required_version,Please install the version >= $required_version" 2>&1 | tee -a  "${LOGFILE}"
        exit 1
     fi
     
     NUM_GPUS_ENABLED=`nvidia-smi | grep -e "|...[0-9]..T...................On" | wc -l`
     NVIDIA_THERE_REP="YES"
fi

IS_OPTIONAL_REPO_ENABLED="NO"
echo " Checking for optional repo enablement." 2>&1 >> "${LOGFILE}"
output=`sudo yum repolist enabled | grep PAIC-Optional`
if [ $? -eq 0 ]
then
   echo " RHEL7 powerle optional repos are enabled." 2>&1 >> "${LOGFILE}"
   IS_OPTIONAL_REPO_ENABLED="YES"
else
   echo " Optional repos are to be enabled to install PowerAI." 2>&1 | tee -a "${LOGFILE}"
   IS_OPTIONAL_REPO_ENABLED="NO"
fi

IS_EXTRAS_REPO_ENABLED="NO"
echo "Checking for extras repo enablement." 2>&1 >> "${LOGFILE}"
output=`sudo yum repolist enabled | grep PAIC-Extras`
if [ $? -eq 0 ]
then
    echo " RHEL7 powerle extras repo is enabled." 2>&1 >> "${LOGFILE}"
    IS_EXTRAS_REPO_ENABLED="YES"
else
    echo " Extras repo is to be enabled to install PowerAI." 2>&1 | tee -a  "${LOGFILE}"
    IS_EXTRAS_REPO_ENABLED="NO"
fi

IS_EPEL_REPO_ENABLED="NO"
echo " Checking for EPEL repo enablement." 2>&1 >> "${LOGFILE}"
output=`sudo yum repolist all | grep PAIC-Epel`
if [ $? -eq 0 ]
then
    echo " EPEL repo is enabled." 2>&1 >> "${LOGFILE}"
    IS_EPEL_REPO_ENABLED="YES"
else
    echo " EPEL repo is to be enabled to install PowerAI." 2>&1 | tee -a "${LOGFILE}"
    IS_EPEL_REPO_ENABLED="NO"
fi

IS_CUDA_INSTALLED="NO"
echo " Checking for CUDA enablment."  2>&1 >> "${LOGFILE}"
output=`sudo rpm -qa | grep cuda`
if [ $? -eq 0 ]
then
   current_cuda_version=`sed -e 's#.*Version\(\)#\1#' <<< cat /usr/local/cuda/version.txt`
   echo " CUDA version=$current_cuda_version" 2>&1 >> "${LOGFILE}"
   if [ $VALIDATE_FRAMEWORK = $powerai_version ]
   then 
       if version_ge $current_cuda_version $cuda_version;
       then
          echo " CUDA $current_cuda_version is greater than or equal to $cuda_version."  2>&1 >> "${LOGFILE}"
       else
          echo " Installed $current_cuda_version,Please install CUDA $cuda_version for $powerai_version Release."  2>&1 | tee -a "${LOGFILE}"
       fi
   fi
   echo " CUDA $current_cuda_version version is installed." 2>&1 >> "${LOGFILE}"
else
   echo " CUDA is to be installed properly to use PowerAI."  2>&1 | tee -a "${LOGFILE}"
   exit 1
fi

echo " Checking for softlink cuda->$cuda_version "  2>&1 >> "${LOGFILE}"
RESULT=`ls -l /usr/local/cuda | awk '{print $NF }'`
if [ $RESULT = "cuda-10.0" ]
then
    echo " Cuda-$current_cuda_version Linked correctly."  2>&1 >> "${LOGFILE}"
    IS_CUDA_INSTALLED="YES"
else
    echo " Cuda-$current_cuda_version is not linked properly"  2>&1 | tee -a  "${LOGFILE}"

fi
IS_CUDNN_INSTALLED="NO"
major_level=`cat /usr/local/cuda/include/cudnn.h | grep "#define CUDNN_MAJOR" | awk '{print $3}'`
minor_level=`cat /usr/local/cuda/include/cudnn.h | grep "#define CUDNN_MINOR" | awk '{print $3}'`

installed_cudnn_version=$major_level.$minor_level
if [ $? -eq 0 ]
then
   if [ $VALIDATE_FRAMEWORK = $powerai_version ]
   then
      echo " Installed version=$installed_cudnn_version" 2>&1 >> "${LOGFILE}"
      if [ $installed_cudnn_version = $cudnn_version ]
      then
          echo " Installed $cudnn_version for $VALIDATE_FRAMEWORK" 2>&1 >> "${LOGFILE}"
      else
          echo " PowerAI release $powerai_version requires cuDNN $cudnn_version" 2>&1 | tee -a  "${LOGFILE}"
      fi
   fi
   echo " cuDNN $installed_cudnn_version version installed."  2>&1 >> "${LOGFILE}"
   IS_CUDNN_INSTALLED="YES"
else
   echo " cuDNN is to be installed properly to install PowerAI."  2>&1 | tee -a "${LOGFILE}"
   IS_CUDNN_INSTALLED="NO"

fi

echo " ##################################### REPORT SUMMARY  ######################" 2>&1 > "${REPFILE}"
echo " System info: ${PLATFORM_INFO}" 2>&1 >> "${REPFILE}"
echo " Is Power platform: ${IS_POWER_ARCH}" 2>&1 >> "${REPFILE}"
echo " Is x86 platform: ${IS_X86_REP}" 2>&1 >> "${REPFILE}"
echo " OS Name: ${OS_NAME}" 2>&1 >> "${REPFILE}"
echo " OS Version: ${OS_VERSION}" 2>&1 >> "${REPFILE}"
echo " Is NVIDIA installed: ${NVIDIA_THERE_REP}" 2>&1 >> "${REPFILE}"
echo " Number of enabled GPUs: ${NUM_GPUS_ENABLED}" 2>&1 >> "${REPFILE}"

validate_anaconda(){
       IS_ANACONDA_INSTALLED="NO"
       ANACONDA_VER=`which conda | grep anaconda | wc -l`
       if [ "${ANACONDA_VER}" != "0" ]
       then
          echo " Anaconda is installed sucessfully."  2>&1 | tee -a "${LOGFILE}"
          IS_ANACONDA_INSTALLED="YES"
       else
          echo " Anaconda is not installed.Anaconda is required for all frameworkd"  2>&1 | tee -a "${LOGFILE}"
          IS_ANACONDA_INSTALLED="NO"
       fi

      anaconda_version1=$(conda list | grep "^anaconda " | awk '{print $2}')
      if [ $anaconda_version1 = $anaconda_ver ]
      then
          echo " Anaconda version: ${anaconda_ver} configured sucessfully." 2>&1 | tee -a "${LOGFILE}"
	  echo " Anaconda is installed sucessfully."  2>&1 >> "${REPFILE}"
	  echo " Anaconda version: ${anaconda_ver} configured sucessfully." 2>&1 >> "${REPFILE}"
      else
          echo " Anaconda version: ${anaconda_ver} is supported for POWERAI $powerai_version but Anaconda ${anaconda_version1} is configured" 2>&1 | tee -a "${LOGFILE}"
     fi

}

validate_anaconda


IS_MLDL_REPO_INSTALLED="NO"
echo " Check for mldl-repo-local installation." 2>&1 >> "${LOGFILE}"
sudo rpm -qa | egrep 'mldl-repo' > /dev/null
if [ $? -eq 0 ]
then
   echo " mldl-repo-local installed sucessfully" 2>&1 >> "${LOGFILE}"
   IS_MLDL_REPO_INSTALLED="YES"
else
   echo " mldl-repo-local is not installed " 2>&1 | tee -a "${LOGFILE}"
   IS_MLDL_REPO_INSTALLED="NO"
   exit 1
fi

POWER_MLDL_REPO_INSTALLED="NO"
echo " Check for power-mldl installation." 2>&1 >> "${LOGFILE}"
sudo rpm -qa | egrep 'power-mldl' > /dev/null
if [ $? -eq 0 ]
then
   echo " power-mldl installed sucessfully" 2>&1 >> "${LOGFILE}"
   POWER_MLDL_REPO_INSTALLED="YES"
else
   echo " power-mldl is not installed " 2>&1 | tee -a "${LOGFILE}"
   POWER_MLDL_REPO_INSTALLED="NO"
   exit 1
fi

if [ -e $LICENSE_BIN/check-powerai-license.sh ]; then
  $LICENSE_BIN/check-powerai-license.sh
  if [ $? -ne 0 ]
  then
      echo " PowerAI license is to be accpeted to activate the frameworks." 2>&1 | tee -a  "${LOGFILE}"
      POWERAI_LICENSE_ACCEPTED="NO"
      exit 1
  else
     echo " PowerAI license is accpeted." 2>&1 >> "${LOGFILE}"
     echo " PowerAI installed sucessfully" 2>&1 | tee -a "${REPFILE}"
     POWERAI_LICENSE_ACCEPTED="YES"
  fi
else
   echo " PowerAI is not installed properly." 2>&1 | tee -a  "${LOGFILE}"
   exit 1
fi


echo " Is PowerAI License accepted: ${POWERAI_LICENSE_ACCEPTED}" 2>&1 >> "${REPFILE}"




validate_ddl(){  
    # Initialize report vars
    #IS_DDL_INSTALLED="0"
    IS_DDL_INSTALLED_REP="NO"
    DDL_INFO=""
    IS_DDL_ACTIVE="0"
    IS_DDL_ACTIVE_REP="NO"

    IS_DDL_INSTALLED=`sudo rpm -qa | grep power-ddl | wc -l`
    if [ "${IS_DDL_INSTALLED}" != "0" ]
    then
        echo " DDL is installed." 2>&1 >> "${LOGFILE}"
        DDL_INFO=`sudo yum list | grep -E '(^|\s)power-ddl.ppc64le($|\s)'`
        IS_DDL_INSTALLED_REP="YES"
    else
       echo " DDL is not installled."  2>&1 | tee -a "${LOGFILE}"
       #exit 1
   fi
   
   # If tensoflow is installed, on PowerAI we need to activate it
   if [ "${IS_DDL_INSTALLED}" != "0" ]
   then
       if [ $POWERAI_LICENSE_ACCEPTED = "YES" ]
       then
           echo " Activating DDL." 2>&1 >> "${LOGFILE}"
           source /opt/DL/ddl/bin/ddl-activate
           if [ $? -eq 0 ]
           then
             	 echo " DDL activated sucessfully" 2>&1 >> "${LOGFILE}"
          	 IS_DDL_INSTALLED_REP="YES"
       	   else
          	 /opt/DL/tensorflow/bin/install_dependencies -y
          	 source /opt/DL/ddl/bin/ddl-activate
                 if [ $? -eq 0 ]
                 then
            	 	echo " DDL activated sucessfully" 2>&1 >> "${LOGFILE}"
                 	IS_DDL_INSTALLED_REP="YES"
           	 else
           	 	echo " DDL is not activated correctly"
	         	IS_DDL_INSTALLED_REP="NO"	
          	 fi
       	   fi    
       else
           echo " Please accept PowerAI license to activate DDL." 2>&1 | tee -a "${LOGFILE}"
           IS_DDLINSTALLED_REP="NO"
        fi
   fi


   # Perform sample application test
  if [ "${IS_DDL_INSTALLED}" != "0" ]
   then
        echo " Beginning sample application test!" 2>&1 >> "${LOGFILE}"
     	 ddlrun ls >> "${LOGFILE}" 2>&1

        IS_DDL_ACTIVE=$?
        if [ "${IS_DDL_ACTIVE}" = "0" ]
        then
            echo " DDL is operational." 2>&1 >> "${LOGFILE}"
            IS_DDL_ACTIVE_REP="YES"
            ddl_version=$(echo $DDL_INFO | awk '{print $2}')
            echo " DDL version: $ddl_version" 2>&1 >> "${REPFILE}"

           # echo " DDL $ddl_version installed sucessfully"
        fi
    fi
    
    echo " ##################################### DDL Status  ######################" 2>&1 >> "${REPFILE}"
    echo " Is DDL installed: ${IS_DDL_INSTALLED_REP}" 2>&1 >> "${REPFILE}"
    echo " Is DDL operational: ${IS_DDL_ACTIVE_REP}" 2>&1 >> "${REPFILE}"
    ddl_version=$(echo $DDL_INFO | awk '{print $2}')
    ddl_version1=$(echo $ddl_version | cut -f1 -d-)
#    echo "DDL version: $ddl_version1" 2>&1 > "${REPFILE}"
    if [ "$ddl_version1" = "$ddl_ver" ]
    then
       echo " DDL version: ${ddl_version}" installed sucessfully. 2>&1 | tee -a "${REPFILE}"
    else
       echo " DDL version: ${ddl_ver} is supported with $powerai_version but DDL ${ddl_version1} is installed" 2>&1 | tee -a "${REPFILE}"
    fi
}

validate_snapml(){  
    # Initialize report vars
    IS_SNAPML_INSTALLED="0"
    IS_SNAPML_INSTALLED_REP="NO"
    SNAPML_INFO=""
    IS_SNAPML_ACTIVE="0"
    IS_SNAPML_ACTIVE_REP="NO"

    IS_SNAPML_INSTALLED=`sudo rpm -qa | grep power-snapml | wc -l`
    if [ "${IS_SNAPML_INSTALLED}" != "0" ]
    then
        echo " SNAPML is installed." 2>&1 >> "${LOGFILE}"
        SNAPML_INFO=`sudo yum list | grep -E '(^|\s)power-snapml.ppc64le($|\s)'`
        IS_SNAPML_INSTALLED_REP="YES"
    else
       echo " SNAPML is not installled."  2>&1 | tee -a "${LOGFILE}"
       #exit 1
   fi
   
   # If SNAPML is installed, on PowerAI we need to activate it
   if [ "${IS_SNAPML_INSTALLED}" != "0" ]
   then
       if [ $POWERAI_LICENSE_ACCEPTED = "YES" ]
       then
           echo " Activating SNAPML." 2>&1 >> "${LOGFILE}"

           source /opt/DL/snap-ml-mpi/bin/snap-ml-mpi-activate
           if [ $? -eq 0 ]
           then
              echo " SNAPML activated sucessfully" 2>&1 >> "${LOGFILE}"
              IS_SNAPML_INSTALLED_REP="YES"
           else
              /opt/DL/snap-ml-mpi/bin/install_dependencies -y
              if [ $? -eq 0 ]
              then
                 source /opt/DL/snap-ml-mpi/bin/snap-ml-mpi-activate
                 echo " SNAPML activated sucessfully" 2>&1 >> "${LOGFILE}"
                 IS_SNAPML_INSTALLED_REP="YES"
              else
                 echo " SNAPML is not activated correctly"
                 IS_SNAPML_INSTALLED_REP="NO"
              fi
           fi
        else
			echo " Please accept PowerAI license to activate SnapML." 2>&1 | tee -a "${LOGFILE}"
			IS_SNAPML_INSTALLED_REP="NO"
		fi

   fi

   # Perform sample application test
  if [ "${IS_SNAPML_INSTALLED}" != "0" ]
   then
        echo " Beginning sample application test!" 2>&1 >> "${LOGFILE}"
     	 snaprun ls >> "${LOGFILE}" 2>&1
        IS_SNAPML_ACTIVE=$?
        if [ "${IS_SNAPML_ACTIVE}" = "0" ]
        then
            echo " SNAPML is operational." 2>&1 >> "${LOGFILE}"
            IS_SNAPML_ACTIVE_REP="YES"
            snapml_version=$(echo $SNAPML_INFO | awk '{print $2}')
            echo " SNAPML version: $snap_ml_version" 2>&1 >> "${REPFILE}"

            #echo " SNAPML $snapml_version installed sucessfully"
		else
		    echo " SNAPML is not operational." 2>&1 >> "${LOGFILE}"
			S_SNAPML_ACTIVE_REP="NO"
        fi
    fi
    
    echo " ##################################### SNAPML Status  ######################" 2>&1 >> "${REPFILE}"
    echo " Is SNAPML installed: ${IS_SNAPML_INSTALLED_REP}" 2>&1 >> "${REPFILE}"
    echo " Is SNAPML operational: ${IS_SNAPML_ACTIVE_REP}" 2>&1 >> "${REPFILE}"
    snapml_version=$(echo $SNAPML_INFO | awk '{print $2}')

    snapml_version1=$(echo $snapml_version | cut -f1 -d-)
    if [ "$snapml_version1" = "$snapml_ver" ]
    then
       echo " SNAPML version: ${snapml_version}" installed sucessfully. 2>&1 | tee -a "${REPFILE}"
    else
       echo " SNAPML version: ${snapml_ver} is supported with $powerai_version but SNAPML ${snapml_version1} is installed" 2>&1 |tee -a "${REPFILE}"
    fi
}

validate_tensorflow(){  
    # Initialize report vars
    IS_TENSORFLOW_INSTALLED="0"
    IS_TENSORFLOW_INSTALLED_REP="NO"
    TENSORFLOW_INFO=""
    IS_TENSORFLOW_ACTIVE="0"
    IS_TENSORFLOW_ACTIVE_REP="NO"

    IS_TENSORFLOW_INSTALLED=`sudo yum list | grep tensorflow | wc -l`
    if [ "${IS_TENSORFLOW_INSTALLED}" != "0" ]
    then
        echo " Tensorflow is installed." 2>&1 >> "${LOGFILE}"
        TENSORFLOW_INFO=`sudo yum list | grep -E '(^|\s)tensorflow.ppc64le($|\s)'`
        IS_TENSORFLOW_INSTALLED_REP="YES"
    else
       echo " Tensorflow is not installled."  2>&1 | tee -a "${LOGFILE}"
   #    exit 1
   fi
   
   # If tensoflow is installed, on PowerAI we need to activate it
   if [ "${IS_TENSORFLOW_INSTALLED}" != "0" ]
   then
       if [ $POWERAI_LICENSE_ACCEPTED = "YES" ]
       then
           echo " Activating tensorflow." 2>&1 >> "${LOGFILE}"

           source /opt/DL/tensorflow/bin/tensorflow-activate
           if [ $? -eq 0 ]
           then
              echo " Tensorflow activated sucessfully" 2>&1 >> "${LOGFILE}"
              IS_TENSORFLOW_INSTALLED_REP="YES"
           else
              /opt/DL/tensorflow/bin/install_dependencies -y
              source /opt/DL/tensorflow/bin/tensorflow-activate
              if [ $? -eq 0 ]
              then
                 echo " Tensorflow activated sucessfully" 2>&1 >> "${LOGFILE}"
                 IS_TENSORFLOW_INSTALLED_REP="YES"
              else
                 echo " Tensorflow is not activated correctly"
                 IS_TENSORFLOW_INSTALLED_REP="NO"
              fi
           fi
       else
           echo " Please accept PowerAI license to activate tensorflow." 2>&1 | tee -a "${LOGFILE}"
           IS_TENSORFLOW_INSTALLED_REP="NO"
           exit 1
        fi
   fi


   # Perform sample application test
   if [ "${IS_TENSORFLOW_INSTALLED}" != "0" ]
   then
        echo " Beginning sample application test!" 2>&1 >> "${LOGFILE}"
        python -c "import tensorflow" >> "${LOGFILE}" 2>&1

        IS_TENSORFLOW_ACTIVE=$?
        if [ "${IS_TENSORFLOW_ACTIVE}" = "0" ]
        then
            echo " Tensorflow is operational." 2>&1 >> "${LOGFILE}"
            IS_TENSORFLOW_ACTIVE_REP="YES"
            tf_version=$(echo $TENSORFLOW_INFO | awk '{print $2}')
            echo " Tensorflow version: $tf_version" 2>&1 >> "${REPFILE}"

            #echo " Tensorflow $tf_version installed sucessfully"
        fi
    fi
    
    echo " ##################################### Tensorflow Status  ######################" 2>&1 >> "${REPFILE}"
    echo " Is Tensorflow installed: ${IS_TENSORFLOW_INSTALLED_REP}" 2>&1 >> "${REPFILE}"
    echo " Is Tensorflow operational: ${IS_TENSORFLOW_ACTIVE_REP}" 2>&1 >> "${REPFILE}"
    tf_version=$(echo $TENSORFLOW_INFO | awk '{print $2}')
    tf_version1=$(echo $tf_version | cut -f1 -d-)
#    echo "Tensorflow version: $tf_version1" 2>&1 > "${REPFILE}"
    if [ "$tf_version1" = "$tensorflow_ver" ]
    then
       echo " Tensorflow version: ${tf_version}" installed sucessfully. 2>&1 | tee -a "${REPFILE}"
    else
       echo " Tensorflow version: ${tensorflow_ver} is supported with $powerai_version but tensorflow ${tf_version1} is installed" 2>&1 | tee -a "${REPFILE}"
    fi
}


validate_caffe() {
    # Initialize report vars
    IS_BVLC_CAFFE_INSTALLED="0"
    IS_BVLC_CAFFE_INSTALLED_REP="NO"
    IS_IBM_CAFFE_INSTALLED="0"
    IS_IBM_CAFFE_INSTALLED_REP="NO"

    BVLC_CAFFE_INFO=""
    IBM_CAFFE_INFO=""

    IS_BVLC_CAFFE_ACTIVE="0"
    IS_BVLC_CAFFE_ACTIVE_REP="NO"

    IS_IBM_CAFFE_ACTIVE="0"
    IS_IBM_CAFFE_ACTIVE_REP="NO"

    IS_CAFFE_INSTALLED="0"
    IS_CAFFE_INSTALLED_REP="NO"
    IS_CAFFE_OPERATIONAL_REP="NO"


    IS_BVLC_CAFFE_INSTALLED=`sudo yum list | grep caffe-bvlc | wc -l`

    if [ "${IS_BVLC_CAFFE_INSTALLED}" != "0" ]
    then
        BCLC_CAFFE_INFO=`sudo yum list | grep caffe-bvlc`
        IS_BVLC_CAFFE_INSTALLED_REP="YES"
    fi

    IS_IBM_CAFFE_INSTALLED=`sudo yum list | grep caffe-ibm | wc -l`

    if [ "${IS_IBM_CAFFE_INSTALLED}" != "0" ]
    then
        IBM_CAFFE_INFO=`sudo yum list | grep caffe-ibm`
        IS_IBM_CAFFE_INSTALLED_REP="YES"
    fi

    # For PowerAI - activate caffe-ibm to prepare for test
    if [ "${IS_IBM_CAFFE_INSTALLED}" != "0" ]
    then
        echo " Activating IBM Caffe." 2>&1 >> "${LOGFILE}"
        #source ~/.bashrc

        source /opt/DL/caffe-ibm/bin/caffe-activate
        if [ $? -eq 0 ]
        then
           echo " Caffe activated sucessfully" 2>&1 >> "${LOGFILE}"
        else
           /opt/DL/caffe-ibm/bin/install_dependencies -y
           source /opt/DL/caffe-ibm/bin/caffe-activate
           if [ $? -eq 0 ]
           then
              echo " Caffe activated sucessfully" 2>&1 >> "${LOGFILE}"
           else
              echo " Caffe is not activated correctly"
           fi
        fi
    fi

    # If either IBM or BLVC Caffe is installed then Caffe is installed
    #if [ [ "${IS_IBM_CAFFE_INSTALLED_REP}" == "YES" ] || [ "${IS_BVLC_CAFFE_INSTALLED_REP}" != "YES" ] ]
    
   if [ ["${IS_IBM_CAFFE_INSTALLED_REP}" == "YES" ] && [ "${IS_BVLC_CAFFE_INSTALLED_REP}" == "YES" ] ]
   then
        IS_CAFFE_INSTALLED="YES"
    fi
 
    
    # Sample application test
    if [ "${IS_CAFFE_INSTALLED}" == "0" ]
    then

        # Test the first GPU for now
        echo " Performing Caffe gpu test." 2>&1 >> "${LOGFILE}"
        caffe device_query -gpu 0 >> "${LOGFILE}" 2>&1
        if [ $? = "0" ]
        then
                IS_CAFFE_OPERATIONAL_REP="YES"
        fi

    fi

    echo " ##################################### Caffe Status  ######################" 2>&1 >> "${REPFILE}"
    echo " Is BVLC Caffe installed: ${IS_BVLC_CAFFE_INSTALLED_REP}" 2>&1 >> "${REPFILE}"
    for LINE in $BCLC_CAFFE_INFO
    do
        echo " BLVC Caffe version: ${LINE}" 2>&1 >> "${REPFILE}"
    done

    echo " Is IBM Caffe installed: ${IS_BVLC_CAFFE_INSTALLED_REP}" 2>&1 >> "${REPFILE}"
    caffe_version=$(echo $IBM_CAFFE_INFO | awk '{print $2}')
    caffe_version1=$(echo $caffe_version | cut -f1 -d-) 
    if [ "$caffe_version1" = "$caffe_ver" ]
    then
       echo " IBM Caffe version: ${caffe_version}" installed sucessfully. 2>&1 | tee -a "${REPFILE}"
    else
       echo " Caffe version: ${caffe_ver} is supported with $powerai_version but caffe ${caffe_version} is installed" 2>&1 | tee -a "${REPFILE}"
    fi

    echo " Is Caffe operational: ${IS_CAFFE_OPERATIONAL_REP}" 2>&1 >> "${REPFILE}"
}


validate_pytorch(){  
    # Initialize report vars
    IS_PYTORCH_INSTALLED="0"
    IS_PYTORCH_INSTALLED_REP="NO"
    PYTORCH_INFO=""
    IS_PYTORCH_ACTIVE="0"
    IS_PYTORCH_ACTIVE_REP="NO"

    IS_PYTORCH_INSTALLED=`sudo yum list | grep pytorch | wc -l`
    if [ "${IS_PYTORCH_INSTALLED}" != "0" ]
    then
        echo " PYTORCH is installed." 2>&1 >> "${LOGFILE}"
        PYTORCH_INFO=`sudo yum list | grep -E '(^|\s)pytorch.ppc64le($|\s)'`
        IS_PYTORCH_INSTALLED_REP="YES"
    else
       echo " PYTORCH is not installled."  2>&1 | tee -a "${LOGFILE}"
       exit 1
   fi
   
   # If tensoflow is installed, on PowerAI we need to activate it
   if [ "${IS_PYTORCH_INSTALLED}" != "0" ]
   then
       if [ $POWERAI_LICENSE_ACCEPTED = "YES" ]
       then
           echo " Activating PYTORCH." 2>&1 >> "${LOGFILE}"

           source /opt/DL/pytorch/bin/pytorch-activate
	   if [ $? -eq 0 ]
       	   then
          	echo " PYTORCH activated sucessfully" 2>&1 >> "${LOGFILE}"
          	IS_PYTORCH_INSTALLED_REP="YES"
           else
          	/opt/DL/pytorch/bin/install_dependencies -y
          	source /opt/DL/pytorch/bin/pytorch-activate
                if [ $? -eq 0 ]
                then
             		echo " PYTORCH activated sucessfully" 2>&1 >> "${LOGFILE}"
             		IS_PYTORCH_INSTALLED_REP="YES"
           	else
             		echo " PYTORCH is not activated correctly"
	   		IS_PYTORCH_INSTALLED_REP="NO"	
           	fi
       	   fi
      
   else
           echo " Please accept PowerAI license to activate PYTORCH." 2>&1 | tee -a "${LOGFILE}"
           IS_PYTORCH_INSTALLED_REP="NO"
           exit 1
        fi
   fi


   # Perform sample application test
  if [ "${IS_PYTORCH_INSTALLED}" != "0" ]
   then
        echo " Beginning sample application test!" 2>&1 >> "${LOGFILE}"
    	python -c "import torch" >> "${LOGFILE}" 2>&1
        IS_PYTORCH_ACTIVE=$?
        if [ "${IS_PYTORCH_ACTIVE}" = "0" ]
        then
            echo " PYTORCH is operational." 2>&1 >> "${LOGFILE}"
            IS_PYTORCH_ACTIVE_REP="YES"
            pytorch_version=$(echo $PYTORCH_INFO | awk '{print $2}')
            echo " Pytorch version: $pytorch_version" 2>&1 >> "${REPFILE}"

            #echo " pytorch $pytorch_version installed sucessfully"
        fi
    fi
    
    echo " ##################################### PYTORCH Status  ######################" 2>&1 >> "${REPFILE}"
    echo " Is PYTORCH installed: ${IS_PYTORCH_INSTALLED_REP}" 2>&1 >> "${REPFILE}"
    echo " Is PYTORCH operational: ${IS_PYTORCH_ACTIVE_REP}" 2>&1 >> "${REPFILE}"
    pytorch_version=$(echo $PYTORCH_INFO | awk '{print $2}')
    pytorch_version1=$(echo $pytorch_version | cut -f1 -d-)
#    echo "pytorch version: $pytorch_version1" 2>&1 > "${REPFILE}"
    if [ "$pytorch_version1" = "$pytorch_ver" ]
    then
       echo " Pytorch version: ${pytorch_version}" installed sucessfully. 2>&1 | tee -a "${REPFILE}"
    else
       echo " Pytorch version: ${pytorch_ver} is supported with $powerai_version but PYTORCH ${pytorch_version1} is installed" 2>&1 | tee -a "${REPFILE}"
    fi
}


if [ $VALIDATE_FRAMEWORK = "tensorflow" ]
then
    validate_tensorflow
fi

if [ $VALIDATE_FRAMEWORK = "caffe" ]
then
    validate_caffe
fi

if [ $VALIDATE_FRAMEWORK = "ddl" ]
then
    validate_ddl
fi

if [ $VALIDATE_FRAMEWORK = "snapml" ]
then
    validate_snapml
fi

if [ $VALIDATE_FRAMEWORK = "pytorch" ]
then
    validate_pytorch
fi

if [ $VALIDATE_FRAMEWORK = "all" ]
then
    validate_tensorflow
    validate_caffe
    validate_pytorch
    validate_ddl
    validate_snapml
    
fi

echo "---------------------------------------------------------------------"
echo " Item                                |status"
echo "---------------------------------------------------------------------"
echo "Is Power Platform                    |${IS_POWER_ARCH}   "
echo "RHEL OS Version                      |${OS_VERSION}"
echo "Number of GPUs enabled               |${NUM_GPUS_ENABLED}"
echo "Optional repos enabled               |${IS_OPTIONAL_REPO_ENABLED}"
echo "Extras repo enabled                  |${IS_EXTRAS_REPO_ENABLED}"
echo "EPEL repo enabled                    |${IS_EPEL_REPO_ENABLED}"
echo "CUDA Operational                     |${IS_CUDA_INSTALLED}"
echo "cuDNN Operational                    |${IS_CUDNN_INSTALLED}"
echo "Is Repository package installed      |${IS_MLDL_REPO_INSTALLED}"
echo "Is power-mldl installed              |${POWER_MLDL_REPO_INSTALLED}"
echo "Is PowerAI License accepted          |${POWERAI_LICENSE_ACCEPTED}"
echo "IS Anaconda installed                |${IS_ANACONDA_INSTALLED}"
echo "Is Caffe Operational                 |${IS_CAFFE_OPERATIONAL_REP}"
echo "Is Tensorflow Operational            |${IS_TENSORFLOW_ACTIVE_REP}"
echo "Is Pytorch Operational               |${IS_PYTORCH_ACTIVE_REP}"
echo "Is DDL Operational                   |${IS_DDL_ACTIVE_REP}"
echo "Is SNAPML Operational                |${IS_SNAPML_ACTIVE_REP}"
exit 
