################################################################################
# cpuset_check.sh
#
# Due to a race condition between Kubernetes and/or docker, and the
# onlining of GPU memory, services may start without all GPUs causing
# CUDA failures.
#
# As described in https://bugzilla.redhat.com/show_bug.cgi?id=1746415
# If Kubernetes, or others create their cgroup slice before the all GPU
# Memory is available, they will have an incomplete list.  This causes
# issues when a container has access to a GPU's device, but it's memory
# does not show up in the cpuset.mems file.  Leading to a CUDA intiliazation
# error
#
# This script provides a workaround allowing users to effectively remove the
# incorrect slices, and allow the services (docker, kubernetes, etc) to rebuild
# with the correct values taken from the original cpuset.mems.
#
# (C) Copyright IBM Corp. 2019. All Rights Reserved.
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
#
###############################################################################
#!/bin/bash
CPUSET_DIR=/sys/fs/cgroup/cpuset
CPUSET_ORIG=$CPUSET_DIR/cpuset.mems
DOCKER_DIR=$CPUSET_DIR/docker
SYSTEM_DIR=$CPUSET_DIR/system.slice
KUBE_DIR=$CPUSET_DIR/kubepods.slice

DOCKER_MSG="DOCKER SLICE   ($DOCKER_DIR) AFFECTED .............. "
KUBERS_MSG="KUBEPODS SLICE ($KUBE_DIR) AFFECTED .... "
SYSTEM_MSG="SYSTEM SLICE   ($SYSTEM_DIR) AFFECTED ........ "

#######################################
# Display usage information
# Globals:
#   None
# Arguments:
#   None
# Returns:
#   None
#######################################
function usage
{
    echo "usage: cpuset_check.sh [[--correct ] | [-h]]"
    echo "Check if cpuset slices are out of sync with master cpuset"
    echo -e "\n\t--correct  Attempt to correct any slices that are out of sync\n"
    echo -e "\t--force  Force correction without prompting user\n"
    echo -e "\t--use_move  Use mv command and move slice directory instead of attempting rmdir\n"
    echo -e "\t--gpucheck Check if the gpu memory has come online"
    echo -e "\t\tReturn Code 0 = gpu memory online and available \n\t\tReturn Code 1 = Still waiting for gpu memory"
}

#######################################
# Check if script has sudo/root authority
# Globals:
#   None
# Arguments:
#   None
# Returns:
#   None
#######################################
function checkElevation {
    if [ "$EUID" -ne 0 ] ; then
        echo "ERROR: Need to run with elevated permissions to wipe cgroup slices."
        exit 1
    fi
}

#######################################
# Check if we are POWER9 based.
# Globals:
#   None
# Arguments:
#   None
# Returns:
#   None
#######################################
function isPOWER9 {
    cat /proc/cpuinfo | grep -q POWER9
    if [ "$?" -ne 0] ; then
        return 0
    else
        return 1
    fi
}

#######################################
# Collect number of V100 GPUs we expect
# Globals:
#   None
# Arguments:
#   None
# Returns:
#   None
#######################################
function getV100Count {
    v100=`lspci | grep -i V100 | wc -l`
}

#######################################
# Collect number of V100 GPUs we expect
# Globals:
#   None
# Arguments:
#   None
# Returns:
#   None
#######################################
function calculateCpuset {
    getV100Count
    cpuset="0,8"
    if [ $v100 -eq "0" ] ; then
        echo "INFO: There are no V100 GPUs detected."
        gpumemset=
    elif [ $v100 -eq "1" ] ; then
        gpumemset=",255"
    elif [ $v100 -eq "2" ] ; then
        gpumemset=",254,255"
    elif [ $v100 -eq "3" ] ; then
        gpumemset=",253-255"
    elif [ $v100 -eq "4" ] ; then
        gpumemset=",252-255"
    fi
    targetcpuset=$cpuset$gpumemset
}

#######################################
# Check if calculated cpuset.mems equals system version
# Globals:
#   None
# Arguments:
#   None
# Returns:
#   0 - cpuset.mems matches what we expected
#   1 - cpuset.mems does not match
#######################################
function isGpuMemReady {
    calculateCpuset
    cpuset_cur=$(cat $CPUSET_DIR/cpuset.mems)
    if [ "$cpuset_cur" == "$targetcpuset" ]; then
        echo "SUCCESS: Generated cpuset $cpuset_cur matches target cpuset.mems."
        return 0
    else
        echo "INFO: GPU Memory doesn't match cpuset.mems.  Memory still onlining"
        return 1
    fi
}
#######################################
# Check if docker slice directory exists under
# /sys/fs/cgroups/cpuset/
# used by docker-ce
# Globals:
#   DOCKER_DIR
# Arguments:
#   None
# Returns:
#   1 - "docker" slice directory exists
#   0 - "docker" slice directory does not exist
#######################################
function isDockerSlice {
    if [ ! -d "$DOCKER_DIR" ]; then
        return 1
    else
        return 0
    fi
}

#######################################
# Check if system slice directory exists under
# /sys/fs/cgroups/cpuset/
# used by RHEL docker
# Globals:
#   SYSTEM_DIR
# Arguments:
#   None
# Returns:
#   1 - system.slice directory exists
#   0 - system.slice slice directory does not exist
#######################################
function isSystemSlice {
    if [ ! -d "$SYSTEM_DIR" ]; then
        return 1
    else
        return 0
    fi
}

#######################################
# Check if kubernetes slice directory exists under
# /sys/fs/cgroups/cpuset/ty
# Globals:
#   KUBE_DIR
# Arguments:
#   None
# Returns:
#   1 - kubepods.slice directory exists
#   0 - kubepods.slice directory does not exist
#######################################
function isKubeSlice {
    if [ ! -d "$KUBE_DIR" ]; then
        return 1
    else
        return 0
    fi
}

##############################################################
# Check if the cpuset.mems between two directories are equal
# directories are equal
# Globals:
#   left
#   right
# Arguments:
#   1 - first directory to compare
#   2 - second directory to compare
# Returns:
#   0 - cpuset.mems are equal
#   1 - cpuset.mems aren't equal
##############################################################
function isMismatchDetected {
    left=$(cat $1/cpuset.mems)
    right=$(cat $2/cpuset.mems)

    if [ "$left" == "$right" ]; then
      return 0
    else
      return 1
    fi
}

############################################################
# Check if kubernetes slice matches main master cpuset.mems
# Globals:
#   KUBE_DIR
#   CPUSET_DIR
# Arguments:
#   None
# Returns:
#   1 - kubepods.slice is affected
#   0 - kubepods.slice is not affected
############################################################
function isKubeAffected {
    if isMismatchDetected $KUBE_DIR $CPUSET_DIR; then
        return 1
    else
        return 0
    fi
}

############################################################
# Check if docker-ce slice matches main master cpuset.mems
# Globals:
#   DOCKER_DIR
#   CPUSET_DIR
# Arguments:
#   None
# Returns:
#   1 - docker slice is affected
#   0 - docker slice is not affected
############################################################
function isDockerAffected {
    if isMismatchDetected $DOCKER_DIR $CPUSET_DIR; then
        return 1
    else
        return 0
    fi
}

############################################################
# Check if system slice matches main master cpuset.mems
# Globals:
#   SYSTEM_DIR
#   CPUSET_DIR
# Arguments:
#   None
# Returns:
#   1 - system.slice is affected
#   0 - system.slice is not affected
############################################################
function isSystemAffected {
    if isMismatchDetected $SYSTEM_DIR $CPUSET_DIR; then
        return 1
    else
        return 0
    fi
}

############################################################
# Remove Slice directory passed as argument
# Globals:
#   SYSTEM_DIR
#   CPUSET_DIR
# Arguments:
#   Slice directory to remove
# Returns:
#   1 - system.slice is affected
#   0 - system.slice is not affected
############################################################
function removeSlice {
    if [ $use_move ] ; then
        mv $1 $1.bak
    else
        rmdir $1
    fi
}
############################################################
# Attempt to wipe the kubepods.slice sysfs directory
# Globals:
#   KUBE_DIR
# Arguments:
#   None
# Returns:
#   None
############################################################
function wipeKubeSlice {
    if [ $force ] ; then
        tr_resp="y"
    else
        echo -n "Do you wish to correct Kubernetes slice? (y/n): "
        read resp
        tr_resp=$(echo $resp | tr “[:upper:]” “[:lower:]”)
    fi
    if [ $tr_resp == "y" ] ; then
        if ! removeSlice $KUBE_DIR ; then
            echo "ERROR: Wiping Kubernetes Slice Failed.  Please make sure Kubernetes has been shutdown on this system"
        else
            echo "SUCCESS: Kubernetes slice has been removed.  Please start the Kubernetes service."
        fi
    fi
}

############################################################
# Attempt to wipe the docker slice sysfs directory
# This is used by docker-ce
# Globals:
#   DOCKER_DIR
# Arguments:
#   None
# Returns:
#   None
############################################################
function wipeDockerSlice {
    if [ $force ] ; then
        tr_resp="y"
    else
        echo -n "Do you wish to correct Docker slice? (y/n): "
        read resp
        tr_resp=$(echo $resp | tr “[:upper:]” “[:lower:]”)
    fi

    if [ $tr_resp == "y" ] ; then
        if ! removeSlice $DOCKER_DIR ; then
            echo "ERROR: Wiping Docker Slice Failed.  Please make sure the Docker daemon has been shutdown on this system"
        else
            echo "SUCCESS: Docker slice has been removed.  Please start the Docker service."
        fi
    fi
}

##############################################################
# Attempt to wipe the system.slice sysfs directory
# This is used by RHEL docker, and older versions of docker-ce
# Globals:
#   SYSTEM_DIR
# Arguments:
#   None
# Returns:
#   None
##############################################################
function wipeSystemSlice {
    if [ $force ] ; then
        tr_resp="y"
    else
        echo -n "Do you wish to correct System slice? (y/n): "
        read resp
        tr_resp=$(echo $resp | tr “[:upper:]” “[:lower:]”)
    fi

    if [ $tr_resp == "y" ] ; then
        if ! removeSlice $SYSTEM_DIR ; then
            echo "ERROR: Wiping System Slice Failed.  Please make sure the Docker daemon has been shutdown on this system"
        else
            echo "SUCCESS: System slice has been removed.  Please start the Docker service."
        fi
    fi
}

############################################################
# Check the three slice groups for any inconsistencies with the
# cpuset.mems
# Globals:
#   KUBERS_MSG
#   SYSTEM_MSG
#   DOCKER_MSG
#   right
#   left
# Arguments:
#   None
# Returns:
#   None
############################################################
function checkCpusetSlices {
    echo "CHECKING FOR INCORRECT CONTAINER GROUPS"
    echo "---------------------------------------"

    #If kubepods.slice directory exists, and it's cpuset.mems is incorrect.
    if isKubeSlice && isKubeAffected ; then
        kube_affected=1
        echo $KUBERS_MSG "TRUE";
        echo "EXPECTED: $right -- ACTUAL: $left"
    else
        echo $KUBERS_MSG "FALSE"
    fi

    #If system.slice directory exists, and it's cpuset.mems is incorrect.
    if isSystemSlice && isSystemAffected ; then
        system_affected=1
        echo $SYSTEM_MSG "TRUE";
        echo "EXPECTED: $right -- ACTUAL: $left"
    else
        echo $SYSTEM_MSG "FALSE"
    fi

    #If kudocker slice directory exists, and it's cpuset.mems is incorrect.
    if isDockerSlice && isDockerAffected ; then
        docker_affected=1
        echo $DOCKER_MSG "TRUE";
        echo "EXPECTED: $right -- ACTUAL: $left"

    else
        echo $DOCKER_MSG "FALSE"
    fi
}

############################################################
# Attempt to correct any cpuset.mems inconsistencies by
# deleting the slice and letting the service rebuild
#
# Globals:
#   docker_affected
#   system_affected
#   kube_affected
# Arguments:
#   None
# Returns:
#   None
############################################################

function wipeCpusetSlices {

    #Make sure we're elevated.  Otherwise nothing will work
    checkElevation

    #Call checkCpusetSlices to see if any areas are affected
    #No sense wiping if they're good.
    checkCpusetSlices


    #Prompt user to wipe docker directory if affected
    if [ $docker_affected ]; then
        wipeDockerSlice
    fi

    #Prompt user to wipe system.slice directory if affected
    if [ $system_affected ]; then
        wipeSystemSlice
    fi
    echo $kube_affected
    #Prompt user to wipe kubepods.slice directory if affected
    if [ $kube_affected ]; then
        wipeKubeSlice
    fi
}

while [ "$1" != "" ]; do
    case $1 in
        --correct )             correct=1
                                ;;
        --force )               force=1
                                ;;
        --use_move )            use_move=1
                                ;;
        --gpucheck )            gpucheck=1
                                ;;
        -h | --help )           usage
                                exit
                                ;;
        * )                     usage
                                exit 1
    esac
    shift
done

if [ $correct ] ; then
    wipeCpusetSlices
elif [ $gpucheck ] ; then
    isGpuMemReady
    exit $?
else
    checkCpusetSlices
fi
