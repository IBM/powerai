# Utility functions for performing image inference
#
# Copyright 1993-2019 NVIDIA Corporation.  All rights reserved.
#
# NOTICE TO LICENSEE:
#
# This source code and/or documentation ("Licensed Deliverables") are
# subject to NVIDIA intellectual property rights under U.S. and
# international Copyright laws.
#
# These Licensed Deliverables contained herein is PROPRIETARY and
# CONFIDENTIAL to NVIDIA and is being provided under the terms and
# conditions of a form of NVIDIA software license agreement by and
# between NVIDIA and Licensee ("License Agreement") or electronically
# accepted by Licensee.  Notwithstanding any terms or conditions to
# the contrary in the License Agreement, reproduction or disclosure
# of the Licensed Deliverables to any third party without the express
# written consent of NVIDIA is prohibited.
#
# NOTWITHSTANDING ANY TERMS OR CONDITIONS TO THE CONTRARY IN THE
# LICENSE AGREEMENT, NVIDIA MAKES NO REPRESENTATION ABOUT THE
# SUITABILITY OF THESE LICENSED DELIVERABLES FOR ANY PURPOSE.  IT IS
# PROVIDED "AS IS" WITHOUT EXPRESS OR IMPLIED WARRANTY OF ANY KIND.
# NVIDIA DISCLAIMS ALL WARRANTIES WITH REGARD TO THESE LICENSED
# DELIVERABLES, INCLUDING ALL IMPLIED WARRANTIES OF MERCHANTABILITY,
# NONINFRINGEMENT, AND FITNESS FOR A PARTICULAR PURPOSE.
# NOTWITHSTANDING ANY TERMS OR CONDITIONS TO THE CONTRARY IN THE
# LICENSE AGREEMENT, IN NO EVENT SHALL NVIDIA BE LIABLE FOR ANY
# SPECIAL, INDIRECT, INCIDENTAL, OR CONSEQUENTIAL DAMAGES, OR ANY
# DAMAGES WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS,
# WHETHER IN AN ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS
# ACTION, ARISING OUT OF OR IN CONNECTION WITH THE USE OR PERFORMANCE
# OF THESE LICENSED DELIVERABLES.
#
# U.S. Government End Users.  These Licensed Deliverables are a
# "commercial item" as that term is defined at 48 C.F.R. 2.101 (OCT
# 1995), consisting of "commercial computer software" and "commercial
# computer software documentation" as such terms are used in 48
# C.F.R. 12.212 (SEPT 1995) and is provided to the U.S. Government
# only as a commercial end item.  Consistent with 48 C.F.R.12.212 and
# 48 C.F.R. 227.7202-1 through 227.7202-4 (JUNE 1995), all
# U.S. Government End Users acquire the Licensed Deliverables with
# only those rights set forth herein.
#
# Any use of the Licensed Deliverables in individual and commercial
# software must include, in the user documentation and internal
# comments to the code, the above Disclaimer and U.S. Government End
# Users Notice.

import os
import sys

import tensorrt as trt

import numpy as np

import dnn_util.engine as engine_utils # TRT Engine creation/save/load utils
import dnn_util.model as model_utils
import dnn_util.common as common
# ../../common.py
sys.path.insert(1,
    os.path.join(
        os.path.dirname(os.path.realpath(__file__)),
        os.pardir,
        os.pardir
    )
)

DATATYPE = {
    trt.DataType.HALF: np.float16,
    trt.DataType.FLOAT: np.float32
}

# TensorRT logger singleton
TRT_LOGGER = trt.Logger(trt.Logger.WARNING)

class TRTInference(object):
    """Manages TensorRT objects for model inference."""
    def __init__(self, trt_deploy_path, trt_engine_path, trt_model_path, trt_engine_datatype=trt.DataType.FLOAT, batch_size=1):
        """Initializes TensorRT objects needed for model inference.

        Args:
            trt_engine_path (str): path where TensorRT engine should be stored
            trt_model_path (str): path of caffe model
            trt_engine_datatype (trt.DataType):
                requested precision of TensorRT engine used for inference
            batch_size (int): batch size for which engine
                should be optimized for
        """

        # We first load all custom plugins shipped with TensorRT,
        # some of them will be needed during inference
        trt.init_libnvinfer_plugins(TRT_LOGGER, '')

        # Initialize runtime needed for loading TensorRT engine from file
        self.trt_runtime = trt.Runtime(TRT_LOGGER)
        # TRT engine placeholder
        self.trt_engine = None

        self.datatype = DATATYPE[trt_engine_datatype]
        # Display requested engine settings to stdout
        print("TensorRT inference engine settings:")
        print("  * Inference precision - {}".format(trt_engine_datatype))
        print("  * Max batch size - {}\n".format(batch_size))

        # If engine is not cached, we need to build it
        if not os.path.exists(trt_engine_path):
           # For more details, check implmentation
            self.trt_engine = engine_utils.build_engine(
                trt_deploy_path, trt_model_path, TRT_LOGGER,
                trt_engine_datatype=trt_engine_datatype,
                batch_size=batch_size)
            print("self.trt_engine:",self.trt_engine)
            # Save the engine to file
            engine_utils.save_engine(self.trt_engine, trt_engine_path)

        # If we get here, the file with engine exists, so we can load it
        if not self.trt_engine:
            print("Loading cached TensorRT engine from {}".format(
                trt_engine_path))
            self.trt_engine = engine_utils.load_engine(
                self.trt_runtime, trt_engine_path)

        # This allocates memory for network inputs/outputs on both CPU and GPU
        self.inputs, self.outputs, self.bindings, self.stream =  common.allocate_buffers(self.trt_engine)
          #  engine_utils.allocate_buffers(self.trt_engine)
          #  common.allocate_buffers(self.trt_engine)
        # Execution context is needed for inference
        self.context = self.trt_engine.create_execution_context()

        # Allocate memory for multiple usage [e.g. multiple batch inference]
        input_volume = trt.volume(model_utils.ModelData.INPUT_SHAPE)
        print("input_volume:",input_volume)
        print("self.trt_engine.max_batch_size:",self.trt_engine.max_batch_size)
        self.numpy_array = np.zeros((self.trt_engine.max_batch_size, input_volume), dtype=np.float32)
        self.im_info = np.zeros((self.trt_engine.max_batch_size, 3), dtype=np.float32)

    def infer_batch(self, img_np):
        """Infers model on batch of same sized images resized to fit the model.

        Args:
            img_np (str): images, that will be packed into batch and fed into model
        """
        max_batch_size = self.trt_engine.max_batch_size
        actual_batch_size = len(img_np)

        # for i in range(actual_batch_size):
        #     self.numpy_array[i] = np.array(img_np[i]).ravel()
        self.numpy_array = img_np

        # Load all images to CPU...
        import dnn_util.model as model_utils
        for i in range(self.trt_engine.max_batch_size):
            self.im_info[i] = np.array([model_utils.ModelData.INPUT_SHAPE[1], model_utils.ModelData.INPUT_SHAPE[2], 1], dtype=np.float32).ravel()
        
        # ...copy them into appropriate place into memory...
        np.copyto(self.inputs[0].host, self.numpy_array.ravel())
        np.copyto(self.inputs[1].host, self.im_info.ravel())

        roiss = np.zeros((0), dtype=np.float32)
        bbox_preds = np.zeros((0), dtype=np.int32)
        cls_probs = np.zeros((0), dtype=np.int32)

        # split inference into batches
        for i in range(0, actual_batch_size, self.trt_engine.max_batch_size):
            # ...fetch model outputs...
            [rois, bbox_pred, cls_prob] = common.do_inference(
                self.context, bindings=self.bindings, inputs=self.inputs,
                outputs=self.outputs, stream=self.stream,
                batch_size=max_batch_size)

            roiss = np.append(roiss, rois, axis=0)
            bbox_preds = np.append(bbox_preds, bbox_pred, axis=0)
            cls_probs = np.append(cls_probs, cls_prob, axis=0)

        return roiss, bbox_preds, cls_probs


