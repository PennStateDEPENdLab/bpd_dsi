#!/bin/bash
maxjobs=30

roi=/Volumes/Phillips/larsen/MMrescan_Michael/rois/amy_unc_tracking.nii.gz
datadir=/Volumes/Serena/MMRescan/MR_Proc/

outfile=/Volumes/Phillips/larsen/MMrescan_Michael/analyses/$(basename ${roi%.nii.gz}_qa0.csv)
echo -n > $outfile

 for subdir in $(ls -d $datadir/{0,1}*); do 
   subid=$(basename $subdir|cut -d _ -f1)
   qa0img=$subdir/dsi_ap/*undistorted*fib*fa0.nii.gz
   qaMean=$(3dROIstats -mask $roi -quiet $qa0img)
   echo $qaMean
   echo "${subid},${qaMean}" >>$outfile
 done
