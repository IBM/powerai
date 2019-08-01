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

""" Inference client example running TensorRT-optimized model

Usage: python resnet_v1_50_inference_client.py

"""
import grpc
import requests
import numpy
import urllib.request

import tensorflow as tf
from tensorflow.python import keras
from tensorflow.python.keras.preprocessing.image import load_img
from tensorflow.python.keras.preprocessing.image import img_to_array
from tensorflow.python.keras.applications.vgg16 import preprocess_input
from tensorflow.python.keras.applications.vgg16 import decode_predictions
from tensorflow.compat.v1 import make_tensor_proto
from tensorflow_serving.apis import predict_pb2
from tensorflow_serving.apis import prediction_service_pb2_grpc

_IMAGE_URL = 'https://static1.squarespace.com/static/5b19f01b4eddec0b62c9fac1/t/5c0ad6c1575d1fa80730173e/1544214218159/animal-collar-dog-8081.jpg'

image_url = _IMAGE_URL
filename = image_url.split('/')[-1]
urllib.request.urlretrieve(image_url, filename)

# Load the image and resize to (224, 224)
image = load_img(filename, target_size=(224, 224))

# Add channels (224, 224, 3)
image = img_to_array(image)

# Scale pixels for Tensorflow
image = preprocess_input(image)

# Batch size will be 1
image = image.reshape((1, image.shape[0], image.shape[1], image.shape[2]))

server = 'localhost:8500' # gRPC port
channel = grpc.insecure_channel(server)
stub = prediction_service_pb2_grpc.PredictionServiceStub(channel)

request = predict_pb2.PredictRequest()
request.model_spec.name = 'resnet_v1_50_fp32' # Model name from example
request.model_spec.signature_name = 'predict' # See saved_model_cli show command

request.inputs['input'].CopyFrom(
  tf.compat.v1.make_tensor_proto(image, dtype=tf.float32, shape=[1, image.shape[1], image.shape[2], image.shape[3]]))

result = stub.Predict(request, 30.0) # 30 secs timeout
probabilities = numpy.array(result.outputs['probabilities'].float_val)
probabilities = numpy.resize(probabilities, [1, 1000])
print("predictions: ", decode_predictions(probabilities, top=3)[0]) # Convert probabilities to class labels
