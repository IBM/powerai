# IBM PowerAI Verification Tool

## Overview

IBM PowerAI Verification Tool is used to validate the PowerAI environment. Below are the validations done by the tool.
1) Is Power Platform               
2) OS Version     
3) Number of GPUs enabled               
4) Optional repos enabled               
5) Extras repo enabled                  
6) EPEL repo enabled                    
7) CUDA Operational                     
8) cuDNN Operational                    
9) Is Repository package installed      
10) Is power-mldl installed              
11) Is License accepted                  
12) Is Anaconda installed                 
13) Is Caffe Operational                 
14) Is Tensorflow Operational           
15) Is Pytorch Operational              
16) Is DDL Operational                  
17) Is SNAPML Operational               

Usage: sh powerai_verification_tool.sh [<args>]
    This tool is to validate the pre-requisites of PowerAI (e.g. CUDA, NVIDIA driver, cuDNN) and
    verifies that PowerAI license is accepted.
    And, it also validates the installed frameworks as per the args passed in the command line..

Agruments:
  help           Display this help and exit
  caffe          Verifies caffe installation.
  tensorflow     Verifies tensorflow installation.
  pytroch        Verifies pytorch installation.
  ddl            Verifies ddl installation.
  snapml         Verifies snapml installation.
  all            Verifies all frameworks installation.  


Note 1:  PowerAI verfication tool validates the versions installed in the enriroment with requirement.txt file.


