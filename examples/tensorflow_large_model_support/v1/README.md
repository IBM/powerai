# TensorFlow Large Model Support Examples

This directory contains examples for using the original version of TensorFlow
Large Model Support (TFLMS) included in IBM PowerAI which exists in the
`tensorflow.contrib.lms` Python module.

## Session based training example
The [mnist_deep_lms.py]|mnist_deep_lms.py file is an example of how to
enable TFLMS when using Session based training. This example is
a TFLMS enabled version of [this TensorFlow example]|https://github.com/tensorflow/tensorflow/blob/v1.12.0/tensorflow/examples/tutorials/mnist/mnist_deep.py.

## Estimator based training example
The [cnn_mnist_lms.py]|cnn_mnist_lms.py file is an example of how to
enable TFLMS when using Estimator based training. This example is
a TFLMS enabled version of [this TensorFlow example]|https://github.com/tensorflow/tensorflow/blob/v1.13.1/tensorflow/examples/tutorials/layers/cnn_mnist.py.
