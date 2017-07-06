#!/usr/bin/env sh

#PBS -l nodes=1:ppn=40
#PBS -l walltime=84:00:00
#PBS -A mnh5174_a_g_hc_default
#PBS -j oe
#PBS -M michael.hallquist@psu.edu
#PBS -m abe
#PBS -W group_list=mnh5174_collab

#env
cd $PBS_O_WORKDIR

#NI setup
source /gpfs/group/mnh5174/default/lab_resources/ni_path.bash

#override lab-wide settings to prefer scripts in my home directory and use the right matlab batch script.
PATH="$HOME/fmri_processing_scripts:$HOME/fmri_processing_scripts/autopreproc:${PATH}"

export PATH

#set -e
#echo "DEPEND_SETUP: $DEPEND_SETUP"
#echo "python: $( which python )"

bash preproc_all_dsi.bash
