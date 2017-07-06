#!/bin/bash

datadir=/Volumes/Serena/MMRescan/MR_Proc/
mkdir $datadir/undistort_DB

 for subdir in $(ls -d $datadir/{0,1}*); do 
   subid=$(basename $subdir|cut -d _ -f1)
   cp $subdir/dsi_ap/dsi_ap_undistorted.src*fib.gz $datadir/undistort_DB/${subid}.fib.gz
 done
