#!/bin/bash
export CUDA_VISIBLE_DEVICES=0,1,2,3


ls $HOME/Deeplabv3/tensorflow-models/research/deeplab/datasets/pascal_voc_seg/exp/train_on_trainval_set/train/
rm $HOME/Deeplabv3/tensorflow-models/research/deeplab/datasets/pascal_voc_seg/exp/train_on_trainval_set/train/*
echo "-------------------REMOVED----------------"
ls $HOME/Deeplabv3/tensorflow-models/research/deeplab/datasets/pascal_voc_seg/exp/train_on_trainval_set/train/
ddlrun -t --accelerators 4 -m b ./deeplab_lmsv2.sh  
