# ```
#(C) Copyright IBM Corp.  2018,2020. All Rights Reserved.
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

# Dataset preprocessing and training code based on the solution posted here:
# https://www.kaggle.com/tsaustin/mercari-price-recommendation

import pandas as pd
import warnings
warnings.filterwarnings('ignore')
import os
import argparse
import numpy as np
import scipy

CLI=argparse.ArgumentParser()
CLI.add_argument("--max_features", type=int, default=0)
args = CLI.parse_args()

# Define output paths for the train and test datasets
x_train_filename = "X_train_norm.npz"
x_test_filename = "X_test_norm.npz"
y_train_filename = "y_train.npy"
y_test_filename = "y_test.npy"

if args.max_features > 0:
    x_train_filename = "X_train_norm_" + str(args.max_features) + "feats_one_hot.npz"
    x_test_filename = "X_test_norm_" + str(args.max_features) + "feats_one_hot.npz"
    y_train_filename = "y_train_" + str(args.max_features) + "feats_one_hot.npy"
    y_test_filename = "y_test_" + str(args.max_features) + "feats_one_hot.npy"

# Read the training dataset
df = pd.read_csv('./datasets/train.tsv',sep="\t")
print(df.head())

# Remove the train_id feature column
df.set_index('train_id',inplace=True)
print(df.head())

# Compute the percentages of missing values
df_na = (df.isnull().sum() / len(df)) * 100
df_na = df_na.drop(df_na[df_na == 0].index).sort_values(ascending=False)[:30]
missing_data = pd.DataFrame({'Missing Ratio' :df_na})
missing_data.head(20)

# Compute the number of products with price 0
len(df[df['price'] == 0])

print(df['price'].unique())

# Remove the products with price 0
df = df[df['price']>0]


# Replace the missing values with a given word 'missing'
df['brand_name'] = df['brand_name'].fillna('missing')
df['category_name'] = df['category_name'].fillna('missing')
df['item_description'] = df['item_description'].fillna('missing')
print(df.head())

# Change the data type for category_name, brand_name and item_condition_id
df['category_name'] = df['category_name'].astype('category')
df['item_condition_id'] = df['item_condition_id'].astype('category')
print(df.dtypes)

# Words cleaning function for the columns with long text
def clean_text(col):
    # remove non alpha characters
    col = col.str.replace("[\W]", " ") #a-zA-Z1234567890
    # all lowercase
    col = col.apply(lambda x: x.lower())
    return col

# Clean the text in the name, category name and item description features
df['name']=clean_text(df['name'])
df['category_name']=clean_text(df['category_name'])
df['item_description']=clean_text(df['item_description'])
print(df.head())


# create feature matrix for name, category_name and item description features
from sklearn.feature_extraction.text import CountVectorizer

# The text will be replaced with a vector of word counts for each of the columns

if args.max_features==0:
    cv = CountVectorizer(min_df=0.0001, max_df=0.1, stop_words='english')
    X_name = cv.fit_transform(df['name'])
    print(X_name.shape)

    cv = CountVectorizer()
    X_category = cv.fit_transform(df['category_name'])
    print(X_category.shape)

    cv = CountVectorizer(min_df=0.0001, max_df=0.1, stop_words='english')
    X_item_description = cv.fit_transform(df['item_description'])
    print(X_item_description.shape)

else:
    cv = CountVectorizer(min_df=0.0001, max_df=0.1, max_features=args.max_features, stop_words='english')
    X_name = cv.fit_transform(df['name'])
    print(X_name.shape)

    cv = CountVectorizer(max_features=args.max_features)
    X_category = cv.fit_transform(df['category_name'])
    print(X_category.shape)

    cv = CountVectorizer(min_df=0.0001, max_df=0.1, max_features=args.max_features, stop_words='english')
    X_item_description = cv.fit_transform(df['item_description'])
    print(X_item_description.shape)


# the brand name is label binarizer 
# generate the feature matrix for the brand name feature
from sklearn.preprocessing import LabelBinarizer
if args.max_features==0:
    lb = LabelBinarizer(sparse_output=True)
    X_brand = lb.fit_transform(df['brand_name'])
else:
    lb = LabelBinarizer(sparse_output=True)
    X_brand = lb.fit_transform(df['brand_name'])

y = df['price']
df = df.drop('price',axis=1)
print(df.head())

# one-hot encoding for the item condition id (5 integer values) and shipping (2 integer values)
from scipy.sparse import csr_matrix
df['shipping'] = df['shipping'].astype('category')
X_condition_shipping = csr_matrix(pd.get_dummies(df[['item_condition_id','shipping']], sparse=True).values)

# create the complete feature matrix by stacking the individual column transformations
from scipy.sparse import hstack

if args.max_features == 0:
    X_all = hstack((X_brand, X_category, X_name, X_item_description, X_condition_shipping)).tocsr()
else:
    X_all = hstack((X_brand, X_category, X_name, X_item_description, X_condition_shipping)).tocsr()
print(X_all.shape)

# reduce the feature columns by removing all features with a document frequency smaller than 1
import numpy as np
mask = np.array(np.clip(X_all.getnnz(axis=0) - 1, 0, 1), dtype=bool)
X_all = X_all[:, mask]
print(X_all.shape)

# target variable: the log of the price
y_log = np.log1p(y)

# perform standard scaling
print("Before Split\n")
print("X_all=",X_all.shape)
print("y_log=",y_log.shape)

# split into test and train samples
from sklearn.model_selection import train_test_split
X_train, X_test, y_train, y_test = train_test_split(X_all, y_log, random_state=42, test_size=0.2)

print("After Split\n")
print("X_train=",X_train.shape)
print("X_test=",X_test.shape)
print("y_train=",y_train.shape)
print("y_test=",y_test.shape)

from sklearn.preprocessing import normalize
X_train = normalize(X_train, axis=1, norm='l1')
X_test = normalize(X_test, axis=1, norm='l1')

print("Saving X_train to ", x_train_filename)
print("Saving X_test to ", x_test_filename)
print("Saving y_train to ", y_train_filename)
print("Saving y_test to ", y_test_filename)

scipy.sparse.save_npz(x_train_filename, X_train, compressed=False)
scipy.sparse.save_npz(x_test_filename, X_test, compressed=False)
np.save(y_train_filename, y_train)
np.save(y_test_filename, y_test)


