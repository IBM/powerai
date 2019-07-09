#! /usr/bin/env python
# coding: utf-8
#
# Copyright 2019. IBM All Rights Reserved.
# Copyright 2018 The TensorFlow Authors. All Rights Reserved.
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

# MIT License
#
# Copyright (c) 2017 François Chollet
#
# Permission is hereby granted, free of charge, to any person obtaining a
# copy of this software and associated documentation files (the "Software"),
# to deal in the Software without restriction, including without limitation
# the rights to use, copy, modify, merge, publish, distribute, sublicense,
# and/or sell copies of the Software, and to permit persons to whom the
# Software is furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL
# THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
# FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
# DEALINGS IN THE SOFTWARE.
#
r""" Text classification of movie reviews

This code is based on this jupyter notebook example:
https://github.com/tensorflow/docs/blob/master/site/en/r2/tutorials/keras/basic_text_classification.ipynb

This program classifies movie reviews as positive or negative using the text
of the review. This is an example of binary classification. This particular
example exports the saved model to the filesystem where it can be served for
inferencing by TensorFlow Serving

Usage: movie_reviews_training.py [--training_iteration=40] [--model_version=1] \
                                 [--model_path_base=/tmp/movie_reviews] 

"""



from __future__ import absolute_import, division, print_function, unicode_literals

import tensorflow as tf
from tensorflow import keras

import argparse
import numpy as np
import os

parser = argparse.ArgumentParser()
parser.add_argument('--training_iteration', type=int, default=40,
                    help='number of training iterations (epochs)')
parser.add_argument('--model_version', type=int, default=1,
                    help='version number of the model.')

parser.add_argument('--model_base_path', default='/tmp/movie_reviews',
                    help='Directory where to save the model')

# input shape is the vocabulary count used for the movie reviews (10,000 words)
vocab_size = 10000

def main(args):
  if args.training_iteration <= 0:
    print('Please specify a positive value for training_iteration.')
    exit(1)
  if args.model_version <= 0:
    print('Please specify a positive value for model_version.')
    exit(1)

  imdb = keras.datasets.imdb
  word_index = imdb.get_word_index()

  # The first indices are reserved
  word_index = {k:(v+3) for k,v in word_index.items()}
  word_index["<PAD>"] = 0
  word_index["<START>"] = 1
  word_index["<UNK>"] = 2  # unknown
  word_index["<UNUSED>"] = 3

  (train_data, train_labels), (test_data, test_labels) = imdb.load_data(num_words=vocab_size)
  train_data = keras.preprocessing.sequence.pad_sequences(train_data,
                                                          value=word_index["<PAD>"],
                                                          padding='post',
                                                          maxlen=256)

  test_data = keras.preprocessing.sequence.pad_sequences(test_data,
                                                         value=word_index["<PAD>"],
                                                         padding='post',
                                                         maxlen=256)


  model = keras.Sequential()
  model.add(keras.layers.Embedding(vocab_size, 16, name="input_layer"))
  model.add(keras.layers.GlobalAveragePooling1D())
  model.add(keras.layers.Dense(16, activation='relu'))
  model.add(keras.layers.Dense(1, activation='sigmoid', name="output_layer"))

  model.summary()

  model.compile(optimizer='adam',
                loss='binary_crossentropy',
                metrics=['accuracy'])

  x_val = train_data[:10000]
  partial_x_train = train_data[10000:]

  y_val = train_labels[:10000]
  partial_y_train = train_labels[10000:]

  model.fit(partial_x_train,
            partial_y_train,
            epochs=args.training_iteration,
            batch_size=512,
            validation_data=(x_val, y_val),
            verbose=1)

  save_directory = os.path.join(args.model_base_path,str(args.model_version))
  tf.saved_model.save(model, save_directory)
  
  results = model.evaluate(test_data, test_labels)
  print("\nFinal Results")
  for (label, value) in zip(model.metrics_names,results):
     print("%s = %f" % (label, value))

if __name__ == '__main__':
  args = parser.parse_args()
  main(args)
