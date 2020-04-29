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

## 
# Authors: Thomas Parnell,Naveen M, Andreea Anghel, Kokil Deuri
# Script to benchmark SnapML,cuML,scikit-learn for linear models on a single-GPU on the Power platform
## 
import numpy as np
from scipy import sparse
from pai4sk.metrics import mean_squared_error, accuracy_score
import time
from pai4sk.linear_model import RidgeSklearn as Ridge
from pai4sk.linear_model import LassoSklearn as	Lasso
from pai4sk.linear_model import LogisticRegressionSklearn as Logistic
from pai4sk import LinearRegression, LogisticRegression
from cuml import Ridge as cuRidge
from cuml import Lasso as cuLasso
from cuml import LogisticRegression as cuLogistic
import os, sys
import cuml
import pai4sk
import warnings
import argparse
from datetime import datetime


# datetime object containing current date and time
now = datetime.now()
# dd/mm/YY H:M:S
dt_string = now.strftime("%d/%m/%Y %H:%M:%S")

CLI=argparse.ArgumentParser()
CLI.add_argument("--data_dir", type=str, default='datasets')
CLI.add_argument("--dataset", type=str, default='500feats')
CLI.add_argument("--test", type=str, default='ridge')
CLI.add_argument("--small_test", dest='small_test', action='store_true')
CLI.add_argument("--densify_all", dest='densify_all', action='store_true')
CLI.add_argument("--densify_sk", dest='densify_sk', action='store_true')
CLI.add_argument("--num_gpu_threads", type=int, default=256)
CLI.add_argument("--num_cpu_threads", type=int, default=8)
CLI.add_argument("--skip_cuml", dest='skip_cuml', action='store_true')
CLI.add_argument("--print_csv", dest='print_csv', action='store_true')

args = CLI.parse_args()

if args.dataset == '500feats':
    dataset_type = 'regression'
    X_train_ = sparse.load_npz(args.data_dir + "/X_train_norm_500feats_one_hot.npz")
    X_test  = sparse.load_npz(args.data_dir + "/X_test_norm_500feats_one_hot.npz")
    y_train_ = np.load(args.data_dir + "/y_train_500feats_one_hot.npy")
    y_test  = np.load(args.data_dir + "/y_test_500feats_one_hot.npy")

elif args.dataset == 'priceprediction':
    dataset_type = 'regression'
    X_train_ = sparse.load_npz(args.data_dir + "/X_train_norm.npz")
    X_test  = sparse.load_npz(args.data_dir + "/X_test_norm.npz")
    y_train_ = np.load(args.data_dir + "/y_train.npy")
    y_test  = np.load(args.data_dir + "/y_test.npy")
	
elif args.dataset == 'epsilon':
    dataset_type = 'classification'
    X_train_ = np.load(args.data_dir + "/epsilon.X_train.npy")
    X_test   = np.load(args.data_dir + "/epsilon.X_test.npy")
    y_train_ = (np.load(args.data_dir + "/epsilon.y_train.npy")+1)/2
    y_test   = (np.load(args.data_dir + "/epsilon.y_test.npy")+1)/2

elif args.dataset == 'higgs':
    dataset_type = 'classification'
    X_train_ = np.load(args.data_dir + "/HIGGS.X_train.npy")
    X_test   = np.load(args.data_dir + "/HIGGS.X_test.npy")
    y_train_ = np.load(args.data_dir + "/HIGGS.y_train.npy")
    y_test   = np.load(args.data_dir + "/HIGGS.y_test.npy")

elif args.dataset == 'taxi':
    dataset_type = 'regression'
    X_train_ = sparse.load_npz(args.data_dir + "/taxi.X_train.npz")
    X_test   = sparse.load_npz(args.data_dir + "/taxi.X_test.npz")
    y_train_ = np.load(args.data_dir + "/taxi.y_train.npy")
    y_test   = np.load(args.data_dir + "/taxi.y_test.npy")

else:
    raise ("Invalid dataset")


# convert continuous labels to binary for logistic
if(args.test == 'logistic' and dataset_type == 'regression'):
    y_part = np.median(y_train_)
    for i in range(y_train_.shape[0]):
        y_train_[i] = 1.0 if y_train_[i] > y_part else 0.0
    for i in range(y_test.shape[0]):
        y_test[i] = 1.0 if y_test[i] > y_part else 0.0

# Calculate sparsity/density
density=0.0
sparsity=0.0
if args.dataset == 'epsilon' or args.dataset == 'higgs':
        non_zeroes   = np.count_nonzero(X_train_)
        total_zeroes = (X_train_.shape[0] * X_train_.shape[1])
        density  = non_zeroes /total_zeroes
        sparsity  = 1- density
else:
        non_zeroes   = X_train_.count_nonzero()
        total_zeroes = (X_train_.shape[0] * X_train_.shape[1])
        density  = non_zeroes /total_zeroes
        sparsity  = 1- density


# print experiment details
print("date and time:   %s" % ( dt_string))
print("Loaded dataset:  %s" % (args.dataset))
print("Running test:    %s" % (args.test))
print("cuML version:    %s" % (cuml.__version__))
print("pai4sk version:  %s" % (pai4sk.__version__))
print("small_test:      %s" % ("True" if args.small_test else "False"))
print("densify_all:     %s" % ("True" if args.densify_all else "False"))
print("densify_sk:      %s" % ("True" if args.densify_sk else "False"))
print("num_cpu_threads: %d" % (args.num_cpu_threads))
print("num_gpu_threads: %d" % (args.num_gpu_threads))
print("num_examples:    %d" % (X_train_.shape[0]))
print("num_features:    %d" % (X_train_.shape[1]))
print("data_type:       %s" % (type(X_train_)))
print("density:       %.3f" % (density))
print("sparsity:      %.3f" % (sparsity))


if args.small_test:
    X_test = X_test[:1000,:]
    y_test = y_test[:1000]

if type(X_test) is not np.ndarray:
    X_test_np = X_test.toarray()
else:
    X_test_np = X_test

# convert test set into column-major
X_test_cu = np.asfortranarray(X_test_np)

if args.test == 'lasso':
    regularizer = 100.0
elif args.test == 'ridge':
    regularizer = 1.0
elif args.test == 'logistic':
    regularizer = 1.0
else:
    raise("Invalid test")

def scorer(y_test, z_test):
    if args.test == 'logistic':
        return accuracy_score(y_test, z_test)
    else:
        return mean_squared_error(y_test, z_test)

stop = False

if args.print_csv:
	print("n_rows,t-sk,t-cu,t-snap-cpu,t-snap-gpu,score-sk,score-cu,score-snap-cpu,score-snap-gpu")

for n_use in [100, 1000, 10000, 100000, 200000, 400000, 800000, 1600000, 3200000, 6400000, 12800000]:

    if stop:
        continue

    # cuML fails with larger number of examples 
    if args.dataset == '500feats': 
    	if n_use >= 175000: 
        	n_use = 175000 
        	stop = True

    if n_use > X_train_.shape[0]:
        n_use = X_train_.shape[0]
        stop = True

    # supppres stdout
    newstdout = os.dup(sys.stdout.fileno())
    nulf = os.open(os.devnull, os.O_WRONLY)
    os.dup2(nulf, sys.stdout.fileno())
    os.close(nulf)

    X_train = X_train_[:n_use,:]
    y_train = y_train_[:n_use]

    if args.densify_all:
         X_train = X_train.toarray()

    if type(X_train) is not np.ndarray:
        X_train_np = X_train.toarray()
    else:
        X_train_np = X_train

    if args.densify_all:
         X_train = X_train_np

    if args.test == 'ridge':
        sk = Ridge(fit_intercept=False, alpha=regularizer)
        cu = cuRidge(fit_intercept=False, alpha=regularizer, solver='eig')
        lr_cpu = LinearRegression(fit_intercept=False, use_gpu=False, num_threads=args.num_cpu_threads, dual=True, penalty='l2', regularizer=regularizer)
        lr_gpu = LinearRegression(fit_intercept=False, use_gpu=True, device_ids=[0], dual=True, penalty='l2', regularizer=regularizer, num_threads=args.num_gpu_threads)
    elif args.test == 'lasso':
        sk = Lasso(fit_intercept=False, alpha=regularizer/X_train.shape[0])
        cu = cuLasso(fit_intercept=False, alpha=regularizer/X_train.shape[0])
        lr_cpu = LinearRegression(fit_intercept=False, use_gpu=False, num_threads=args.num_cpu_threads, dual=False, penalty='l1', regularizer=regularizer)
        lr_gpu = LinearRegression(fit_intercept=False, use_gpu=True, device_ids=[0], dual=False, penalty='l1', regularizer=regularizer, num_threads=args.num_gpu_threads)
    elif args.test == 'logistic':
        sk = Logistic(fit_intercept=False, C=regularizer, dual=True, solver='liblinear')
        cu = cuLogistic(fit_intercept=False, C=regularizer*X_train.shape[0], max_iter=100000, tol=1e-8)
        lr_cpu = LogisticRegression(fit_intercept=False, use_gpu=False, num_threads=args.num_cpu_threads, dual=True, penalty='l2', regularizer=regularizer)
        lr_gpu = LogisticRegression(fit_intercept=False, use_gpu=True, device_ids=[0], dual=True, penalty='l2', regularizer=regularizer, num_threads=args.num_gpu_threads)
    else:
        raise("Invalid test")

    if args.densify_sk:
        X_train_sk = X_train_np
    else:
        X_train_sk = X_train

    # sklearn
    t0 = time.time()
    with warnings.catch_warnings():
        warnings.filterwarnings("ignore")
        sk.fit(X_train_sk, y_train)
    t_sk = time.time()-t0
    sk_pred = sk.predict(X_test)
    score_sk = scorer(y_test, sk_pred)

    # cuML
    if not(args.skip_cuml):
    	X_train_cu = np.asfortranarray(X_train_np)
    	y_train_cu = np.asfortranarray(y_train)

    	t0 = time.time()
    	with warnings.catch_warnings():
        	warnings.filterwarnings("ignore")
        	cu.fit(X_train_cu, y_train_cu)
    	t_cu = time.time()-t0
    	cu_pred = cu.predict(X_test_cu)
    	score_cu = scorer(y_test, cu_pred.to_pandas().values)
    else:
    	score_cu = 0.0 
    	t_cu = 0.0 
    
    # snap-cpu
    t0 = time.time()
    res_cpu = lr_cpu.fit(X_train, y_train)
    t_cpu = time.time()-t0
    lr_cpu_pred = lr_cpu.predict(X_test)
    score_cpu = scorer(y_test, lr_cpu_pred)

    # snap-gpu
    # For the lasso test and the input is in ndarray format ,then pass the data in column major format 
    if args.test == 'lasso' and (args.dataset == 'epsilon' or args.dataset== 'higgs'):
    	X_train_col_major = np.asfortranarray(X_train) 
    	y_train_col_major = np.asfortranarray(y_train) 
    	t0 = time.time()
    	res_gpu = lr_gpu.fit(X_train_col_major, y_train_col_major)
    	t_gpu = time.time()-t0
    else: 
    	t0 = time.time()
    	res_gpu = lr_gpu.fit(X_train, y_train)
    	t_gpu = time.time()-t0

    lr_gpu_pred = lr_gpu.predict(X_test)
    score_gpu = scorer(y_test, lr_gpu_pred)

    # revert stdout
    os.dup2(newstdout, sys.stdout.fileno())
    
    if args.print_csv:
    	print("%7d, %8.4f, %8.4f, %8.4f, %8.4f, %6.3f, %6.3f, %6.3f, %6.3f" % (n_use, t_sk, t_cu, t_cpu, t_gpu, score_sk, score_cu, score_cpu, score_gpu))
    else: 
    	print("n_rows: %7d t-sk: %8.4f t-cu: %8.4f t-snap-cpu: %8.4f t-snap-gpu: %8.4f  score-sk: %6.3f score-cu: %6.3f score-snap-cpu: %6.3f score-snap-gpu: %6.3f" % (n_use, t_sk, t_cu, t_cpu, t_gpu, score_sk, score_cu, score_cpu, score_gpu))


