#!/bin/bash

wget http://public.dhe.ibm.com/software/server/POWER/Linux/xl-compiler/eval/ppc64le/rhel7/repodata/repomd.xml.key
sudo rpm --import repomd.xml.key
wget http://public.dhe.ibm.com/software/server/POWER/Linux/xl-compiler/eval/ppc64le/rhel7/ibm-xl-compiler-eval.repo
sudo cp ibm-xl-compiler-eval.repo /etc/yum.repos.d/

sudo yum install xlc.16.1.1

#libibmc++ is at /opt/ibm/lib
export LD_LIBRARY_PATH=/opt/ibm/lib
