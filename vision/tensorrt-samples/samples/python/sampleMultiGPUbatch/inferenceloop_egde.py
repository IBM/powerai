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

import os, subprocess
import logging
import time
from threading import Thread
import multiprocessing
from multiprocessing import Process
import traceback

import argparse
import requests
import json
import csv
import collections
import re

manager = multiprocessing.Manager()
queue = manager.Queue()
results = manager.Queue()

cfg = {}
csvResult = {}

def post(url, **kwargs):
    return requests.post(url, **kwargs)

def worker_thread(port):

    print('{{')

    while queue.qsize() > 0:
        img = queue.get()
        try:
            print('{')
            url = "http://localhost:" + str(port) + "/inference"
            
            # post
            if type(img) is str:
                #params = {"files": open(str(img), 'rb')}
                params = {"imagefile": open(str(img), 'rb')}
            elif type(img) is list:
                params = [('imagefile', open(i, 'rb')) for i in img]

            #rsp = requests.post(url, params, verify=False)
            rsp = requests.post(url, files=params, verify=False)
            
            # get
            # if type(img) is str:
            #     params = {'imageurl': 'file:///temp/' + img, 'confthre': 0.8}
            # elif type(img) is list:
            #     params = [('imageurl', 'file:///temp/' + i) for i in img]

            #rsp = requests.get(url, params)
            results.put(rsp)

            print('} ' + ' ' + str(port))# + ' ' + str(img) + ' ' + rsp.text)
        except Exception as e:
            print(str(port))
            print(str(e))
            print(traceback.print_exc())
            break

    print('}}')


def main():
    parser = argparse.ArgumentParser()

    parser.add_argument("--numperGPU", type=int, default=4, help="Models per GPU")
    parser.add_argument("--numGPUs", type=int, default=2, help="Number of GPUs")
    parser.add_argument("--batch", type=int, default=20, help="Batch size 1-20")
    parser.add_argument("--iterations", type=int, default=10, help="Iterations")
    parser.add_argument("--baseport", type=int, default=6000, help="Base port number")

    parser.add_argument("--width", type=int, default=1000, help="Model resolution width")
    parser.add_argument("--height", type=int, default=600, help="Model resolution height")
    #parser.add_argument("--model", type=str, help="Model zip file")
    parser.add_argument("--model", type=str, help="Model zip file",default="/home/zoe/models/50x5_detectron_3.zip")

    #parser.add_argument("--folder", type=str, help="Images folder")
    parser.add_argument("--folder", type=str, help="Images folder",default="/home/zoe/images")
    #parser.add_argument("--file", type=str, help="Image file, just base name")
    parser.add_argument("--file", type=str, help="Image file, just base name",default="/Image__2020-09-22__08-55-58.jpg")

    # parser.add_argument("--numperGPU", type=int, default=10, help="Models per GPU")
    # parser.add_argument("--numGPUs", type=int, default=4, help="Number of GPUs")
    # parser.add_argument("--batch", type=int, default=1, help="Batch size 1-20")
    # parser.add_argument("--width", type=int, default=1000, help="Model resolution width")
    # parser.add_argument("--height", type=int, default=600, help="Model resolution height")
    # parser.add_argument("--model", type=str, help="Model zip file")
    # parser.add_argument("--baseport", type=int, default=6000, help="Base port number")
    # parser.add_argument("--folder", type=str, help="Images folder")
    # parser.add_argument("--file", type=str, help="Image file, just base name")
    # parser.add_argument("--iterations", type=int, default=1000, help="Iterations")

    args = parser.parse_args()

    # deploy models
    # can skip this if already running
    cmd = ""

    for i in range(args.numGPUs):
        for j in range(args.numperGPU):
            port = args.baseport + i * 100 + j
            # os.system("docker stop myfrcnn" + str(i) + str(j))
            # os.system("docker rm myfrcnn" + str(i) + str(j))
            #cmd = "sudo /opt/powerai-vision/dnn-deploy-service/bin/deploy_zip_model.sh -m myfrcnn" + str(i) + str(j) + " -p " + str(port) + " -g " + str(i) \
            #    + " -v " + args.folder + ":/temp --trt --batch " + str(args.batch) + " --resolution " + str(args.width) + "x" + str(args.height) + " " + args.model# & "
            cmd = "/opt/ibm/vision-edge/bin/deploy_zip_model.sh -m mydetectron" + str(i) + str(j) + " -p " + str(port) + " -g " + str(i) \
                + " -v " + args.folder + ":/temp --trt --batch " + str(args.batch) + " --resolution " + str(args.width) + "x" + str(args.height) + " " + args.model# & "
            print(cmd)
            rez = os.popen(cmd + " wait").read()
            print(rez)
            pass

    # inference with a queue
    ts = time.time()

    # for 1000x1 images
    for img in range(args.iterations):
        if args.batch == 1:
            queue.put(args.folder+args.file)
        else:
            queue.put([args.folder+args.file for i in range(args.batch)])

    from multiprocessing.managers import BaseProxy
    if 'localhost' in BaseProxy._address_to_local:
        del BaseProxy._address_to_local['localhost'][0].connection

    for x in range(args.numperGPU * args.numGPUs):
        port = args.baseport + x / args.numperGPU * 100 + x % args.numperGPU + 0
        worker = Process(target=worker_thread, args=([port]))
        worker.start()

    while queue.qsize() > 0:
        time.sleep(0.01)

    # wait for workers
    time.sleep(0.5)

    inference_time = time.time() - ts
    print('Took %s seconds %s fps' % (str(inference_time), str((results.qsize()*args.batch)/inference_time)))

    time.sleep(1.0)

    # clean up models
    # skip this if one wants to keep servers running
    for i in range(args.numGPUs):
        for j in range(args.numperGPU):
            os.system("docker stop mydetectron" + str(i) + str(j))
            os.system("docker rm mydetectron" + str(i) + str(j))
            pass

if __name__ == '__main__':
    main()

