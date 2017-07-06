#!/bin/bash
maxjobs=30

subdir=/Volumes/Serena/MMRescan/MR_Proc/


 for fib in $(ls  $subdir/{1,0}*/dsi_ap/*fib*); do 
   [[ ! -e "${fib%fib.gz}fib.gz.nii.gz" ]] && (dsi_studio --action=exp --source=${fib} --export=fa0,fa1,iso,gfa)&
   
   while [ $( jobs -p | wc -l ) -ge $maxjobs ]
   do
   sleep 20s
   done
 done
