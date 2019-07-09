#! /usr/bin/env python
# Copyright 2019. IBM All Rights Reserved.
# Copyright 2019 The TensorFlow Authors. All Rights Reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# https://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

r""" batch REST client inference example: text classification of movie reviews

This example uses the REST interface to send a batch of inferface request
to a TensorFlow Serving model server. Test data is downloaded from the
imdb dataset and 100 records are sent to be inferenced.
The results are predictions of the text being a postive review. Anything greater
than or equal to .50 is considered a postive review. This is then compared
to the actual value in the test data to determine accuracy.

Usage: batch_rest_client_example.py [--server=localhost:8500] [--seed=0]

"""

from __future__ import absolute_import, division, print_function, unicode_literals

import tensorflow as tf
from tensorflow import keras

import argparse
import json
import numpy as np
import re
import requests

parser = argparse.ArgumentParser()
parser.add_argument('--server', default='localhost:8501',
                    help='PredictionService host:port')
parser.add_argument('--seed', type=int, default=0,
                    help='provide a non zero seed to use the same dataset between runs')

# input shape is the vocabulary count used for the movie reviews (10,000 words)
vocab_size = 10000

imdb = keras.datasets.imdb
word_index = imdb.get_word_index()

max_length=256
model_name="movie_reviews"

# The first indices are reserved
word_index = {k:(v+3) for k,v in word_index.items()}
word_index["<PAD>"] = 0
word_index["<START>"] = 1
word_index["<UNK>"] = 2  # unknown
word_index["<UNUSED>"] = 3

def main(args):
  random_seed=args.seed if args.seed !=0 else np.random.randint(1000)
  (train_data, train_labels), (test_data, test_labels) = imdb.load_data(num_words=vocab_size, seed=random_seed)
  test_data = keras.preprocessing.sequence.pad_sequences(test_data,
                                                         value=word_index["<PAD>"],
                                                         padding='post',
                                                         maxlen=256)

  #Batch inteference on 100 reviews
  test_data = test_data[:100]
  test_labels = test_labels[:100]

  SERVER_URL = "http://%s/v1/models/%s:predict" % (args.server, model_name)

  # Create the rest inference request
  request = '{"instances" :  %s }' % json.dumps(test_data.tolist())

  # Submit the request to the server
  response = requests.post(SERVER_URL, data=request)
  response.raise_for_status()

  # Display the results
  correct=0
  incorrect=0
  predictions = response.json()['predictions']
  for prediction, expected_value in zip(predictions, test_labels):
    if prediction[0] >= 0.50 and expected_value==1:
      correct+=1
    elif prediction[0] < 0.50 and expected_value==0:
      correct+=1
    else:
      incorrect+=1

  total = correct+incorrect
  print("%i out of %i correct" % (correct,total))

#  print("Confidence level the review is a positive one: %f" % prediction)
#  if prediction >= 0.50:
#    print("Review is considered postive!")
#  else:
#    print("Review is considered negative!")

if __name__ == '__main__':
  args = parser.parse_args()
  main(args)
