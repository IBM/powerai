# vision-tensorrt-samples

### Common Assumptions

* The repository contains samples based on Nvidia's TensorRT c/c++ samples modified for ease of use. Target platforms are Power with GPUs and Nvidia Jetsons both native Linux or within docker containers.

- Inputs can be arbitrary image files in terms of extension and resolution passed in as command line arguments
- Outputs are list of classes and bboxes per image and debug images with bbox marked
- Model can be arbitrary as long as it matches the model type (SSD, FRCNN for now, Yolo and Googlenet soon to follow) and that <model_name>_trt.prototxt and <model_name>.caffemodel are present and names adjusted in source code
- Batch size can be arbitrary as long as it fits the device memory, adjustable in source code
- Floating point precision can be arbitrary which affects the accuracy, speed and memory footprint, adjustable in source code
- Number and names of classes can be arbitrary based on model, also adjustable in source code. The names could be read from label file but due to variations in syntax, left out for now
- Number of classes is always one more than the label file since there is one background class.
- Confidence level can be adjusted which determines the number of object recognized

### Common Use

* The samples first have to be compiled from source and ran from bin directory with command line parameters
- It is assumed that cuda, cudnn, tensorrt, gcc, opencv are preinstalled and environment variables set (see below).
- Copy the samples and make files over the respective TensorRT sample directories
- Modify the code to match desired model, batch size, floating point precision, image folder, names of classes
- Compile the source code via make from respective samples directory
- Run the binary (release or debug) from the bin folder and pass in the file names as "name.ext" "name.ext" without the folder path.
- On initial run, if TensorRT engine for the model has not been run before, it will take a little while to parse and serialize it to file
- On subsequent runs if no changes were made to the model or engine parameters, the engine will be deserialized from an earlier saved one

### Common Prerequisites

* Following are prerequisite steps to have the correct native or docker environment both for Power and Jetson, build and runtime

- If building on Power within docker best is to start with nvidia/cuda-ppc64le:10.1-cudnn7-devel-ubuntu18.04 docker and add latest TensorRT SDK (currently 5.1.3.2, cuda 10.1, cudnn 7.5, for Power)
- Install or build opencv version 3.3.1 and above
- If building on Jetson TX2 native, follow the steps described in Nvidia Jetpack installation. This requires an Ubuntu host machine to initially flash the board via Jetpack Manager (currently 4.2.2). All the prerequisites, if checked, during installation are preinstalled and ready for use.
-  Note that Host Machine needs to be unchecked and TensorFlow can be unchecked and Jetson TX2 checked.

- Please follow the rest of the prerequisite instructions from the Nvidia samples README.md


