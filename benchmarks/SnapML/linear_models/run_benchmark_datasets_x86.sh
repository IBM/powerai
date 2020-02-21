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
python benchmark_x86.py --data_dir=./datasets --dataset epsilon --test ridge >& epsilon_x86_ridge
sleep 2
python benchmark_x86.py --data_dir=./datasets --dataset epsilon --test lasso >& epsilon_x86_lasso
sleep 2
python benchmark_x86.py --data_dir=./datasets --dataset epsilon --test logistic >& epsilon_x86_logistic
sleep 2
python benchmark_x86.py --data_dir=./datasets --dataset higgs --test ridge >& higgs_x86_ridge
sleep 2
python benchmark_x86.py --data_dir=./datasets --dataset higgs --test lasso >& higgs_x86_lasso
sleep 2
python benchmark_x86.py --data_dir=./datasets --dataset higgs --test logistic >& higgs_x86_logistic
sleep 2
python benchmark_x86.py --data_dir=./datasets --dataset 500feats --test ridge >& 500feats_x86_ridge
sleep 2
python benchmark_x86.py --data_dir=./datasets --dataset 500feats --test lasso >& 500feats_x86_lasso
sleep 2
python benchmark_x86.py --data_dir=./datasets --dataset 500feats --test logistic >& 500feats_x86_logistic
sleep 2
python benchmark_x86.py --data_dir=./datasets --dataset taxi --test ridge --densify_sk >& taxi_x86_ridge
sleep 2
python benchmark_x86.py --data_dir=./datasets --dataset taxi --test lasso >& taxi_x86_lasso
sleep 2
python benchmark_x86.py --data_dir=./datasets --dataset taxi --test logistic >& taxi_x86_logistic
sleep 2
python benchmark_x86.py --data_dir=./datasets --dataset priceprediction --test ridge    --skip_cuml >& priceprediction_x86_ridge
sleep 2
python benchmark_x86.py --data_dir=./datasets --dataset priceprediction --test lasso    --skip_cuml >& priceprediction_x86_lasso
sleep 2
python benchmark_x86.py --data_dir=./datasets --dataset priceprediction --test logistic --skip_cuml  >& priceprediction_x86_logistic
sleep 2
