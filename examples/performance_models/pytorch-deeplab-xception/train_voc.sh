arch=$1
res=$2
batch_size=$3
lms=$4
num_gpu=$5
alternate=$6
max_iter=$7
lms_limit=$8
lms_limit=${lms_limit:-0}

#Compute the batch size
#batch_size=$(( $num_gpu * $batch_size ))
epochs=$(( $batch_size* $max_iter * num_gpu  ))
#epochs=$(( $epochs/1464))
#echo "BATCH_SIZE="$batch_size

#To account for the current number of epochs in the 4GPU case
epochs=$(python -c "from math import ceil;print(ceil($epochs/1464) + 2)")
inBytes=$(python -c "from math import floor;print(floor(${lms_limit}*1024*1024*1024))")

echo "LMS limit in BYTES="$inBytes" GB="${lms_limit}
lms_limit=$inBytes
echo "LMS limit in BYTES="${lms_limit}

echo "EPOCHS="$epochs


GPU_DEVICE_CMDLINE="CUDA_VISIBLE_DEVICES="
GPU_IDS="--gpu-ids="

if [ "$num_gpu" = "1" ];then
   GPU_DEVICE_CMDLINE+="0 "
   GPU_IDS+="0 "
   if [ "$arch" = "p9" ]
   then
     NUM_ACTL_CMDLINE=" numactl --cpunodebind=0 --membind=0 "
   else
     NUM_ACTL_CMDLINE=""
   fi
fi

if [ "$num_gpu" = "2" ];then
   if [ "$alternate" = "yes" ]; then
   	GPU_DEVICE_CMDLINE+="0,2 "
   	GPU_IDS+="0,1 "
   else
   	GPU_DEVICE_CMDLINE+="0,1 "
   	GPU_IDS+="0,1 "
   fi
fi

if [ "$num_gpu" = "4" ];then
   if [ "$alternate" = "yes" ]; then
   	GPU_DEVICE_CMDLINE+="0,3,4,7 "
   	GPU_IDS+="0,1,2,3 "
   else
   	GPU_DEVICE_CMDLINE+="0,1,2,3 "
   	GPU_IDS+="0,1,2,3 "
   fi
fi

if [ "$num_gpu" = "8" ];then
   	GPU_DEVICE_CMDLINE+="0,1,2,3,4,5,6,7 "
   	GPU_IDS+="0,1,2,3,4,5,6,7 "
fi

#echo $GPU_DEVICE_CMDLINE
#echo $GPU_IDS

if [ "$lms" = "lms" ];then
	LMS_CMDLINE=" --lms "
else
	LMS_CMDLINE=" "
fi

CMD=$GPU_DEVICE_CMDLINE
CMD+=$NUM_ACTL_CMDLINE
CMD+="python train.py --backbone xception --lr 0.007 --workers 40 --checkname deeplab-xception --eval-interval 1 --dataset pascal --no-val "
CMD+=$GPU_IDS
CMD+=" --crop-size "${res}
CMD+=" --base-size "${res}
CMD+=" --batch-size "${batch_size}
CMD+=${LMS_CMDLINE}
CMD+=" --epochs "$epochs
CMD+=" --max-iterations "$max_iter
CMD+=" --set-limit-lms "$lms_limit

# Pass in direct arguments to training script
CMD+=" ${@:9}"
echo $CMD
eval $CMD

#CUDA_VISIBLE_DEVICES=0 python train.py --backbone xception --lr 0.007 --workers 4  --epochs 10 --gpu-ids 0 --checkname deeplab-xception --eval-interval 1 --dataset pascal --crop-size $res --base-size $res --batch-size $batch_size --no-val --lms
