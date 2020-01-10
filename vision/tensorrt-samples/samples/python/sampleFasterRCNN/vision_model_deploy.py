# Copyright 2019. IBM All Rights Reserved.
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

#encoding=utf8
'''
Detection with FRCNN
In this example, we will load a FRCNN model and use it to detect objects.
'''

import os
import sys
import json
import argparse
import time
import cv2

import numpy as np
# from dnn_util.config import cfg
from dnn_util.py_cpu_nms import py_cpu_nms as nms
from dnn_util.bbox_transform import clip_boxes, bbox_transform_inv

from dnn_util.paths import PATHS  # Path management

from dnn_util.test import _get_image_blob

WINDOW_NAME = 'Camera'

# deploy COD model exported from AI Vision.
class VisionCODModelDeploy(object):

    def __init__(self, net_file, model_file, json_file, label_file, batch_size, resolution):

        attribute_file = " "

        self._parseModelInfo(json_file, label_file, attribute_file)

        self.batch_size = batch_size
        # cfg.TEST.HAS_RPN = True
        self.nms_threshold = 0.3
        # load model
        import tensorrt as trt
        import dnn_util.inference as inference_utils  # TRT inference wrappers

        TRT_PRECISION_TO_DATATYPE = {
            16: trt.DataType.HALF,
            32: trt.DataType.FLOAT
        }
        trt_engine_datatype = TRT_PRECISION_TO_DATATYPE[16]

        trt_engine_path = PATHS.get_engine_path(trt_engine_datatype, batch_size)
        print("trt_engine_path:", trt_engine_path)
        try:
            os.makedirs(os.path.dirname(trt_engine_path))
        except:
            pass

        # override native resolution with command line or prototxt
        try:
            import re
            if resolution != "":
                wh = resolution.split('x')
                w = int(wh[0])
                h = int(wh[1])

                f = open(net_file, 'r')
                contents = f.read()
                f.close()
                contents = re.sub('(?<=input: "data"\ninput_shape {\n  dim: 1\n  dim: 3\n  dim: )[0-9]+', str(h), contents)
                contents = re.sub('(?<=input: "data"\ninput_shape {\n  dim: 1\n  dim: 3\n  dim: ' + str(h) + '\n  dim: )[0-9]+', str(w), contents)
                f = open(net_file, 'w')
                f.write(contents)
                f.close()
            else:
                f = open(net_file, 'r')
                contents = f.read()
                f.close()
                dim = re.search('(?<=input: "data"\ninput_shape {\n  dim: 1\n  dim: 3\n  dim: )[0-9]+', contents)
                h = contents[dim.span()[0]:dim.span()[1]]
                dim = re.search('(?<=input: "data"\ninput_shape {\n  dim: 1\n  dim: 3\n  dim: ' + h + '\n  dim: )[0-9]+', contents)
                w = int(contents[dim.span()[0]:dim.span()[1]])
                h = int(h)

            import dnn_util.model as model_utils
            model_utils.ModelData.INPUT_SHAPE = (3, h, w)
        except Exception as e:
            import logging
            logging.info('Bad resolution, using defaults')

        self.trt_inference_wrapper = inference_utils.TRTInference(
            net_file, trt_engine_path, model_file,
            trt_engine_datatype=trt_engine_datatype,
            batch_size=batch_size)

    def inference(self, image, conf_threshold):
        objects = self._detect(image, conf_threshold)
        return objects

    def _parseModelInfo(self, json_file, label_file, attribute_file):

        with open(label_file, "r") as f:
            classname = f.read()
        self.classname = ('__background__',) + tuple(list(eval(classname)))

        with open(json_file, "r") as f:
            model_info = json.load(f)

        if os.path.exists(attribute_file):
            attributename = open(attribute_file,'r').read()
            self.attributename = ('__background__',)+tuple(list(eval(attributename)))
            self.accuracy_cls, self.accuracy_attribute = model_info["accuracy"].split(',')
        else:
            self.attributename = ('__background__',)
            self.accuracy_cls= model_info["accuracy"].split(',')
        self.name = model_info["accuracy"]

    def _detect(self, image, conf_threshold):

        from os import listdir
        from os.path import isdir, isfile, join
        import dnn_util.model as model_utils

        # Start measuring time
        loadimage_start_time = time.time()

        # handle post files, get folders and comma separated file paths/names
        if isinstance(image, list):
            images = []
            for im in image:
                if isdir(im):
                    images.extend([join(im, f) for f in listdir(im) if isfile(join(im, f))])
                else:
                    images.append(im)
        elif isinstance(image, str):
            images = image.split(',')
        elif isinstance(image, np.ndarray):
            images = [image]

        # actual number of images
        actual_batch_size = len(images)

        image_w = [0] * actual_batch_size
        image_h = [0] * actual_batch_size
        im_scales = [1.0] * actual_batch_size

        def _get_image_blob(im, SCALES, MAX_SIZE):

            PIXEL_MEANS = np.array([[[102.9801, 115.9465, 122.7717]]])

            im_orig = im.astype(np.float32, copy=True)
            im_shape = im_orig.shape
            im_size_min = np.min(im_shape[0])
            im_size_max = np.max(im_shape[1])

            target_size = SCALES
            im_scale = float(target_size) / float(im_size_min)
            # Prevent the biggest axis from being more than MAX_SIZE
            if np.round(im_scale * im_size_max) > MAX_SIZE:
                im_scale = float(MAX_SIZE) / float(im_size_max)

            # Subtract cfg.PIXEL_MEANS on smaller image:
            # if im_scale <1 subtract after resize, otherwise subtract before resize
            im = cv2.resize(im_orig, None, None, fx=im_scale, fy=im_scale, interpolation=cv2.INTER_AREA)
            im = cv2.subtract(im, (PIXEL_MEANS[0][0][0], PIXEL_MEANS[0][0][1], PIXEL_MEANS[0][0][2], 0))

            blob = np.zeros((SCALES, MAX_SIZE, 3), dtype=np.float32)
            blob[0:im.shape[0], 0:im.shape[1], :] = im
            blob = blob.transpose((2, 0, 1))

            return blob, im_scale

        # images_np = np.zeros((actual_batch_size, 3, model_utils.ModelData.INPUT_SHAPE[1], model_utils.ModelData.INPUT_SHAPE[2]), np.float32)
        transformed_images = np.zeros((self.batch_size, 3, model_utils.ModelData.INPUT_SHAPE[1], model_utils.ModelData.INPUT_SHAPE[2]), np.float32)
        for i, image in enumerate(images):
            if isinstance(image, str):
                image = cv2.imread(image)
            images[i] = image
            image_w[i], image_h[i] = image.shape[1], image.shape[0]
            transformed_images[i], im_scales[i] = _get_image_blob(image, model_utils.ModelData.INPUT_SHAPE[1], model_utils.ModelData.INPUT_SHAPE[2])

        print("Image loading time: {} ms for {} images".format(int(round((time.time() - loadimage_start_time) * 1000)), actual_batch_size))

        # Start measuring time
        inference_start_time = time.time()

        # Get TensorRT FRCNN model output
        rois, box_deltas, scores = self.trt_inference_wrapper.infer_batch(transformed_images)

        # number of images in all batches, some trailing images unused
        import math
        max_batch_size = int(math.ceil(float(actual_batch_size) / float(self.batch_size)) * self.batch_size)

        max_cls_size = len(self.classname)
        rois = np.reshape(rois, (max_batch_size, 300, 4))
        box_deltas = np.reshape(box_deltas, (max_batch_size, 300, 4*max_cls_size))
        scores = np.reshape(scores, (max_batch_size, 300, max_cls_size))

        boxes = rois[:, :, 0:4] / 1#im_scales[0]

        objects_list = []
        for index in range(actual_batch_size):
            # adjust bboxes to absolute location and size
            box = boxes[index, :, :]

            import dnn_util.model as model_utils
            # box[:, 0] /= float(model_utils.ModelData.INPUT_SHAPE[2]) / image_w[index]
            # box[:, 1] /= float(model_utils.ModelData.INPUT_SHAPE[1]) / image_h[index]
            # box[:, 2] /= float(model_utils.ModelData.INPUT_SHAPE[2]) / image_w[index]
            # box[:, 3] /= float(model_utils.ModelData.INPUT_SHAPE[1]) / image_h[index]
            box /= im_scales[index]

            pred_boxes = bbox_transform_inv(box, box_deltas[index, :, :])
            pred_boxes = clip_boxes(pred_boxes, (image_h[index], image_w[index]))
            for cls_ind, cls in enumerate(self.classname[1:]):
                cls_ind += 1 # because we skipped background
                cls_boxes = pred_boxes[:, 4*cls_ind:4*(cls_ind + 1)]
                cls_scores = scores[index, :, cls_ind]
                dets = np.hstack((cls_boxes, cls_scores[:, np.newaxis])).astype(np.float32)
                keep = nms(dets[:,:5], self.nms_threshold)
                dets = dets[keep, :]
                objects = self._get_object(cls, dets, thresh=conf_threshold)
                for object in objects:
                    object['image_id'] = index
                objects_list.extend(objects)

        print("Image inference time: {} ms for {} images".format(int(round((time.time() - inference_start_time) * 1000)), actual_batch_size))

        # draws bboxes on images just for debugging
        def analyze_prediction(obj, k, imgid, img_pil):
            class_name = obj['label']
            confidence = obj['confidence']
            xmin = obj['xmin']
            ymin = obj['ymin']
            xmax = obj['xmax']
            ymax = obj['ymax']
            confidence_percentage = "{0:.0%}".format(confidence)
            # print("Detected {} with confidence {}".format(class_name, confidence_percentage))
            cv2.rectangle(img_pil, (xmin, ymin), (xmax, ymax), (0, 255, 0), 4)
            # cv2.imwrite('/home/nvidia/Downloads/tmp/img_' + str(imgid) + '_' + str(k) + '_.jpg', img_pil)

        if len(objects_list) > 0:
            for k, object_item in enumerate(objects_list):
                analyze_prediction(object_item, k, object_item['image_id'], images[object_item['image_id']])

        cv2.imshow(WINDOW_NAME, images[0])

        return objects_list

    def _get_object(self, class_name, dets, thresh=0.5):
        objects_list = []
        inds = np.where(dets[:, 4] >= thresh)[0]
        if len(inds) == 0:
            return []
        for i in inds:
            bbox = dets[i, :4]
            score = dets[i, 4]
            attribute_score = dets[i, 5:]
            object_item = {}
            object_item['label'] = class_name
            object_item['confidence'] = round(float(score), 5)
            object_item['xmin'] = int(bbox[0])
            object_item['ymin'] = int(bbox[1])
            object_item['xmax'] = int(bbox[2])
            object_item['ymax'] = int(bbox[3])
            attr_list = []
            attr_dict = {}
            for attr_ind, attr in enumerate(self.attributename[1:]):
                attr_ind += 1
                if float(attribute_score[attr_ind]>0.8):
                    attr_dict[attr] = attribute_score[attr_ind]
            attr_list.append(attr_dict) 
            object_item['attr'] = attr_list
            objects_list.append(object_item)
        return objects_list

def main(argv):
    parser = argparse.ArgumentParser()

    parser.add_argument(
        "--net_file",
        required = True,
        help = "Model prototxt file for deployment.",
    )

    parser.add_argument(
        "--model_file",
        required = True,
        help = "Model weights caffemodel file for deployment.",
    )

    parser.add_argument(
        "--json_file",
        required = True,
        help = "Json file for deployment.",
    )

    parser.add_argument(
        "--label_file",
        required = True,
        help = "Label prototxt file for deployment.",
    )

    parser.add_argument(
        "--batch",
        default = 20,
        type = int,
        help = "Batch size for TensorRT inference",
    )

    parser.add_argument(
        "--resolution",
        default = "1000x600",
        help = "Override native inference resolution",
    )
    
    parser.add_argument(
        "--image_name",
        required = True,
        default = "",
        help = "Image file full path",
    )

    parser.add_argument(
        "--confthre",
        default = 0.5,
        help = "Override confidence threshold",
    )

    def open_window(width, height):
        cv2.namedWindow(WINDOW_NAME, cv2.WINDOW_NORMAL)
        cv2.resizeWindow(WINDOW_NAME, width, height)
        cv2.moveWindow(WINDOW_NAME, 0, 0)
        cv2.setWindowTitle(WINDOW_NAME, 'Camera Demo for Jetson TX2/TX1')

    open_window(1280, 720)

    args, _ = parser.parse_known_args()
    detector = VisionCODModelDeploy(args.net_file, args.model_file, args.json_file, args.label_file, args.batch, args.resolution)
    if args.image_name != 'Camera':
        results = detector.inference(args.image_name, args.confthre)
        print(results)
    else:
        gst_str = ('nvarguscamerasrc ! nvvidconv ! video/x-raw, format=BGRx ! videoconvert ! video/x-raw, format=BGR ! appsink')
        cap = cv2.VideoCapture(gst_str, cv2.CAP_GSTREAMER)
        if cap.isOpened():
            while True:
                _, img = cap.read()
                results = detector.inference(img, args.confthre)
                print(results)
                if cv2.getWindowProperty(WINDOW_NAME, 0) < 0:
                    break
                key = cv2.waitKey(1)
                if key == 27:  # ESC key: quit program
                    break
            cap.release()

    cv2.destroyAllWindows()

if __name__ == '__main__':
    main(sys.argv)
