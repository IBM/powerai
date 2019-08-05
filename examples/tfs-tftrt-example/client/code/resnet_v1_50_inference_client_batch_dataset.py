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

""" Inference client batch request example running TensorRT-optimized model

Usage: python resnet_v1_50_inference_client_batch_dataset.py --data_dir <dir> \
         --max_test_images <number> --batch_size <number>

"""
import os
import argparse
import grpc
import requests
import numpy
import urllib.request, json

import tensorflow as tf
from tensorflow.python import keras
from tensorflow.python.keras.preprocessing.image import load_img
from tensorflow.python.keras.preprocessing.image import img_to_array
from tensorflow.python.keras.applications.vgg16 import preprocess_input
from tensorflow.compat.v1 import make_tensor_proto
from tensorflow_serving.apis import predict_pb2
from tensorflow_serving.apis import prediction_service_pb2_grpc

_IMAGENET_SYNSET = 'http://www.image-net.org/api/text/imagenet.synset.geturls?wnid=n02958343'
_IMAGES_DIR = 'car'
_IMAGENET_CLASS_INDEX_URL = 'https://storage.googleapis.com/download.tensorflow.org/data/imagenet_class_index.json'
_IMAGE_HEIGHT = 256
_IMAGE_WIDTH = 256
_IMAGE_CHANNELS = 3

parser = argparse.ArgumentParser()
parser.add_argument('--data_dir', default=None, help='The directory where to save downloaded files.')
parser.add_argument('--max_test_images', type=int, default=50, help='Limit number of loops.')
parser.add_argument('--batch_size', type=int, default=10, help='The number of samples in each batch.')

imagenet_class_index = None

# Test data is image-net images
def download_testdata(data_dir):
    testdata_dir = os.path.join(data_dir, _IMAGES_DIR)

    if not os.path.isdir(testdata_dir):
        os.makedirs(testdata_dir)

        r = requests.get(_IMAGENET_SYNSET)

        image_url_list = r.text

        image_urls = image_url_list.split()

        actual_number_of_images_downloaded = 0

        for num_test_images, url in enumerate(image_urls):
            filename = url.split('/')[-1]
            try:
                r = requests.get(url, timeout=30)
            except (requests.exceptions.ReadTimeout, requests.exceptions.ConnectionError) as err:
                print('Exception: ', r.status_code, 'url: ', url)

            if r.status_code == 200:
                filename_and_path = os.path.join(testdata_dir, filename)
                with open(filename_and_path, 'wb') as f:
                    f.write(r.content)
                actual_number_of_images_downloaded += 1

            if actual_number_of_images_downloaded >= args.max_test_images:
                break

    return testdata_dir

# Get file names of downloaded images
def get_filenames(testdata_dir):
    photo_filenames = []

    for filename in os.listdir(testdata_dir):
        path = os.path.join(testdata_dir, filename)
        photo_filenames.append(path)

    return photo_filenames

# Convert predictions to image-net class label
def decode_predictions(predictions, top=3):
    global imagenet_class_index

    if imagenet_class_index is None:
        with urllib.request.urlopen(_IMAGENET_CLASS_INDEX_URL) as url:
            imagenet_class_index = json.loads(url.read())

    top_predictions = predictions.argsort()

    result_classes = []; i = 0
    for prediction in reversed(list(top_predictions)):
        result_class = tuple(imagenet_class_index[str(prediction-1)]) + (predictions[prediction],)
        result_classes.append(result_class)
        i += 1
        if i >= top:
            break 
    return result_classes

def main(args):
    if args.batch_size > 64:
        print('The maximum batch size for the model is 64.')
        return

    testdata_dir = download_testdata(args.data_dir)

    photo_filenames = get_filenames(testdata_dir)

    num_test_images = args.max_test_images; num_batch_images = args.batch_size; predict_images = []
    for filename in photo_filenames:
        try:
            # Load the image and resize to (224, 224)
            image = load_img(filename, target_size=(224, 224))
        except:
            print('load_img exception - skipping image')
            num_test_images -= 1
            continue
        # Add channels (224, 224, 3)
        image = img_to_array(image)
        # Scale pixels for Tensorflow
        image = preprocess_input(image)

        num_test_images -= 1

        predict_images.append(image)
        num_batch_images -= 1

        if num_batch_images == 0 or num_test_images == 0:
            predict_images = numpy.array(predict_images)             
            server = 'server:8500' # gRPC port
            channel = grpc.insecure_channel(server)
            stub = prediction_service_pb2_grpc.PredictionServiceStub(channel)

            request = predict_pb2.PredictRequest()
            request.model_spec.name = 'resnet_v1_50_fp32' # Model name from example
            request.model_spec.signature_name = 'predict' # See saved_model_cli show command

            request.inputs['input'].CopyFrom(
                tf.compat.v1.make_tensor_proto(predict_images))

            result = stub.Predict(request, 30.0) # 30 secs timeout
            num_batch_probabilities = result.outputs['probabilities'].tensor_shape.dim[0].size
            num_probabilities = result.outputs['probabilities'].tensor_shape.dim[1].size
            probabilities_shape = (num_batch_probabilities, num_probabilities)
            probabilities = numpy.array(result.outputs['probabilities'].float_val)
            probabilities = numpy.reshape(probabilities, probabilities_shape)
            for probability_batch in probabilities:
                print("predictions: ", decode_predictions(probability_batch, top=3)) # Convert probabilities to class labels
            num_batch_images = args.batch_size; predict_images = []

        if num_test_images == 0:
            break

if __name__ == '__main__':
    args = parser.parse_args()
    main(args)
