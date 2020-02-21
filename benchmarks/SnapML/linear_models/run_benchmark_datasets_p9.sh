# ```
#(C) Copyright IBM Corp.  2019,2020. All Rights Reserved.
# ```
# 
# ```
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# 
#      http://www.apache.org/licenses/LICENSE-2.0
# 
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
# ```
python benchmark_p9.py --data_dir=./datasets --dataset epsilon --test ridge --num_gpu_threads 1024  >& epsilon_p9_ridge
sleep 2
python benchmark_p9.py --data_dir=./datasets --dataset epsilon --test lasso --num_gpu_threads 1024  >& epsilon_p9_lasso
sleep 2
python benchmark_p9.py --data_dir=./datasets --dataset epsilon --test logistic --num_gpu_threads 1024  >& epsilon_p9_logistic
sleep 2
python benchmark_p9.py --data_dir=./datasets --dataset higgs --test ridge --num_gpu_threads 1024  >& higgs_p9_ridge
sleep 2
python benchmark_p9.py --data_dir=./datasets --dataset higgs --test lasso --num_gpu_threads 1024  >& higgs_p9_lasso
sleep 2
python benchmark_p9.py --data_dir=./datasets --dataset higgs --test logistic --num_gpu_threads 512  >& higgs_p9_logistic
sleep 2
python benchmark_p9.py --data_dir=./datasets --dataset 500feats --test ridge --num_gpu_threads 256  >& 500feats_p9_ridge
sleep 2
python benchmark_p9.py --data_dir=./datasets --dataset 500feats --test lasso --num_gpu_threads 256  >& 500feats_p9_lasso
sleep 2
python benchmark_p9.py --data_dir=./datasets --dataset 500feats --test logistic --num_gpu_threads 256  >& 500feats_p9_logistic
sleep 2
python benchmark_p9.py --data_dir=./datasets --dataset taxi --test ridge --num_gpu_threads 256 --densify_sk >& taxi_p9_ridge
sleep 2
python benchmark_p9.py --data_dir=./datasets --dataset taxi --test lasso --num_gpu_threads 1024  >& taxi_p9_lasso
sleep 2
python benchmark_p9.py --data_dir=./datasets --dataset taxi --test logistic --num_gpu_threads 256  >& taxi_p9_logistic
sleep 2
python benchmark_p9.py --data_dir=./datasets --dataset priceprediction --test ridge --num_gpu_threads 256 --skip_cuml >& priceprediction_p9_ridge
sleep 2
python benchmark_p9.py --data_dir=./datasets --dataset priceprediction --test lasso --num_gpu_threads 512 --skip_cuml >& priceprediction_p9_lasso
sleep 2
python benchmark_p9.py --data_dir=./datasets --dataset priceprediction --test logistic --num_gpu_threads 256 --skip_cuml  >& priceprediction_p9_logistic
sleep 2
