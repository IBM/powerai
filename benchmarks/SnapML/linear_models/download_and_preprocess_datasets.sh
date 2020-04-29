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

mkdir -p datasets
# Get epsilon dataset
echo "Downloading epsilon dataset... "
wget https://www.csie.ntu.edu.tw/~cjlin/libsvmtools/datasets/binary/epsilon_normalized.bz2
echo "Downloading epsilon dataset complete!!"
echo "Extract and preprocess epsilon dataset "
bunzip2 epsilon_normalized.bz2
mv  epsilon_normalized ./datasets
python preprocess-epsilon.py --data_path=./datasets

# Get higgs dataset
echo "Downloading higgs dataset... "
wget https://www.csie.ntu.edu.tw/~cjlin/libsvmtools/datasets/binary/HIGGS.bz2
echo "Downloading higgs dataset complete!!"
echo "Extract and preprocess higgs dataset "
bunzip2 HIGGS.bz2
mv HIGGS datasets/
python preprocess-higgs.py --data_path=./datasets


echo "Price prediction datatset must be downloaded from the following location using the Kaggle API"
echo "Download :https://www.kaggle.com/c/mercari-price-suggestion-challenge/data"
echo "download and extract train.tsv.7z and move it to the \"datasets\" directory "
# Price prediction cropped 
# Dataset source :https://www.kaggle.com/c/mercari-price-suggestion-challenge/data
FILE=./datasets/train.tsv
echo "Extract and preprocess price prediction cropped dataset "
if test -f $FILE; then
python preprocess-priceprediction.py --max_features=500
mv  X_train_norm_500feats_one_hot.npz 	./datasets
mv  X_test_norm_500feats_one_hot.npz 	./datasets
mv  y_train_500feats_one_hot.npy 	./datasets
mv  y_test_500feats_one_hot.npy 	./datasets

# Price prediction full
python preprocess-priceprediction.py
mv  X_train_norm.npz  	./datasets
mv  X_test_norm.npz	./datasets
mv  y_train.npy		./datasets
mv  y_test.npy		./datasets

else
   echo "$FILE does not exist"
fi

# Get taxi dataset
wget -nc https://s3.amazonaws.com/nyc-tlc/trip+data/yellow_tripdata_2019-06.csv
echo "Preprocess taxi dataset "
python preprocess-taxi.py
mv taxi.* yellow_tripdata_2019-06.csv ./datasets
mv yellow_tripdata_2019-06.csv ./datasets
