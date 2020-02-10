/*
 * Copyright 1993-2019 NVIDIA Corporation.  All rights reserved.
 * Copyright 2019. IBM All Rights Reserved.
 *
 * NOTICE TO LICENSEE:
 *
 * This source code and/or documentation ("Licensed Deliverables") are
 * subject to NVIDIA intellectual property rights under U.S. and
 * international Copyright laws.
 *
 * These Licensed Deliverables contained herein is PROPRIETARY and
 * CONFIDENTIAL to NVIDIA and is being provided under the terms and
 * conditions of a form of NVIDIA software license agreement by and
 * between NVIDIA and Licensee ("License Agreement") or electronically
 * accepted by Licensee.  Notwithstanding any terms or conditions to
 * the contrary in the License Agreement, reproduction or disclosure
 * of the Licensed Deliverables to any third party without the express
 * written consent of NVIDIA is prohibited.
 *
 * NOTWITHSTANDING ANY TERMS OR CONDITIONS TO THE CONTRARY IN THE
 * LICENSE AGREEMENT, NVIDIA MAKES NO REPRESENTATION ABOUT THE
 * SUITABILITY OF THESE LICENSED DELIVERABLES FOR ANY PURPOSE.  IT IS
 * PROVIDED "AS IS" WITHOUT EXPRESS OR IMPLIED WARRANTY OF ANY KIND.
 * NVIDIA DISCLAIMS ALL WARRANTIES WITH REGARD TO THESE LICENSED
 * DELIVERABLES, INCLUDING ALL IMPLIED WARRANTIES OF MERCHANTABILITY,
 * NONINFRINGEMENT, AND FITNESS FOR A PARTICULAR PURPOSE.
 * NOTWITHSTANDING ANY TERMS OR CONDITIONS TO THE CONTRARY IN THE
 * LICENSE AGREEMENT, IN NO EVENT SHALL NVIDIA BE LIABLE FOR ANY
 * SPECIAL, INDIRECT, INCIDENTAL, OR CONSEQUENTIAL DAMAGES, OR ANY
 * DAMAGES WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS,
 * WHETHER IN AN ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS
 * ACTION, ARISING OUT OF OR IN CONNECTION WITH THE USE OR PERFORMANCE
 * OF THESE LICENSED DELIVERABLES.
 *
 * U.S. Government End Users.  These Licensed Deliverables are a
 * "commercial item" as that term is defined at 48 C.F.R. 2.101 (OCT
 * 1995), consisting of "commercial computer software" and "commercial
 * computer software documentation" as such terms are used in 48
 * C.F.R. 12.212 (SEPT 1995) and is provided to the U.S. Government
 * only as a commercial end item.  Consistent with 48 C.F.R.12.212 and
 * 48 C.F.R. 227.7202-1 through 227.7202-4 (JUNE 1995), all
 * U.S. Government End Users acquire the Licensed Deliverables with
 * only those rights set forth herein.
 *
 * Any use of the Licensed Deliverables in individual and commercial
 * software must include, in the user documentation and internal
 * comments to the code, the above Disclaimer and U.S. Government End
 * Users Notice.
 */

#include <algorithm>
#include <cassert>
#include <cmath>
#include <cstring>
#include <cuda_runtime_api.h>
#include <fstream>
#include <iostream>
#include <memory>
#include <sstream>
#include <sys/stat.h>
#include <time.h>

#include "NvCaffeParser.h"
#include "NvInferPlugin.h"
#include "common.h"
#include "logger.h"
#include "argsParser.h"

#include <opencv2/imgcodecs.hpp>
#include <opencv2/videoio.hpp>
#include <opencv2/highgui.hpp>
#include <opencv2/imgproc/imgproc.hpp>

// using namespace std;
// using namespace cv;

const std::string gSampleName = "TensorRT.sample_fasterRCNN";

static samplesCommon::Args gArgs;
using namespace nvinfer1;
using namespace nvcaffeparser1;
using namespace plugin;

// Stuff we know about the network and the caffe input/output blobs
static const int INPUT_C = 3;
static const int INPUT_H = 600; // This value needs to be changed as per prototxt dim
static const int INPUT_W = 1000; // This value needs to be changed as per prototxt dim
static const int IM_INFO_SIZE = 3;
static const int OUTPUT_CLS_SIZE = 3; // This value needs to be changed as per number of classes
static const int OUTPUT_BBOX_SIZE = OUTPUT_CLS_SIZE * 4;
static const int NMS_MAX_OUT = 300; // This value needs to be changed as per the nmsMaxOut value set in RPROI plugin parameters in prototxt
// Batch size
static const int N = 1; // This value needs to be changed as number of images per inference, 1 for camera

static const float nms_threshold = 0.3f;
static const float score_threshold = 0.8f; // This value needs to be changed per confidence threshold

// This value needs to be changed as per number and names of classes
const std::string CLASSES[OUTPUT_CLS_SIZE]{"background", "1", "2"};//, "3", "4", "5", "6", "7", "8", "9", "10", "11", "12", "13", "14", "15", "16", "17", "18", "19", "20"};

const char* INPUT_BLOB_NAME0 = "data";
const char* INPUT_BLOB_NAME1 = "im_info";
const char* OUTPUT_BLOB_NAME0 = "bbox_pred";
const char* OUTPUT_BLOB_NAME1 = "cls_prob";
const char* OUTPUT_BLOB_NAME2 = "rois";

struct PPM
{
    std::string magic, fileName;
    int h, w, max;
    uint8_t buffer[INPUT_C * INPUT_H * INPUT_W];
};

struct BBox
{
    float x1, y1, x2, y2;
};

std::string locateFile(const std::string& input)
{
    // This value needs to be changed as per model and images folder
    std::vector<std::string> dirs{"data/samples/faster-rcnn/", "data/faster-rcnn/"};
    return locateFile(input, dirs);
}

// Simple PPM (portable pixel map) reader
void readPPMFile(const std::string& filename, PPM& ppm)
{
    ppm.fileName = filename;
    std::ifstream infile(locateFile(filename), std::ifstream::binary);
    infile >> ppm.magic >> ppm.w >> ppm.h >> ppm.max;
    infile.seekg(1, infile.cur);
    infile.read(reinterpret_cast<char*>(ppm.buffer), ppm.w * ppm.h * 3);
}

void writePPMFileWithBBox(const std::string& filename, PPM& ppm, const BBox& bbox)
{
    std::ofstream outfile("./" + filename, std::ofstream::binary);
    assert(!outfile.fail());
    outfile << "P6"
            << "\n"
            << ppm.w << " " << ppm.h << "\n"
            << ppm.max << "\n";
    auto round = [](float x) -> int { return int(std::floor(x + 0.5f)); };
    for (int x = int(bbox.x1); x < int(bbox.x2); ++x)
    {
        // Bbox top border
        ppm.buffer[(round(bbox.y1) * ppm.w + x) * 3] = 255;
        ppm.buffer[(round(bbox.y1) * ppm.w + x) * 3 + 1] = 0;
        ppm.buffer[(round(bbox.y1) * ppm.w + x) * 3 + 2] = 0;
        // Bbox bottom border
        ppm.buffer[(round(bbox.y2) * ppm.w + x) * 3] = 255;
        ppm.buffer[(round(bbox.y2) * ppm.w + x) * 3 + 1] = 0;
        ppm.buffer[(round(bbox.y2) * ppm.w + x) * 3 + 2] = 0;
    }
    for (int y = int(bbox.y1); y < int(bbox.y2); ++y)
    {
        // Bbox left border
        ppm.buffer[(y * ppm.w + round(bbox.x1)) * 3] = 255;
        ppm.buffer[(y * ppm.w + round(bbox.x1)) * 3 + 1] = 0;
        ppm.buffer[(y * ppm.w + round(bbox.x1)) * 3 + 2] = 0;
        // Bbox right border
        ppm.buffer[(y * ppm.w + round(bbox.x2)) * 3] = 255;
        ppm.buffer[(y * ppm.w + round(bbox.x2)) * 3 + 1] = 0;
        ppm.buffer[(y * ppm.w + round(bbox.x2)) * 3 + 2] = 0;
    }
    outfile.write(reinterpret_cast<char*>(ppm.buffer), ppm.w * ppm.h * 3);
}

void caffeToTRTModel(const std::string& deployFile,           // Name for caffe prototxt
                     const std::string& modelFile,            // Name for model
                     const std::vector<std::string>& outputs, // Network outputs
                     unsigned int maxBatchSize,               // Batch size - NB must be at least as large as the batch we want to run with)
                     IHostMemory** trtModelStream)            // Output stream for the TensorRT model
{
    // Create the builder
    IBuilder* builder = createInferBuilder(gLogger.getTRTLogger());
    assert(builder != nullptr);

    // Parse the caffe model to populate the network, then set the outputs
    INetworkDefinition* network = builder->createNetwork();
    ICaffeParser* parser = createCaffeParser();

    gLogInfo << "Begin parsing model..." << std::endl;
    const IBlobNameToTensor* blobNameToTensor = parser->parse(locateFile(deployFile).c_str(),
                                                              locateFile(modelFile).c_str(),
                                                              *network,
                                                              //DataType::kFLOAT);
                                                              DataType::kHALF);
    gLogInfo << "End parsing model..." << std::endl;
    // Specify which tensors are outputs
    for (auto& s : outputs)
        network->markOutput(*blobNameToTensor->find(s.c_str()));

    // Build the engine
    builder->setMaxBatchSize(maxBatchSize);
    builder->setMaxWorkspaceSize(1 << 30); // We need about 6MB of scratch space for the plugin layer for batch size 5

    builder->setFp16Mode(1);
    builder->setInt8Mode(0);
    builder->allowGPUFallback(true);

    samplesCommon::enableDLA(builder, gArgs.useDLACore);

    gLogInfo << "Begin building engine..." << std::endl;
    ICudaEngine* engine = builder->buildCudaEngine(*network);
    assert(engine);
    gLogInfo << "End building engine..." << std::endl;

    // We don't need the network any more, and we can destroy the parser
    network->destroy();
    parser->destroy();

    // Serialize the engine, then close everything down
    (*trtModelStream) = engine->serialize();

    engine->destroy();
    builder->destroy();
    shutdownProtobufLibrary();
}

void doInference(IExecutionContext& context, float* inputData, float* inputImInfo, std::vector<float>& outputBboxPred, std::vector<float>& outputClsProb, std::vector<float>& outputRois, int batchSize)
{
    const ICudaEngine& engine = context.getEngine();
    // Input and output buffer pointers that we pass to the engine - the engine requires exactly IEngine::getNbBindings(),
    // of these, but in this case we know that there is exactly 2 inputs and 3 outputs.
    assert(engine.getNbBindings() == 5);
    void* buffers[5];

    // In order to bind the buffers, we need to know the names of the input and output tensors.
    // note that indices are guaranteed to be less than IEngine::getNbBindings()
    int inputIndex0 = engine.getBindingIndex(INPUT_BLOB_NAME0),
        inputIndex1 = engine.getBindingIndex(INPUT_BLOB_NAME1),
        outputIndex0 = engine.getBindingIndex(OUTPUT_BLOB_NAME0),
        outputIndex1 = engine.getBindingIndex(OUTPUT_BLOB_NAME1),
        outputIndex2 = engine.getBindingIndex(OUTPUT_BLOB_NAME2);
    const int dataSize = batchSize * INPUT_C * INPUT_H * INPUT_W;
    const int imInfoSize = batchSize * IM_INFO_SIZE;
    const int bboxPredSize = batchSize * NMS_MAX_OUT * OUTPUT_BBOX_SIZE;
    const int clsProbSize = batchSize * NMS_MAX_OUT * OUTPUT_CLS_SIZE;
    const int roisSize = batchSize * NMS_MAX_OUT * 4;
    // Create GPU buffers and a stream
    CHECK(cudaMalloc(&buffers[inputIndex0], dataSize * sizeof(float)));      // data
    CHECK(cudaMalloc(&buffers[inputIndex1], imInfoSize * sizeof(float)));    // im_info
    CHECK(cudaMalloc(&buffers[outputIndex0], bboxPredSize * sizeof(float))); // bbox_pred
    CHECK(cudaMalloc(&buffers[outputIndex1], clsProbSize * sizeof(float)));  // cls_prob
    CHECK(cudaMalloc(&buffers[outputIndex2], roisSize * sizeof(float)));     // rois

    cudaStream_t stream;
    CHECK(cudaStreamCreate(&stream));

    // DMA the input to the GPU,  execute the batch asynchronously, and DMA it back:
    CHECK(cudaMemcpyAsync(buffers[inputIndex0], inputData, dataSize * sizeof(float), cudaMemcpyHostToDevice, stream));
    CHECK(cudaMemcpyAsync(buffers[inputIndex1], inputImInfo, imInfoSize * sizeof(float), cudaMemcpyHostToDevice, stream));
    context.enqueue(batchSize, buffers, stream, nullptr);
    CHECK(cudaMemcpyAsync(outputBboxPred.data(), buffers[outputIndex0], bboxPredSize * sizeof(float), cudaMemcpyDeviceToHost, stream));
    CHECK(cudaMemcpyAsync(outputClsProb.data(), buffers[outputIndex1], clsProbSize * sizeof(float), cudaMemcpyDeviceToHost, stream));
    CHECK(cudaMemcpyAsync(outputRois.data(), buffers[outputIndex2], roisSize * sizeof(float), cudaMemcpyDeviceToHost, stream));
    cudaStreamSynchronize(stream);

    // Release the stream and the buffers
    cudaStreamDestroy(stream);
    CHECK(cudaFree(buffers[inputIndex0]));
    CHECK(cudaFree(buffers[inputIndex1]));
    CHECK(cudaFree(buffers[outputIndex0]));
    CHECK(cudaFree(buffers[outputIndex1]));
    CHECK(cudaFree(buffers[outputIndex2]));
}

void bboxTransformInvAndClip(std::vector<float>& rois, std::vector<float>& deltas, std::vector<float>& predBBoxes, float* imInfo,
                             const int N, const int nmsMaxOut, const int numCls)
{
    for (int i = 0; i < N * nmsMaxOut; ++i)
    {
        float width = rois[i * 4 + 2] - rois[i * 4] + 1;
        float height = rois[i * 4 + 3] - rois[i * 4 + 1] + 1;
        float ctr_x = rois[i * 4] + 0.5f * width;
        float ctr_y = rois[i * 4 + 1] + 0.5f * height;
        float* imInfo_offset = imInfo + i / nmsMaxOut * 3;
        for (int j = 0; j < numCls; ++j)
        {
            float dx = deltas[i * numCls * 4 + j * 4];
            float dy = deltas[i * numCls * 4 + j * 4 + 1];
            float dw = deltas[i * numCls * 4 + j * 4 + 2];
            float dh = deltas[i * numCls * 4 + j * 4 + 3];
            float pred_ctr_x = dx * width + ctr_x;
            float pred_ctr_y = dy * height + ctr_y;
            float pred_w = exp(dw) * width;
            float pred_h = exp(dh) * height;
            predBBoxes[i * numCls * 4 + j * 4] = std::max(std::min(pred_ctr_x - 0.5f * pred_w, imInfo_offset[1] - 1.f), 0.f);
            predBBoxes[i * numCls * 4 + j * 4 + 1] = std::max(std::min(pred_ctr_y - 0.5f * pred_h, imInfo_offset[0] - 1.f), 0.f);
            predBBoxes[i * numCls * 4 + j * 4 + 2] = std::max(std::min(pred_ctr_x + 0.5f * pred_w, imInfo_offset[1] - 1.f), 0.f);
            predBBoxes[i * numCls * 4 + j * 4 + 3] = std::max(std::min(pred_ctr_y + 0.5f * pred_h, imInfo_offset[0] - 1.f), 0.f);
        }
    }
}

std::vector<int> nms(std::vector<std::pair<float, int>>& score_index, float* bbox, const int classNum, const int numClasses, const float nms_threshold)
{
    auto overlap1D = [](float x1min, float x1max, float x2min, float x2max) -> float {
        if (x1min > x2min)
        {
            std::swap(x1min, x2min);
            std::swap(x1max, x2max);
        }
        return x1max < x2min ? 0 : std::min(x1max, x2max) - x2min;
    };
    auto computeIoU = [&overlap1D](float* bbox1, float* bbox2) -> float {
        float overlapX = overlap1D(bbox1[0], bbox1[2], bbox2[0], bbox2[2]);
        float overlapY = overlap1D(bbox1[1], bbox1[3], bbox2[1], bbox2[3]);
        float area1 = (bbox1[2] - bbox1[0]) * (bbox1[3] - bbox1[1]);
        float area2 = (bbox2[2] - bbox2[0]) * (bbox2[3] - bbox2[1]);
        float overlap2D = overlapX * overlapY;
        float u = area1 + area2 - overlap2D;
        return u == 0 ? 0 : overlap2D / u;
    };

    std::vector<int> indices;
    for (auto i : score_index)
    {
        const int idx = i.second;
        bool keep = true;
        for (unsigned k = 0; k < indices.size(); ++k)
        {
            if (keep)
            {
                const int kept_idx = indices[k];
                float overlap = computeIoU(&bbox[(idx * numClasses + classNum) * 4],
                                           &bbox[(kept_idx * numClasses + classNum) * 4]);
                keep = overlap <= nms_threshold;
            }
            else
                break;
        }
        if (keep)
            indices.push_back(idx);
    }
    return indices;
}

void printHelp(const char* name)
{
    std::cout << "Usage: " << name << "\n"
        << "Optional Parameters:\n"
        << "  -h, --help        Display help information.\n"
        << "  image_file        Specify the image file(s) separated by blanks or Camera for camera input.\n";
}

void writeBuffer(void* buffer, size_t size, std::string const& path)
{
	std::ofstream stream(path.c_str(), ios::binary);

    if (stream)
        stream.write(static_cast<char*>(buffer), size);
}

// Returns empty string iff can't read the file
std::string readBuffer(std::string const& path)
{
    string buffer;
    std::ifstream stream(path.c_str(), ios::binary);

    if (stream)
    {
        stream >> noskipws;
        copy(istream_iterator<char>(stream), istream_iterator<char>(), back_inserter(buffer));
    }

    return buffer;
}

// call with blank space separated file names within locateFile list of folders above
int main(int argc, char** argv)
{
    bool argsOK = samplesCommon::parseArgs(gArgs, argc, argv);
    if (gArgs.help || !argsOK)
    {
        printHelp(argv[0]);
        return argsOK ? EXIT_SUCCESS : EXIT_FAILURE;
    }

    auto sampleTest = gLogger.defineTest(gSampleName, argc, const_cast<const char**>(argv));

    gLogger.reportTestStart(sampleTest);

    IHostMemory* trtModelStream{nullptr};
    initLibNvInferPlugins(&gLogger.getTRTLogger(), "");

    std::string engineName = std::string("frcnn_HALF_") + std::to_string(N) + ".buf";
    bool b = std::ifstream(engineName).good();

    IRuntime* runtime = createInferRuntime(gLogger.getTRTLogger());
	assert(runtime != nullptr);

	ICudaEngine* engine = nullptr;
    if (!b)
    {
		// Create a TensorRT model from the caffe model and serialize it to a stream
		// This value needs to be changed as per model and weights file
		caffeToTRTModel("faster_rcnn_test_iplugin.prototxt",
						"VGG16_faster_rcnn_final.caffemodel",
						std::vector<std::string>{OUTPUT_BLOB_NAME0, OUTPUT_BLOB_NAME1, OUTPUT_BLOB_NAME2},
						N, &trtModelStream);
		assert(trtModelStream != nullptr);

		writeBuffer(trtModelStream->data(), trtModelStream->size(), engineName);

		gLogInfo << "*** deserializing" << std::endl;
		// Deserialize the engine
		if (gArgs.useDLACore >= 0)
		{
			runtime->setDLACore(gArgs.useDLACore);
		}
		engine = runtime->deserializeCudaEngine(trtModelStream->data(), trtModelStream->size(), nullptr);

	    trtModelStream->destroy();
    }
    else
    {
		gLogInfo << "*** deserializing" << std::endl;
		// Deserialize the engine
		std::string buffer = readBuffer(engineName);
        engine = runtime->deserializeCudaEngine(buffer.data(), buffer.size(), nullptr);
    }
    assert(engine != nullptr);

    IExecutionContext* context = engine->createExecutionContext();
    assert(context != nullptr);


    // Available default images
    std::vector<std::string> imageList = {"000456.ppm", "000542.ppm", "001150.ppm", "001763.ppm", "004545.ppm"};
    for (int i = 1; i < argc && i <= N; i++)
    	imageList[i - 1] = argv[i];

    // std::cout << cv::getBuildInformation() << std::endl;

    cv::VideoCapture cap;
    if (imageList[0] == "Camera") {
		cap.open("nvarguscamerasrc ! nvvidconv ! video/x-raw, format=BGRx ! videoconvert ! video/x-raw, format=BGR ! appsink");
		if (!cap.isOpened()) {
			printf("ERROR Cannot open camera");
			cap.release();
			return 0;
		}
		double buff = cap.get(cv::CAP_PROP_BUFFERSIZE);
		double fps = cap.get(cv::CAP_PROP_FPS);
		// bool b = cap.set(cv::CAP_PROP_BUFFERSIZE, 0);
		// printf("buffer %f fps %f\n", buff, fps);
    }

    //std::vector<PPM> ppms(N);
	std::vector<cv::Mat> ppms(N);

    float imInfo[N * 3]; // Input im_info
    assert(ppms.size() <= imageList.size());

    float* data = new float[N * INPUT_C * INPUT_H * INPUT_W];
    // Pixel mean used by the Faster R-CNN's author
    const float pixelMean[3]{102.9801f, 115.9465f, 122.7717f}; // Also in BGR order

    const int sizes[] = {INPUT_H, INPUT_W};
    const int volImg = INPUT_C * INPUT_H * INPUT_W;
    const int volChl = INPUT_H * INPUT_W;

LOOP:
    struct timespec start, end;
    clock_gettime(CLOCK_MONOTONIC, &start);

    for (int i = 0; i < N; ++i)
    {
    	// read and resize image, store original size in ppm
        if (imageList[i] == "Camera") {
        	// flush buffered images since set CV_CAP_PROP_BUFFERSIZE 0 may not work
        	// this should be on its own thread
        	for (int f = 0; f < 5; f++)
        	{
				struct timespec start, end;
				clock_gettime(CLOCK_MONOTONIC, &start);
				// double frame = cap.get(cv::CAP_PROP_POS_FRAMES);
				// double frames = cap.get(cv::CAP_PROP_FRAME_COUNT);
				bool b = cap.grab();
			    clock_gettime(CLOCK_MONOTONIC, &end);
			    double time_taken = (((end.tv_sec - start.tv_sec) * 1e9) + (end.tv_nsec - start.tv_nsec)) * 1e-9;
				// printf("%f %f %f\n", frame, frames, time_taken);

			    if (time_taken > 0.00416)
			    	break;
         	}
			bool b = cap.retrieve(ppms[i]);

			if (ppms[i].empty()) {
				printf("ERROR Blank frame grabbed\n");
				cap.release();
				return 0;
			}
        }
        else
        	ppms[i] = cv::imread(locateFile(imageList[i]));

        cv::Mat src;
        cv::resize(ppms[i], src, cv::Size(INPUT_W, INPUT_H));

        cv::Mat dst;
        cv::subtract(src, cv::Scalar(102.9801f, 115.9465f, 122.7717f), dst, cv::noArray(), CV_32F);

        cv::Mat bgr[3] = {cv::Mat(2, sizes, CV_32F, (void*)(data + i * volImg + 0 * volChl)),
        				  cv::Mat(2, sizes, CV_32F, (void*)(data + i * volImg + 1 * volChl)),
        				  cv::Mat(2, sizes, CV_32F, (void*)(data + i * volImg + 2 * volChl))};
        cv::split(dst, bgr);

        imInfo[i * 3] = float(INPUT_H);     // Number of rows
        imInfo[i * 3 + 1] = float(INPUT_W); // Number of columns
        imInfo[i * 3 + 2] = 1;              // Image scale
    }

    double time_taken;
    clock_gettime(CLOCK_MONOTONIC, &end);
    time_taken = (end.tv_sec - start.tv_sec) * 1e9;
    time_taken = (time_taken + (end.tv_nsec - start.tv_nsec)) * 1e-9;
    printf("doLoading %f\n", time_taken);


    std::vector<float> rois;
    std::vector<float> bboxPreds;
    std::vector<float> clsProbs;
    std::vector<float> predBBoxes;

    // Host memory for outputs
    rois.assign(N * NMS_MAX_OUT * 4, 0);
    bboxPreds.assign(N * NMS_MAX_OUT * OUTPUT_BBOX_SIZE, 0);
    clsProbs.assign(N * NMS_MAX_OUT * OUTPUT_BBOX_SIZE, 0);

    // Predicted bounding boxes
    predBBoxes.assign(N * NMS_MAX_OUT * OUTPUT_BBOX_SIZE, 0);

    ////////////////////////////
    clock_gettime(CLOCK_MONOTONIC, &start);

    // Run inference
    doInference(*context, data, imInfo, bboxPreds, clsProbs, rois, N);

    // end = clock(); 
    // double time_taken = double(end - start) / double(CLOCKS_PER_SEC);
    clock_gettime(CLOCK_MONOTONIC, &end);
    time_taken = (end.tv_sec - start.tv_sec) * 1e9; 
    time_taken = (time_taken + (end.tv_nsec - start.tv_nsec)) * 1e-9; 
    printf("doInference %f\n", time_taken);


    // Unscale back to raw image space
    for (int i = 0; i < N; ++i)
    {
        for (int j = 0; j < NMS_MAX_OUT * 4 && imInfo[i * 3 + 2] != 1; ++j)
            rois[i * NMS_MAX_OUT * 4 + j] /= imInfo[i * 3 + 2];
    }

    bboxTransformInvAndClip(rois, bboxPreds, predBBoxes, imInfo, N, NMS_MAX_OUT, OUTPUT_CLS_SIZE);

    // scale bboxes relative to original image size
    int ii = 0;
    for (int i = 0; i < N; i++)
	{
    	for (int r = 0; r < NMS_MAX_OUT; r++)
		{
			for (int j = 0; j < OUTPUT_CLS_SIZE; ++j)
			{
				predBBoxes[ii * OUTPUT_CLS_SIZE * 4 + j * 4]     *= (float)ppms[i].cols / (float)INPUT_W;
				predBBoxes[ii * OUTPUT_CLS_SIZE * 4 + j * 4 + 1] *= (float)ppms[i].rows / (float)INPUT_H;
				predBBoxes[ii * OUTPUT_CLS_SIZE * 4 + j * 4 + 2] *= (float)ppms[i].cols / (float)INPUT_W;
				predBBoxes[ii * OUTPUT_CLS_SIZE * 4 + j * 4 + 3] *= (float)ppms[i].rows / (float)INPUT_H;
			}
			ii++;
		}
	}


    // The sample passes if there is at least one detection for each item in the batch
    bool pass = true;

    for (int i = 0; i < N; ++i)
    {
        float* bbox = predBBoxes.data() + i * NMS_MAX_OUT * OUTPUT_BBOX_SIZE;
        float* scores = clsProbs.data() + i * NMS_MAX_OUT * OUTPUT_CLS_SIZE;
        int numDetections = 0;
        for (int c = 1; c < OUTPUT_CLS_SIZE; ++c) // Skip the background
        {
            std::vector<std::pair<float, int>> score_index;
            for (int r = 0; r < NMS_MAX_OUT; ++r)
            {
                if (scores[r * OUTPUT_CLS_SIZE + c] > score_threshold)
                {
                    score_index.push_back(std::make_pair(scores[r * OUTPUT_CLS_SIZE + c], r));
                    std::stable_sort(score_index.begin(), score_index.end(),
                                     [](const std::pair<float, int>& pair1,
                                        const std::pair<float, int>& pair2) {
                                         return pair1.first > pair2.first;
                                     });
                }
            }

            // Apply NMS algorithm
            std::vector<int> indices = nms(score_index, bbox, c, OUTPUT_CLS_SIZE, nms_threshold);

            numDetections += static_cast<int>(indices.size());

            // Show results
            for (unsigned k = 0; k < indices.size(); ++k)
            {
                int idx = indices[k];
                std::string storeName = std::to_string(i) + "-" + CLASSES[c] + "-" + std::to_string(scores[idx * OUTPUT_CLS_SIZE + c]) + ".png";
                gLogInfo << "Detected " << CLASSES[c] << " in " << imageList[i] << " with confidence " << scores[idx * OUTPUT_CLS_SIZE + c] * 100.0f << "% "
                         << " (Result stored in " << storeName << ")." << std::endl;

                BBox b{bbox[idx * OUTPUT_BBOX_SIZE + c * 4], bbox[idx * OUTPUT_BBOX_SIZE + c * 4 + 1], bbox[idx * OUTPUT_BBOX_SIZE + c * 4 + 2], bbox[idx * OUTPUT_BBOX_SIZE + c * 4 + 3]};
                // writePPMFileWithBBox(storeName, ppms[i], b);
                // Comment this out for speed if not debugging
                cv::rectangle(ppms[i], cv::Point(b.x1, b.y1), cv::Point(b.x2, b.y2), cv::Scalar(255, 0, 0), 1, 4);
                cv::imwrite(storeName, ppms[i]);
            }
        }
        // Comment this out for speed if not debugging
        cv::imshow("Camera", ppms[i]);

        pass &= numDetections >= 1;
    }

    if (cap.isOpened())
    {
		char key = (char)cv::waitKey(1);
		if (key != 'q' && key != 'Q' && key != 27)
			goto LOOP;
	}

    delete[] data;

    // Destroy the engine
    context->destroy();
    engine->destroy();
    runtime->destroy();

    if (cap.isOpened())
    	cap.release();

    return gLogger.reportTest(sampleTest, pass);
}
