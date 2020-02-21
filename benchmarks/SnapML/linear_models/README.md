# Instructions for benchmarking - P9 and x86

## Step 1:

### On P9 :

#### Install WMLCE-1.6.2
https://www.ibm.com/support/knowledgecenter/SS5SF7_1.6.2/navigation/wmlce_install.htm 

#### Install pai4sk,cuml and scikit-learn
```
conda install pai4sk=1.5.0
conda install scikit-learn=0.21.3
conda install cuml=0.9.1
conda install dask-ml=1.1.1
```

### On x86:
#### Install scikit-learn and cuML
```
conda install -c rapidsai -c nvidia -c conda-forge \
    -c defaults cuml=0.10 python=3.6 cudatoolkit=10.1
conda install scikit-learn
```
## Step 2: 
#### Download and install datasets 

`bash download_and_preprocess_datasets.sh`

## Step 3: Run the benchmarks

### On P9: 
```
bash run_benchmark_datasets_p9.sh
```

### On x86:
```
bash run_benchmark_datasets_x86.sh
```
