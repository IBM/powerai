# TensorFlow Large Model Support Examples

This directory contains examples for using the TensorFlow
Large Model Support (TFLMS) v2 included in IBM PowerAI in the
`tensorflow-large-model-support` conda package.

## Adjustable image resolution ResNet50
The [Keras_ResNet50.py](Keras_ResNet50.py) file uses the ResNet50 from
keras_applications to demonstrate how to enable TensorFlow Large Model
Support (TFLMS) in a Keras model that cannot fit in GPU memory when
using larger resolution data. It provides a convenient way to test out the
capabilities of TFLMS. Command line parameters allow the user to change
the size of the input image data, enable or disable TFLMS,
and set TFLMS tunables. The `TF_LMS_SIMULATOR_MEM_RATIO` environment variable
should be set to `0.8` when running this model to achieve the best results
with auto tuning.

## Session based training example
The [mnist_deep_lms.py](mnist_deep_lms.py) file is an example of how to
enable TFLMS when using Session based training. This example is
a TFLMS enabled version of [this TensorFlow example](https://github.com/tensorflow/tensorflow/blob/v1.12.0/tensorflow/examples/tutorials/mnist/mnist_deep.py).

## Estimator based training example
The [cnn_mnist_lms.py](cnn_mnist_lms.py) file is an example of how to
enable TFLMS when using Estimator based training. This example is
a TFLMS enabled version of [this TensorFlow example](https://github.com/tensorflow/tensorflow/blob/v1.13.1/tensorflow/examples/tutorials/layers/cnn_mnist.py).

## TensorFlow Keras based training example
The [mnist_cnn_keras.py](mnist_cnn_keras.py) file is an example of how to
enable TFLMS when using TensorFlow Keras based training. This example is a
TFLMS enabled version of [this Keras example](https://github.com/keras-team/keras/blob/2.2.4/examples/mnist_cnn.py).
