#!/bin/bash
datadir=/Volumes/Serena/MMRescan/MR_Proc/

outfile=/Volumes/Phillips/larsen/MMrescan_Michael/analyses/motion.csv
echo -n > $outfile

 for subdir in $(ls -d $datadir/{0,1}*); do 
   subid=$(basename $subdir|cut -d _ -f1)
   thisMean=$(sed 1d ${subdir}/dsi_ap/fd.txt | Rio -ne 'mean(df$V1)')
   echo "${subid},${thisMean}" >>$outfile
 done
