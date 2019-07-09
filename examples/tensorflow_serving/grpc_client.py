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

r""" gRPC client inference example: text classification of movie reviews

This program accepts a text based movie review, converts it into an integer
base tensor and sends a prediction request to a TensorFlow Serving model server.
The result is a prediction of the text being a postive review. Anything greater
than or equal to .50 is considered a postive review.

This example uses the gRPC interface to communicate with the TensorFlow Serving
model server.

Usage: grpc_client.py [--server=localhost:8500] --review='text of the review' 

"""


from __future__ import absolute_import, division, print_function, unicode_literals

import tensorflow as tf
from tensorflow import keras

from tensorflow_serving.apis import predict_pb2
from tensorflow_serving.apis import prediction_service_pb2_grpc

import argparse
import grpc
import re

parser = argparse.ArgumentParser()
parser.add_argument('--server', default='localhost:8500',
                    help='PredictionService host:port')
parser.add_argument('--review', required=True, help='Text of the moview review')

word_index = keras.datasets.imdb.get_word_index()

vocab_size=10000
max_length=256
model_name="movie_reviews"

# The first indices are reserved
word_index = {k:(v+3) for k,v in word_index.items()}
word_index["<PAD>"] = 0
word_index["<START>"] = 1
word_index["<UNK>"] = 2  # unknown
word_index["<UNUSED>"] = 3

def main(args):
  review=args.review

  # Lowercase the review, remove anything that isn't a letter, and split it into a list of words
  review=review.lower()
  review=re.sub(r"[^a-z]", " ", review)
  review=review.split()

  # Convert the review into a list of integers corresponding to the words. Use 2 for unknown words.
  # As the model was only trained with words up to vocab_size, we need to remove any words
  # greater than vocab_size or get an error.
  coded_review = []
  for i in review:
    int_value = word_index.get(i, word_index["<UNK>"])
    if int_value>=vocab_size:
      int_value=word_index["<UNK>"]
    coded_review.append(int_value)


  # Uncoment these lines below to decode the message and verify it matches the original text
  # print(coded_review)
  # reverse_word_index = dict([(value, key) for (key, value) in word_index.items()])
  # decoded_review = ' '.join([reverse_word_index.get(i, '?') for i in coded_review])
  # print(decoded_review)

  # Pad the length of the review to match the length of the tensors the model was trained with
  coded_review = keras.preprocessing.sequence.pad_sequences([coded_review], value=word_index["<PAD>"], padding='post', maxlen=max_length)

  # Create the grpc inference request
  channel = grpc.insecure_channel(args.server)
  stub = prediction_service_pb2_grpc.PredictionServiceStub(channel)
  request = predict_pb2.PredictRequest()
  request.model_spec.name = model_name
  request.model_spec.signature_name = 'serving_default'

  # Convert the coded_review into a tensor
  request.inputs['input_layer_input'].CopyFrom(tf.compat.v1.make_tensor_proto(coded_review,dtype=tf.float32))

  # Submit the request to the server
  result = stub.Predict(request, 10.0) # 10 secs timeout

  # Display the results
  prediction = result.outputs['output_layer'].float_val[0]
  print("Confidence level the review is a positive one: %f" % prediction)
  if prediction >= 0.50:
    print("Review is considered postive!")
  else:
    print("Review is considered negative!")

if __name__ == '__main__':
  args = parser.parse_args()
  main(args)
