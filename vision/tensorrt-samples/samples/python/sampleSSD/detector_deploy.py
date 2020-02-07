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
Detection with SSD
In this example, we will load a SSD model and use it to detect objects.
'''

import os
import sys
import argparse
import numpy as np
import cv2

import tensorrt as trt

import utils.inference as inference_utils # TRT inference wrappers
import utils.model as model_utils #
from utils.paths import PATHS # Path management
import time

WINDOW_NAME = 'Camera'

def get_labelname(labelmap, labels):
    num_labels = len(labelmap)
    labelnames = []
    if type(labels) is not list:
        labels = [labels]
    for label in labels:
        labelnames.append(labelmap[int(label)])
    return labelnames

class Detector():
    def __init__(self, model_def, model_weights, labelmap_file, gpu_mode, trt_mode, batch_size, resolution):

        self.batch_size = batch_size

        TRT_PRECISION_TO_DATATYPE = {
            16: trt.DataType.HALF,
            32: trt.DataType.FLOAT
        }
        trt_engine_datatype = TRT_PRECISION_TO_DATATYPE[16]

        ssd_model_path = model_weights
        ssd_deploy_path = model_def

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

                f = open(ssd_deploy_path, 'r')
                contents = f.read()
                f.close()
                contents = re.sub('(?<=input: "data"\ninput_shape {\n  dim: 1\n  dim: 3\n  dim: )[0-9]+', str(h), contents)
                contents = re.sub('(?<=input: "data"\ninput_shape {\n  dim: 1\n  dim: 3\n  dim: ' + str(h) + '\n  dim: )[0-9]+', str(w), contents)
                f = open(ssd_deploy_path, 'w')
                f.write(contents)
                f.close()
            else:
                f = open(ssd_deploy_path, 'r')
                contents = f.read()
                f.close()
                dim = re.search('(?<=input: "data"\ninput_shape {\n  dim: 1\n  dim: 3\n  dim: )[0-9]+', contents)
                h = contents[dim.span()[0]:dim.span()[1]]
                dim = re.search('(?<=input: "data"\ninput_shape {\n  dim: 1\n  dim: 3\n  dim: ' + h + '\n  dim: )[0-9]+', contents)
                w = int(contents[dim.span()[0]:dim.span()[1]])
                h = int(h)

            import utils.model as model_utils
            model_utils.ModelData.INPUT_SHAPE = (3, h, w)
        except Exception as e:
            import logging
            logging.info('Bad resolution, using defaults')

        # Set up all TensorRT data structures needed for inference
        self.trt_inference_wrapper = inference_utils.TRTInference(
            ssd_deploy_path, trt_engine_path, ssd_model_path,
            trt_engine_datatype=trt_engine_datatype,
            batch_size=batch_size)

        # load PASCAL VOC labels
        file = open(labelmap_file, 'r')
        contents = file.read()
        file.close()
        dim = re.findall('(?<=  name: ")[^"]+', contents)
        self.labelmap = dim

    def detect(self, image, conf_thresh=0.5):
        '''
        SSD detection
        '''
        # Start measuring time
        loadimage_start_time = time.time()

        # handle post files, get folders and comma separated file paths/names
        from os import listdir
        from os.path import isdir, isfile, join
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

        # images2 = np.zeros((actual_batch_size, 3, model_utils.ModelData.INPUT_SHAPE[1], model_utils.ModelData.INPUT_SHAPE[2]), np.float32)
        transformed_images = np.zeros((self.batch_size, 3, model_utils.ModelData.INPUT_SHAPE[1], model_utils.ModelData.INPUT_SHAPE[2]), np.float32)
        for i, image in enumerate(images):
            if isinstance(image, str):
                image = cv2.imread(image)
            images[i] = image
            image_w[i], image_h[i] = image.shape[1], image.shape[0]
            image = cv2.resize(image, (model_utils.ModelData.INPUT_SHAPE[2], model_utils.ModelData.INPUT_SHAPE[1]), interpolation=cv2.INTER_AREA)
            image = image.astype(np.float32)
            image = cv2.subtract(image, (104.0, 117.0, 123.0, 0.0))
            image = image.transpose((2, 0, 1))
            transformed_images[i] = image

        print("Image loading time: {} ms for {} images".format(int(round((time.time() - loadimage_start_time) * 1000)), actual_batch_size))
        inference_start_time = time.time()

        # Get TensorRT SSD model output
        detection_out, keep_count_out = self.trt_inference_wrapper.infer_batch(transformed_images)

        print("detection_out.size:", detection_out.size)

        TRT_PREDICTION_LAYOUT = {
            "image_id": 0,
            "label": 1,
            "confidence": 2,
            "xmin": 3,
            "ymin": 4,
            "xmax": 5,
            "ymax": 6
        }

        # extract fields from contiguous memory
        def fetch_prediction_field(field_name, detection_out, pred_start_idx):
            return detection_out[pred_start_idx + TRT_PREDICTION_LAYOUT[field_name]]

        prediction_fields = len(TRT_PREDICTION_LAYOUT)
        det_image = np.zeros(0, dtype=np.int32)
        det_label = np.zeros(0)
        det_conf = np.zeros(0)
        det_xmin = np.zeros(0)
        det_ymin = np.zeros(0)
        det_xmax = np.zeros(0)
        det_ymax = np.zeros(0)

        # over all images, only one
        for i in range(len(images)):
            start = i * 200
            end = i * 200 + keep_count_out[i]
            # print("start:", start, "end:", end)
            # over all objects
            for det in range(start, end):
                pred_start_idx = det * prediction_fields
                image_id = int(fetch_prediction_field("image_id", detection_out, pred_start_idx))# + i / 2 * 2
                label = int(fetch_prediction_field("label", detection_out, pred_start_idx))
                # print("label:",label)
                confidence = fetch_prediction_field("confidence", detection_out, pred_start_idx)

                xmin = fetch_prediction_field("xmin", detection_out, pred_start_idx)
                ymin = fetch_prediction_field("ymin", detection_out, pred_start_idx)
                xmax = fetch_prediction_field("xmax", detection_out, pred_start_idx)
                ymax = fetch_prediction_field("ymax", detection_out, pred_start_idx)

                det_image = np.append(det_image, image_id)
                det_label = np.append(det_label, label)
                det_conf = np.append(det_conf, confidence)
                det_xmin = np.append(det_xmin, xmin)
                det_ymin = np.append(det_ymin, ymin)
                det_xmax = np.append(det_xmax, xmax)
                det_ymax = np.append(det_ymax, ymax)

        # Get detections with confidence higher than threshold.
        top_indices = [i for i, conf in enumerate(det_conf) if conf >= conf_thresh]

        top_conf = det_conf[top_indices]
        top_image_ids = det_image[top_indices]
        top_label_indices = det_label[top_indices].tolist()
        top_labels = get_labelname(self.labelmap, top_label_indices)
        top_xmin = det_xmin[top_indices]
        top_ymin = det_ymin[top_indices]
        top_xmax = det_xmax[top_indices]
        top_ymax = det_ymax[top_indices]

        objects_list = []
        for i in xrange(top_conf.shape[0]):
            object_item = {}
            object_item['xmin'] = int(round(top_xmin[i] * image_w[top_image_ids[i]]))
            object_item['ymin'] = int(round(top_ymin[i] * image_h[top_image_ids[i]]))
            object_item['xmax'] = int(round(top_xmax[i] * image_w[top_image_ids[i]]))
            object_item['ymax'] = int(round(top_ymax[i] * image_h[top_image_ids[i]]))
            object_item['confidence'] = float(top_conf[i])
            object_item['image_id'] = top_image_ids[i]
            object_item['label'] = top_labels[i]
            objects_list.append(object_item)

        print("Image inference time: {} ms for {} images".format(int(round((time.time() - inference_start_time) * 1000)), actual_batch_size))

        # draws bboxes on images just for debugging
        def analyze_prediction(obj, k, imgid, img_pil):
            class_name = obj['label']
            confidence = obj['confidence']
            xmin = obj['xmin']
            ymin = obj['ymin']
            xmax = obj['xmax']
            ymax = obj['ymax']
            # confidence_percentage = "{0:.0%}".format(confidence)
            # print("Detected {} with confidence {}".format(class_name, confidence_percentage))
            cv2.rectangle(img_pil, (xmin, ymin), (xmax, ymax), (0, 255, 0), 4)
            # cv2.imwrite('/home/nvidia/Downloads/tmp/img_' + str(imgid) + '_' + str(k) + '_.jpg', img_pil)

        if len(objects_list) > 0:
            for k, object_item in enumerate(objects_list):
                analyze_prediction(object_item, k, object_item['image_id'], images[object_item['image_id']])

        cv2.imshow(WINDOW_NAME, images[0])

        return objects_list

def main(argv):
    parser = argparse.ArgumentParser()

    parser.add_argument(
        "--model_def",
        required = True,
        help = "Model prototxt file path.",
    )
    parser.add_argument(
        "--model_weights",
        required = True,
        help = "Model weights file path.",
    )
    parser.add_argument(
        "--labelmap_file",
        required = True,
        help = "Model label (prototxt) file path.",
    )

    parser.add_argument(
        "--batch",
        default = 20,
        type = int,
        help = "Batch size for TensorRT inference",
    )
    parser.add_argument(
        "--resolution",
        default = "512x512",
        help = "Override native model resolution",
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

    detector = Detector(args.model_def, args.model_weights, args.labelmap_file, True, True, args.batch, args.resolution)
    if args.image_name != 'Camera':
        results = detector.detect(args.image_name, args.confthre)
        print(results)
    else:
        gst_str = ('nvarguscamerasrc ! nvvidconv ! video/x-raw, format=BGRx ! videoconvert ! video/x-raw, format=BGR ! appsink')
        cap = cv2.VideoCapture(gst_str, cv2.CAP_GSTREAMER)
        if cap.isOpened():
            while True:
                _, img = cap.read()
                results = detector.detect(img, args.confthre)
                print(results)
                key = cv2.waitKey(1)
                if key == 27:  # ESC key: quit program
                    break
                if cv2.getWindowProperty(WINDOW_NAME, 0) < 0:
                    break
            cap.release()

    cv2.destroyAllWindows()

if __name__ == '__main__':
    main(sys.argv)
