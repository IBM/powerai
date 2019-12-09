export TF_CUDA_HOST_MEM_LIMIT_IN_MB=500000

export TF_LMS_SIMULATOR_MEM_RATIO=1.0

export PYTHONPATH=$PYTHONPATH:`pwd`:`pwd`/slim
cd ..
clones=1
res=2100
batch_size=1
iter=4000
lms=true
swapout_threshold=1
swapin_ahead=1
swapin_groupby=0
sync_mode=0



echo "##############################################"

echo "##############################################"

echo "# Cuda_Host_Limit $TF_CUDA_HOST_MEM_LIMIT_IN_MB"
echo "# TF_Lms_Simulator_Mem_Ratio $TF_LMS_SIMULATOR_MEM_RATIO"
echo "# Use numactl ${use_numactl} "

echo "# Running clones     ${clones}"
echo "# Running resolution ${res}"
echo "# Running batchsize  ${batch_size}"
echo "# Running iterations ${iter}"
echo "# Running lms        ${lms}"

if [ $lms = "true" ]
then
echo "# lmsv2 knob swapout_threshold     ${swapout_threshold}"
echo "# lmsv2 knob swapin_ahead          ${swapin_ahead}"
echo "# lmsv2 knob swapin_groupby        ${swapin_groupby}"
echo "# lmsv2 knob sync_mode             ${sync_mode}"
fi

echo "##############################################"

echo "##############################################"

echo "###############AFTER###########################"
ls $HOME/Deeplabv3/tensorflow-models/research/deeplab/datasets/pascal_voc_seg/exp/train_on_trainval_set/train/

python $HOME/Deeplabv3/tensorflow-models/research/deeplab/train.py --logtostderr --train_split=trainval --model_variant=xception_65 --atrous_rates=6 --atrous_rates=12 --atrous_rates=18 --output_stride=16 --decoder_output_stride=4 --train_batch_size=$batch_size --training_number_of_steps=$iter --fine_tune_batch_norm=true --tf_initial_checkpoint=$HOME/Deeplabv3/tensorflow-models/research/deeplab/datasets/pascal_voc_seg/init_models/deeplabv3_pascal_train_aug/model.ckpt --train_logdir=$HOME/Deeplabv3/tensorflow-models/research/deeplab/datasets/pascal_voc_seg/exp/train_on_trainval_set/train --dataset_dir=$HOME/Deeplabv3/tensorflow-models/research/deeplab/datasets/pascal_voc_seg/tfrecord --train_crop_size=$res --train_crop_size=$res --use_tflms=$lms --num_clones=$clones --swapout_threshold=$swapout_threshold --swapin_ahead=$swapin_ahead --swapin_groupby=$swapin_groupby --sync_mode=$sync_mode --disable_layout_optimizer=true
