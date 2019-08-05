# XGBoost examples

This directory contains [XGBoost](https://github.com/dmlc/xgboost) examples.
It also contains other files to help use of XGBoost in Watson Machine Learning(WML) Accelerator.

## XGBoost notebook for training using GPU or CPU
The [xgboost-v82-covertype-demo.ipynb](xgboost-v82-covertype-demo.ipynb) file is
the notebook version of XGBoost example from - 
https://github.com/dmlc/xgboost/blob/release_0.82/demo/gpu_acceleration/cover_type.py
This notebook demonstrates the XGBoost parameters for training a model using GPU,
and also the parameters used for training the same model using CPU.

## YAML file to create a conda environment with XGBoost
The [WMLA-121-standalone-xgb-gpu-v82.yml](WMLA-121-standalone-xgb-gpu-v82.yml) YAML file
can be used to create a new conda environment with XGBoost installed in WML Accelerator.
This file contains the IBM Watson Machine Learning Community Edition(WML CE) conda channel
and necessary packages required to enable the use of XGBoost in a jupyter environment in WML Accelerator.
