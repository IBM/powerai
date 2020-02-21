#!/usr/bin/env python
# coding: utf-8

# ```
# Copyright 2019. IBM All Rights Reserved.
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

# # NYC Taxi Tip prediction (Ridge Regression) using SnapML
# <div class="alert alert-block alert-info">
#     <b>Snap ML</b> is packaged with <b>IBM® Watson™ Machine Learning Community Edition (WML CE)</b> in a conda package <b>pai4sk</b>.
# </div>

# ### Taxi Tip prediction
# In this example we will train a Ridge Regression model to predict the amount of tip paid for a taxi trip using both <b>SnapML</b> and <b>RAPIDS cuML</b>.
# 
# ### Data source
# Dataset used for this notebook is downloaded from https://www1.nyc.gov/site/tlc/about/tlc-trip-record-data.page with all rights reserved by Taxi & Limousine Commission(TLC), City of New York.
# 
# TLC Yellow Taxi Trip Records of June, 2019 is used in this notebook.
# 
# ### Conda packages used for this notebook 
# - `pai4sk  1.5.0 (Package for IBM Snap ML, provided in WML CE 1.6.2)`
# - `cuml    0.9.1 (Package for RAPIDS cuML, provided in WML CE 1.6.2)`
# - `dask    2.6.0 (Used here for distributed loading and feature engineering)`
# - `dask-ml 1.0.0 (Used here for distributed pre-processing)`
# - `seaborn 0.9.0 (Used for Visualization)`
# 
# ### System Configuration 
# 
# |Configuration Parameter |	Value                         |
# |:-----------------------|:-------------------------------|       
# | **Machine** 	         | IBM Power9 AC922               |
# | **CPU cores:**         | 40 (20 cores per socket)       |
# | **Thread(s) per core:**| 4                              |
# | **GPU** 	             | NVIDIA Tesla V100 SXM2 32GB    |
# 

# In[1]:


import dask.dataframe as dpd
import glob
import numpy as np
import time

import warnings
warnings.filterwarnings('ignore')


# ### A. Load one month yellow taxi data ( Using dask dataframe for multi-core parallel processing )

# In[2]:


#Download June 2019 TLC Yellow Taxi Trip records used in this notebook
#get_ipython().system('wget -nc https://s3.amazonaws.com/nyc-tlc/trip+data/yellow_tripdata_2019-06.csv')


# In[3]:


ddf = dpd.read_csv('./yellow_tripdata_2019-06.csv',
                    parse_dates=['tpep_pickup_datetime', 'tpep_dropoff_datetime'])


# In[4]:
ddf.head()


# The yellow taxi trip records include fields capturing pick-up and drop-off dates/times, pick-up and drop-off locations, trip distances, itemized fares, rate types, payment types, and driver-reported passenger counts.
# #### Persist dask dataframe into memory (to avoid reloading from disk)
# In[5]:
ddf = ddf.persist()

# In[6]:
print('The dataset has',ddf.shape[0].compute(),'rows and',ddf.shape[1],'columns.')


# ### B. Cleaning the dataset

# #### 1. Drop trips with zero (or negative) tip_amount
# As per the data dictionary of this dataset, tip_amount column does not include cash tips. So, we'll assume all the rows with 0 in tip_amount were tips paid in cash and drop all such rows!

# In[7]:
filter_out_cash_tips = (ddf['tip_amount'] > 0)


# In[8]:
filter_out_cash_tips.compute().value_counts()


# In[9]:
#Retain only rows with tip amount greater than zero
ddf = ddf[filter_out_cash_tips]


# #### 2. Keep only trips with tip amount <= the fare amount
# In[10]:
filter_out_big_tips = (ddf['tip_amount'] <= ddf['fare_amount'])

# In[11]:
filter_out_big_tips.compute().value_counts()

# In[12]:
ddf = ddf[filter_out_big_tips]

# #### 3. Remove trips with extreme fare amounts
# Keep trips with fare >= the minimum amount 2 dollars and keep trips with fare amount less than 200 dollars
# In[13]:
filter_out_extreme_fare = ((ddf['fare_amount'] >= 2) & (ddf['fare_amount'] < 200))

# In[14]:
filter_out_extreme_fare.compute().value_counts()

# In[15]:
ddf = ddf[filter_out_extreme_fare]

# ### C. Visualise the tip_amount distribution
# In[17]:

# #### Print the dataset shape before preprocessing

# In[18]:
print('The dataset has',ddf.shape[0].compute(),'rows and',ddf.shape[1],'columns.')


# ### D. Data Preprocessing

# #### Create derived features

# In[19]:


#calculate trip time in minutes
trip_time = ddf['tpep_dropoff_datetime'] - ddf['tpep_pickup_datetime']
ddf['trip_time'] = trip_time.astype('timedelta64[m]')

# In[20]:
#extract pickup and dropoff hour
ddf['pickup_hour'] = ddf['tpep_pickup_datetime'].dt.hour
ddf['dropoff_hour'] = ddf['tpep_dropoff_datetime'].dt.hour

# In[21]:
#extract pickup and dropoff day of week
ddf['pickup_day'] = ddf['tpep_pickup_datetime'].dt.weekday_name
ddf['dropoff_day'] = ddf['tpep_dropoff_datetime'].dt.weekday_name

# In[22]:
#Now that we have extracted required derived features from the pickup and dropoff datetime, drop them 
ddf = ddf.drop(['tpep_pickup_datetime', 'tpep_dropoff_datetime'], axis=1)

# #### One Hot encoding
# In[23]:
get_dummy_col = ["VendorID","RatecodeID","store_and_fwd_flag","PULocationID", "DOLocationID","payment_type", "pickup_hour", "dropoff_hour", "pickup_day", "dropoff_day"]
ddf = ddf.categorize(columns=get_dummy_col)

# In[24]:
ddf = dpd.get_dummies(ddf, columns = get_dummy_col)

print("After one-hot encoding")
print(ddf.__class__)
print(ddf.shape[0].compute())

# #### Use tip_amount as the target label for training
# In[25]:
label = ddf[['tip_amount']].compute()
ddf = ddf.drop(['tip_amount'], axis=1)
ddf = ddf.drop(['total_amount'], axis=1)

# #### Transform features and then normalize values
# In[26]:
from dask_ml.preprocessing import MinMaxScaler
min_max_scaler = MinMaxScaler()
X = min_max_scaler.fit_transform(ddf)

# In[27]:
# Convert Dask dataframe to Numpy array 
X = X.to_dask_array().compute()

# In[28]:
from pai4sk.preprocessing import normalize
X = normalize(X, axis=1, norm='l1')

# #### Convert data to float32 data-type
# In[29]:
X = X.astype('float32')
y = label.values.astype('float32')


# In[30]:
print('X is of type :', X.__class__.__name__, 'and y is of type :', y.__class__.__name__)

# #### Split data into train and test sets
# It would have been preferable to use 80% of the data for training, but cuML fails with "out of memory" error if trained with that size of data. Switched to using 60% of data for training to not hit cuML OOM error.
# <b>Snap ML is capable of training with any amount of large data, even when using a single GPU!</b>

# In[31]:
from pai4sk.model_selection import train_test_split
X_train, X_test, y_train, y_test = train_test_split(X, y, test_size=0.4, random_state=17)

# In[32]:
print('The train data has',X_train.shape[0],'rows and',X_train.shape[1],'columns.')
print('The test data has',X_test.shape[0],'rows and',X_test.shape[1],'columns.')

# Save in dense format for cuml
np.save("./taxi.X_train.npy", X_train)
np.save("./taxi.X_test.npy", X_test)

from scipy import sparse
X_train = sparse.csr_matrix(X_train)
X_test = sparse.csr_matrix(X_test)   

from scipy.sparse import save_npz
# Save in sparse format for snapml
save_npz("./taxi.X_train.npz", X_train)
save_npz("./taxi.X_test.npz",  X_test)

np.save("./taxi.y_train", y_train)
np.save("./taxi.y_test",  y_test)

