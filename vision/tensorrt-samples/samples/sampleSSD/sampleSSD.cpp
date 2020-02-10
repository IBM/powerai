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

#include <cassert>
#include <cmath>
#include <cstring>
#include <cuda_runtime_api.h>
#include <unordered_map>

#include "BatchStream.h"
#include "NvCaffeParser.h"
#include "NvInferPlugin.h"
#include "logger.h"
#include "common.h"
#include "argsParser.h"

#include <opencv2/imgcodecs.hpp>
#include <opencv2/videoio.hpp>
#include <opencv2/highgui.hpp>
#include <opencv2/imgproc/imgproc.hpp>

using namespace nvinfer1;
using namespace nvcaffeparser1;
using namespace plugin;
using std::vector;

const std::string gSampleName = "TensorRT.sample_ssd";
static samplesCommon::Args gArgs;

// Network details
const char* gNetworkName = "ssd";       // Network name
static const int kINPUT_C = 3;          // Input image channels
static const int kINPUT_H = 512;        // This value needs to be changed as per prototxt dim
static const int kINPUT_W = 512;        // This value needs to be changed as per prototxt dim
static const int kOUTPUT_CLS_SIZE = 3;  // This value needs to be changed as per number of classes
static const int kKEEP_TOPK = 200;      // Number of total bboxes to be kept per image after NMS step. It is same as detection_output_param.keep_top_k in prototxt file

// Batch size
static const int N = 1;// This value needs to be changed as number of images per inference, 1 for camera

// Visualization
static const float kVISUAL_THRESHOLD = 0.8f; // This value needs to be changed per confidence threshold

enum MODE
{
    kFP32,
    kFP16,
    kINT8,
    kUNKNOWN
};

struct Param
{
    MODE modelType{MODE::kFP32}; // Default run FP32 precision
} params;

std::ostream& operator<<(std::ostream& o, MODE dt)
{
    switch (dt)
    {
    case kFP32: o << "FP32"; break;
    case kFP16: o << "FP16"; break;
    case kINT8: o << "INT8"; break;
    case kUNKNOWN: o << "UNKNOWN"; break;
    }
    return o;
}

// This value needs to be changed as per model and images folder
static const std::vector<std::string> kDIRECTORIES{"data/samples/ssd/", "data/ssd/", "data/int8_samples/ssd/", "int8/ssd/"};

// This value needs to be changed as per number and names of classes
const std::string gCLASSES[kOUTPUT_CLS_SIZE]{"background", "1", "2"};//, "3", "4", "5", "6", "7", "8", "9", "10", "11", "12", "13", "14", "15", "16", "17", "18", "19", "20"}; // List of class labels

static const char* kINPUT_BLOB_NAME = "data";            // Input blob name
static const char* kOUTPUT_BLOB_NAME0 = "detection_out"; // Output blob name
static const char* kOUTPUT_BLOB_NAME1 = "keep_count";    // Output blob name

// not used
// INT8 calibration variables
static const int kCAL_BATCH_SIZE = 1;   // Batch size
static const int kFIRST_CAL_BATCH = 0;  // First batch
static const int kNB_CAL_BATCHES = 100; // Number of batches

#define CalibrationMode 1 //Set to '0' for Legacy calibrator and any other value for Entropy calibrator 2

class Int8LegacyCalibrator : public nvinfer1::IInt8LegacyCalibrator
{
public:
    Int8LegacyCalibrator(BatchStream& stream, int firstBatch, double cutoff, double quantile, const char* networkName, bool readCache = true)
        : mStream(stream)
        , mFirstBatch(firstBatch)
        , mReadCache(readCache)
        , mNetworkName(networkName)
    {
        nvinfer1::Dims dims = mStream.getDims();
        mInputCount = mStream.getBatchSize() * dims.d[1] * dims.d[2] * dims.d[3];
        CHECK(cudaMalloc(&mDeviceInput, mInputCount * sizeof(float)));
        reset(cutoff, quantile);
    }

    virtual ~Int8LegacyCalibrator()
    {
        CHECK(cudaFree(mDeviceInput));
    }

    int getBatchSize() const override { return mStream.getBatchSize(); }
    double getQuantile() const override { return mQuantile; }
    double getRegressionCutoff() const override { return mCutoff; }

    bool getBatch(void* bindings[], const char* names[], int nbBindings) override
    {
        if (!mStream.next())
            return false;

        CHECK(cudaMemcpy(mDeviceInput, mStream.getBatch(), mInputCount * sizeof(float), cudaMemcpyHostToDevice));
        bindings[0] = mDeviceInput;
        return true;
    }

    const void* readCalibrationCache(size_t& length) override
    {
        mCalibrationCache.clear();
        std::ifstream input(calibrationTableName(), std::ios::binary);
        input >> std::noskipws;

        if (mReadCache && input.good())
        {
            std::copy(std::istream_iterator<char>(input), std::istream_iterator<char>(), std::back_inserter(mCalibrationCache));
        }

        length = mCalibrationCache.size();
        return length ? &mCalibrationCache[0] : nullptr;
    }

    void writeCalibrationCache(const void* cache, size_t length) override
    {
        std::ofstream output(calibrationTableName(), std::ios::binary);
        output.write(reinterpret_cast<const char*>(cache), length);
    }

    const void* readHistogramCache(size_t& length) override
    {
        length = mHistogramCache.size();
        return length ? &mHistogramCache[0] : nullptr;
    }

    void writeHistogramCache(const void* cache, size_t length) override
    {
        mHistogramCache.clear();
        std::copy_n(reinterpret_cast<const char*>(cache), length, std::back_inserter(mHistogramCache));
    }

    void reset(double cutoff, double quantile)
    {
        mCutoff = cutoff;
        mQuantile = quantile;
        mStream.reset(mFirstBatch);
    }

private:
    std::string calibrationTableName()
    {
        assert(mNetworkName != nullptr);
        return std::string("CalibrationTable") + mNetworkName;
    }
    BatchStream mStream;
    int mFirstBatch;
    double mCutoff, mQuantile;
    bool mReadCache{true};
    const char* mNetworkName;
    size_t mInputCount;
    void* mDeviceInput{nullptr};
    std::vector<char> mCalibrationCache, mHistogramCache;
};

class Int8EntropyCalibrator2 : public IInt8EntropyCalibrator2
{
public:
    Int8EntropyCalibrator2(BatchStream& stream, int firstBatch, bool readCache = true)
        : mStream(stream)
        , mReadCache(readCache)
    {
        nvinfer1::Dims dims = mStream.getDims();
        mInputCount = mStream.getBatchSize() * dims.d[1] * dims.d[2] * dims.d[3];
        CHECK(cudaMalloc(&mDeviceInput, mInputCount * sizeof(float)));
        mStream.reset(firstBatch);
    }

    virtual ~Int8EntropyCalibrator2()
    {
        CHECK(cudaFree(mDeviceInput));
    }

    int getBatchSize() const override { return mStream.getBatchSize(); }

    bool getBatch(void* bindings[], const char* names[], int nbBindings) override
    {
        if (!mStream.next())
        {
            return false;
        }
        CHECK(cudaMemcpy(mDeviceInput, mStream.getBatch(), mInputCount * sizeof(float), cudaMemcpyHostToDevice));
        assert(!strcmp(names[0], kINPUT_BLOB_NAME));
        bindings[0] = mDeviceInput;
        return true;
    }

    const void* readCalibrationCache(size_t& length) override
    {
        mCalibrationCache.clear();
        std::ifstream input(calibrationTableName(), std::ios::binary);
        input >> std::noskipws;
        if (mReadCache && input.good())
        {
            std::copy(std::istream_iterator<char>(input), std::istream_iterator<char>(), std::back_inserter(mCalibrationCache));
        }
        length = mCalibrationCache.size();
        return length ? &mCalibrationCache[0] : nullptr;
    }

    virtual void writeCalibrationCache(const void* cache, size_t length) override
    {
        std::ofstream output(calibrationTableName(), std::ios::binary);
        output.write(reinterpret_cast<const char*>(cache), length);
    }

private:
    static std::string calibrationTableName()
    {
        assert(gNetworkName);
        return std::string("CalibrationTable") + gNetworkName;
    }
    BatchStream mStream;
    size_t mInputCount;
    bool mReadCache{true};
    void* mDeviceInput{nullptr};
    std::vector<char> mCalibrationCache;
};

std::string locateFile(const std::string& input)
{
    return locateFile(input, kDIRECTORIES);
}

void caffeToTRTModel(const std::string& deployFile,           // Name for caffe prototxt
                     const std::string& modelFile,            // Name for model
                     const std::vector<std::string>& outputs, // Network outputs
                     unsigned int maxBatchSize,               // Batch size - NB must be at least as large as the batch we want to run with)
                     MODE mode,                               // Precision mode
                     IHostMemory** trtModelStream)            // Output stream for the TensorRT model
{
    // Create the builder
    IBuilder* builder = createInferBuilder(gLogger.getTRTLogger());
    assert(builder != nullptr);

    // Parse the caffe model to populate the network, then set the outputs
    INetworkDefinition* network = builder->createNetwork();
    ICaffeParser* parser = createCaffeParser();
    DataType dataType = DataType::kFLOAT;
    if (mode == kFP16)
        dataType = DataType::kHALF;
    gLogInfo << "Begin parsing model..." << std::endl;
    gLogInfo << mode << " mode running..." << std::endl;

    const IBlobNameToTensor* blobNameToTensor = parser->parse(locateFile(deployFile).c_str(),
                                                              locateFile(modelFile).c_str(),
                                                              *network,
                                                              dataType);
    gLogInfo << "End parsing model..." << std::endl;

    // Specify which tensors are outputs
    for (auto& s : outputs)
        network->markOutput(*blobNameToTensor->find(s.c_str()));

    // Build the engine
    builder->setMaxBatchSize(maxBatchSize);
    builder->setMaxWorkspaceSize(36 << 20);
    //builder->setFp16Mode(gArgs.runInFp16);
    builder->setFp16Mode(true);
    //builder->setInt8Mode(gArgs.runInInt8);
    builder->setInt8Mode(false);
    builder->allowGPUFallback(true);
    samplesCommon::enableDLA(builder, gArgs.useDLACore);
    //samplesCommon::enableDLA(-1);

    // Calibrator life time needs to last until after the engine is built.
    std::unique_ptr<IInt8Calibrator> calibrator;

    ICudaEngine* engine;
    /*if (mode == kINT8)
    {
#if CalibrationMode == 0
        assert(args.useDLACore != -1 && "Legacy calibration mode not supported with DLA.");
        gLogInfo << "Using Legacy Calibrator" << std::endl;
        BatchStream calibrationStream(kCAL_BATCH_SIZE, kNB_CAL_BATCHES, "./batches/batch_calibration", kDIRECTORIES);
        calibrator.reset(new Int8LegacyCalibrator(calibrationStream, 0, kCUTOFF, kQUANTILE, gNetworkName, true));
#else
        gLogInfo << "Using Entropy Calibrator 2" << std::endl;
        BatchStream calibrationStream(kCAL_BATCH_SIZE, kNB_CAL_BATCHES, "./batches/batch_calibration", kDIRECTORIES);
        calibrator.reset(new Int8EntropyCalibrator2(calibrationStream, kFIRST_CAL_BATCH));
#endif
        builder->setInt8Mode(true);
        builder->setInt8Calibrator(calibrator.get());
    }
    else
    {
        builder->setFp16Mode(mode == kFP16);
    }*/
    gLogInfo << "Begin building engine..." << std::endl;
    engine = builder->buildCudaEngine(*network);
    assert(engine);
    gLogInfo << "End building engine..." << std::endl;

    // Once the engine is built. Its safe to destroy the calibrator.
    calibrator.reset();

    // We don't need the network any more, and we can destroy the parser
    network->destroy();
    parser->destroy();

    // Serialize the engine, then close everything down
    (*trtModelStream) = engine->serialize();

    engine->destroy();
    builder->destroy();
}

void doInference(IExecutionContext& context, float* inputData, float* detectionOut, int* keepCount, int batchSize)
{
    const ICudaEngine& engine = context.getEngine();
    // input and output buffer pointers that we pass to the engine - the engine requires exactly IEngine::getNbBindings(),
    // of these, but in this case we know that there is exactly 1 input and 2 output.
    assert(engine.getNbBindings() == 3);
    void* buffers[3];

    // In order to bind the buffers, we need to know the names of the input and output tensors.
    // note that indices are guaranteed to be less than IEngine::getNbBindings()
    int inputIndex = engine.getBindingIndex(kINPUT_BLOB_NAME),
        outputIndex0 = engine.getBindingIndex(kOUTPUT_BLOB_NAME0),
        outputIndex1 = engine.getBindingIndex(kOUTPUT_BLOB_NAME1);

    // Create GPU buffers and a stream
    CHECK(cudaMalloc(&buffers[inputIndex], batchSize * kINPUT_C * kINPUT_H * kINPUT_W * sizeof(float))); // Data
    CHECK(cudaMalloc(&buffers[outputIndex0], batchSize * kKEEP_TOPK * 7 * sizeof(float)));               // Detection_out
    CHECK(cudaMalloc(&buffers[outputIndex1], batchSize * sizeof(int)));                                  // KeepCount (BBoxs left for each batch)

    cudaStream_t stream;
    CHECK(cudaStreamCreate(&stream));

    // DMA the input to the GPU,  execute the batch asynchronously, and DMA it back:
    CHECK(cudaMemcpyAsync(buffers[inputIndex], inputData, batchSize * kINPUT_C * kINPUT_H * kINPUT_W * sizeof(float), cudaMemcpyHostToDevice, stream));
    context.enqueue(batchSize, buffers, stream, nullptr);
    CHECK(cudaMemcpyAsync(detectionOut, buffers[outputIndex0], batchSize * kKEEP_TOPK * 7 * sizeof(float), cudaMemcpyDeviceToHost, stream));
    CHECK(cudaMemcpyAsync(keepCount, buffers[outputIndex1], batchSize * sizeof(int), cudaMemcpyDeviceToHost, stream));
    cudaStreamSynchronize(stream);

    // Release the stream and the buffers
    cudaStreamDestroy(stream);
    CHECK(cudaFree(buffers[inputIndex]));
    CHECK(cudaFree(buffers[outputIndex0]));
    CHECK(cudaFree(buffers[outputIndex1]));
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

int main(int argc, char** argv)
{
    bool argsOK = samplesCommon::parseArgs(gArgs, argc, argv);
    if (gArgs.help || !argsOK)
    {
        printHelp(argv[0]);
        return argsOK ? EXIT_SUCCESS : EXIT_FAILURE;
    }

    /*params.modelType = kFP32;
    if (gArgs.runInFp16)
    {
        params.modelType = kFP16;
    }
    else if (gArgs.runInInt8)
    {
        params.modelType = kINT8;
    }*/
    params.modelType = kFP16;


    auto sampleTest = gLogger.defineTest(gSampleName, argc, const_cast<const char**>(argv));

    gLogger.reportTestStart(sampleTest);

    initLibNvInferPlugins(&gLogger.getTRTLogger(), "");

    IHostMemory* trtModelStream{nullptr};
    // Create a TensorRT model from the caffe model and serialize it to a stream

    std::string engineName = std::string("ssd_trt_HALF_") + std::to_string(N) + ".buf";
    bool b = std::ifstream(engineName).good();

    IRuntime* runtime = createInferRuntime(gLogger.getTRTLogger());
	assert(runtime != nullptr);

	ICudaEngine* engine = nullptr;
    if (!b)
    {
    	// This value needs to be changed as per model and weights file
		caffeToTRTModel("ssd.prototxt",
						"VGG_VOC0712_SSD_300x300_iter_120000.caffemodel",
						std::vector<std::string>{kOUTPUT_BLOB_NAME0, kOUTPUT_BLOB_NAME1},
						N, params.modelType, &trtModelStream);
		assert(trtModelStream != nullptr);

		writeBuffer(trtModelStream->data(), trtModelStream->size(), engineName);

		gLogInfo << "*** deserializing" << std::endl;
		// Deserialize the engine
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

    // Host memory for outputs
    float* detectionOut = new float[N * kKEEP_TOPK * 7];
    int* keepCount = new int[N];


    std::vector<std::string> imageList = {"000456.ppm", "000542.ppm", "001150.ppm", "001763.ppm", "004545.ppm"}; // Input image list
    std::vector<cv::Mat> ppms(N);
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
    const float pixelMean[3]{104.0f, 117.0f, 123.0f}; // In BGR order
    // Host memory for input buffer
    float* data = new float[N * kINPUT_C * kINPUT_H * kINPUT_W];

    const int sizes[] = {kINPUT_H, kINPUT_W};
    const int volImg = kINPUT_C * kINPUT_H * kINPUT_W;
    const int volChl = kINPUT_H * kINPUT_W;

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
        cv::resize(ppms[i], src, cv::Size(kINPUT_W, kINPUT_H));

        cv::Mat dst;
        cv::subtract(src, cv::Scalar(104.0f, 117.0f, 123.0f), dst, cv::noArray(), CV_32F);

        cv::Mat bgr[3] = {cv::Mat(2, sizes, CV_32F, (void*)(data + i * volImg + 0 * volChl)),
        				  cv::Mat(2, sizes, CV_32F, (void*)(data + i * volImg + 1 * volChl)),
        				  cv::Mat(2, sizes, CV_32F, (void*)(data + i * volImg + 2 * volChl))};
        cv::split(dst, bgr);
    }

    double time_taken;
    clock_gettime(CLOCK_MONOTONIC, &end);
    time_taken = (end.tv_sec - start.tv_sec) * 1e9;
    time_taken = (time_taken + (end.tv_nsec - start.tv_nsec)) * 1e-9;
    printf("doLoading %f\n", time_taken);

    ////////////////////////////
    clock_gettime(CLOCK_MONOTONIC, &start);

    // Run inference
    doInference(*context, data, detectionOut, keepCount, N);

    clock_gettime(CLOCK_MONOTONIC, &end);
    time_taken = (end.tv_sec - start.tv_sec) * 1e9;
    time_taken = (time_taken + (end.tv_nsec - start.tv_nsec)) * 1e-9; 
    printf("doInference %f\n", time_taken);
    bool pass = true;

    for (int p = 0; p < N; ++p)
    {
        int numDetections = 0;
        // is there at least one correct detection?
        bool correctDetection = false;
        for (int i = 0; i < keepCount[p]; ++i)
        {
            float* det = detectionOut + (p * kKEEP_TOPK + i) * 7;
            if (det[2] < kVISUAL_THRESHOLD)
                continue;
            assert((int) det[1] < kOUTPUT_CLS_SIZE);
            std::string storeName = std::to_string(p) + "-" + gCLASSES[(int) det[1]] + "-" + std::to_string(det[2]) + ".png";

            numDetections++;
            if (gCLASSES[(int) det[1]] == "car")
                correctDetection = true;

            gLogInfo << " Image name:" << imageList[p].c_str() << ", Label: " << gCLASSES[(int) det[1]].c_str() << ","
                     << " confidence: " << det[2] * 100.f
                     << " xmin: " << det[3] * ppms[p].cols
                     << " ymin: " << det[4] * ppms[p].rows
                     << " xmax: " << det[5] * ppms[p].cols
                     << " ymax: " << det[6] * ppms[p].rows
                     << std::endl;

            // samplesCommon::writePPMFileWithBBox(storeName, ppms[p], {det[3] * kINPUT_W, det[4] * kINPUT_H, det[5] * kINPUT_W, det[6] * kINPUT_H});
            // Comment this out for speed if not debugging
            cv::rectangle(ppms[p], cv::Point(det[3] * ppms[p].cols, det[4] * ppms[p].rows), cv::Point(det[5] * ppms[p].cols, det[6] * ppms[p].rows), cv::Scalar(255, 0, 0), 1, 4);
            cv::imwrite(storeName, ppms[p]);
        }

        // Comment this out for speed if not debugging
        cv::imshow("Camera", ppms[p]);

        pass &= numDetections >= 1;
        pass &= correctDetection;
    }

    if (cap.isOpened())
    {
		char key = (char)cv::waitKey(1);
		if (key != 'q' && key != 'Q' && key != 27)
			goto LOOP;
	}

    // Destroy the engine
    context->destroy();
    engine->destroy();
    runtime->destroy();

    delete[] data;
    delete[] detectionOut;
    delete[] keepCount;

    // Note: Once you call shutdownProtobufLibrary, you cannot use the parsers anymore.
    shutdownProtobufLibrary();

    if (cap.isOpened())
    	cap.release();

    return gLogger.reportTest(sampleTest, pass);
}
