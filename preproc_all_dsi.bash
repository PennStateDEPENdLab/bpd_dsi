#!/bin/bash
#set -e
source /gpfs/group/mnh5174/default/lab_resources/ni_path.bash
module load dsi #DSI studio

rawdir=$G/MMRescan/MR_Raw
procdir=$G/MMRescan/MR_Proc

source preproc_helper_functions

function proc_one_subject {
    subjdir="${1}"
    sid="$(basename $s)"
    sprocdir="${procdir}/${sid}"
    logfile="${sprocdir}/dsipreproc.log"

    #setup total readout time for TOPUP
    #total readout time in seconds: (EPI factor - 1) * echo spacing * .001. This is on the SIEMENS scan sheet. It will not change within a given protocol.
    if [ ! -f "${procdir}/acqparams.txt" ]; then
	echo -e "0 -1 0 0.09779\n0 1 0 0.09779" > "${procdir}/acqparams.txt" #phase negative first
    fi
    
    [ ! -d "${sprocdir}" ] && mkdir "${sprocdir}"
    rel "\n-------\nProcessing subject: $s\n-------\n\n" $logfile c
    copy_raw "$sid" "$subjdir" "dsi_ap" "diff_113_AP*" "sbref" 7458 $logfile
    copy_raw "$sid" "$subjdir" "dsi_ap_sbref" "diff_113_AP*_SBRef*" "" 66 $logfile
    copy_raw "$sid" "$subjdir" "b0_pa" "diff_b0_PA*" "sbref" 66 $logfile
    copy_raw "$sid" "$subjdir" "mprage" "SAG-MPRAGE*" "" 208 $logfile
    
    #convert auxiliary files to NIfTI
    if [ ! -f "${sprocdir}/mprage/.dcm2nii_complete" ]; then
	cd $sprocdir/mprage
	rel "dcm2niix -f mprage . && rm -f MR*" $logfile
	date > .dcm2nii_complete
    fi

    if [ ! -f "${sprocdir}/mprage/.mprage_complete" ]; then
	#minimal processing of mprage
	rel "fslreorient2std mprage mprage"
	rel "robustfov -i mprage -r mprage_clipfov"
	rel "3dSkullStrip -input mprage_clipfov.nii.gz -prefix mprage_brain.nii.gz"
	date .mprage_complete
    fi

    if [ ! -f "${sprocdir}/b0_pa/.dcm2nii_complete" ]; then
	cd $sprocdir/b0_pa
	rel "dcm2niix -f b0_pa . && rm -f MR*" $logfile
	rel "fslroi b0_pa b0_pa_vol1 0 1" $logfile
	date > .dcm2nii_complete
    fi

    if [ ! -f "${sprocdir}/dsi_ap_sbref/.dcm2nii_complete" ]; then
	cd $sprocdir/dsi_ap_sbref
	rel "dcm2niix -f dsi_ap_sbref . && rm -f MR*" $logfile
	date > .dcm2nii_complete
    fi

    #handle DSI proper
    cd $sprocdir/dsi_ap
    if [ ! -f .dcmrename_complete ]; then	
	flist=$( find $PWD -iname "MR*" -type f )
	#for f in $flist; do mv $f ${f}.dcm; done
	#rel "for f in MR*; do mv $f $f.dcm; done"

	rel "Comparing reconstruction of DICOMs and b tables from dcm2niix and dsi_studio" $logfile c

	#DSI Studio conversion to src.gz blows up with poorly sorted DICOMs (as in this case)
	#Re-sort and rename in acquisition order
	rel "Dimon -infile_prefix MR -dicom_org -save_file_list sorted.files -quit" $logfile
	linenum=0
	while read file; do
	    linenum=$(( $linenum + 1 ))
	    mv "${file}" "dsi${linenum}.dcm"
	done < sorted.files
	rm -f sorted.files

	date > .dcmrename_complete
    fi
    
    #this pipeline gives preference to the DSI-Studio DICOM conversion, rather than dcm2niix. This was chosen
    #because of the tendency of dcm2niix to complain about no b0 (saves a b-value of 5 for the first image).
    if [ ! -f .dcm2src_complete ]; then
	rel "dsi_studio --action=src --source=./ --output=dsi_ap.src.gz" $logfile o || ( rel "DSI Studio recon from DICOM failed" $logfile c )
	rel "dsi_studio --action=exp --source=dsi_ap.src.gz --export=4dnii" $logfile o || ( rel "DSI Studio export to NIfTI failed" $logfile c )
	rel "mv dsi_ap.src.gz.nii.gz dsi_ap.nii.gz" $logfile
	rel "mv dsi_ap.src.gz.bval dsi_ap.bval" $logfile
	rel "mv dsi_ap.src.gz.bvec dsi_ap.bvec" $logfile
	rel "mv dsi_ap.src.gz.b_table.txt dsi_ap.b_table.txt" $logfile
	date > .dcm2src_complete
    fi

    if [ ! -f .dcm2src_dcm2niix_complete ]; then
	rel "dcm2niix -f dsi_ap_dcm2niix ." $logfile
	rel "rm -f *.dcm" $logfile

	#extract multiple b0 volumes for motion diagnostics
	#> x <- unlist(read.table("dsi_ap_dcm2niix.bval"))
	#> which(x==5)
	#V1  V11  V21  V31  V41  V51  V61  V71  V81  V91 V101 V111
	#1   11   21   31   41   51   61   71   81   91  101  111
	rel "3dTcat -prefix b0_series.nii.gz dsi_ap_dcm2niix.nii.gz'[0,10,20,30,40,50,60,70,80,90,100,110]'" $logfile
	rel "fsl_motion_outliers -i b0_series.nii.gz -o fd.mat -s fd.txt --fd --thresh=1" $logfile
	
	rel "dsi_studio --action=src --source=dsi_ap_dcm2niix.nii.gz --bval=dsi_ap_dcm2niix.bval --bvec=dsi_ap_dcm2niix.bvec --output=dsi_ap_dcm2niix.src.gz" $logfile o || ( rel "DSI studio src.gz from dcm2niix failed: $PWD" $logfile c )
	rel "mkdir dcm2niix" $logfile
	rel "mv dsi_ap_dcm2niix* dcm2niix" $logfile #for comparison of raw reconstruction
	date > .dcm2src_dcm2niix_complete
    fi

    if [ ! -f .topup_complete ]; then
	#run TOPUP
	rel "fslroi dsi_ap b0_ap_vol1 0 1" $logfile
	rel "fslmerge -t both_b0 b0_ap_vol1 ../b0_pa/b0_pa_vol1" $logfile #a>>p comes first
	rel "topup --imain=both_b0 --datain=${procdir}/acqparams.txt --config=b02b0.cnf --out=dsi_ap_topup" $logfile
	rel "applytopup --imain=dsi_ap --inindex=1 --datain=${procdir}/acqparams.txt --topup=dsi_ap_topup --out=dsi_ap_undistorted --method=jac" $logfile
	rel "fslroi dsi_ap_undistorted undistorted_b0 0 1" $logfile
	rel "bet undistorted_b0 undistorted_b0_brain -f 0.2 -R -v -n -m" $logfile
	rel "fslmaths undistorted_b0_brain_mask -fillh undistorted_b0_brain_mask -odt char" $logfile #make sure the mask is contiguous (may also want to -dilF/eroF if ugly)
	date > .topup_complete
    fi

    if [ ! -f .dsi_recon_complete ]; then
	rel "dsi_studio --action=src --source=dsi_ap_undistorted.nii.gz --bval=dsi_ap.bval --bvec=dsi_ap.bvec --output=dsi_ap_undistorted.src.gz" $logfile o || ( rel "conversion to src.gz from TOPUP failed $PWD" $logfile c )

	#reg_method 1 is SPM 14-18-14 for normalization to template (higher order than 7-9-7)
	#method 7 is qsdr
	#param1 is 2mm voxel output (acquisition is 1.8mm, but templates appear to be in 2mm space)
	#thread = 4 uses 4 process threads for reconstruction
	#for the time being, warping the mprage is not working (seg fault regularly)
	#   --other_image=t1w,../mprage/mprage_brain.nii.gz
	rel "dsi_studio --action=rec --thread=1 --source=dsi_ap_undistorted.src.gz --method=7 --param0=1.25
	    		--output_jac=1 --output_map=1 --mask=undistorted_b0_brain_mask.nii.gz --param1=2
		        --reg_method=1 --record_odf=1 --check_btable=1" $logfile o ||
	    ( rel "QSDR reconstruction failed in $PWD" $logfile c )

	#reconstruct from raw dcm2niix output
	cd dcm2niix #dsi_studio grumpy about relative paths
	rel "dsi_studio --action=rec --thread=1 --source=dsi_ap_dcm2niix.src.gz --method=7 --param0=1.25
	    		--output_jac=1 --output_map=1 --param1=2
		        --reg_method=1 --record_odf=1 --check_btable=1" $logfile o ||
	    ( rel "QSDR from dcm2niix reconstruction failed in $PWD" $logfile c )
	cd ..

	#reconstruct from raw dsi_studio output (no TOPUP, mask, or T1)
	rel "dsi_studio --action=rec --thread=1 --source=dsi_ap.src.gz --method=7 --param0=1.25
	    		--output_jac=1 --output_map=1 --param1=2
		        --reg_method=1 --record_odf=1 --check_btable=1" $logfile o ||
	    ( rel "QSDR reconstruction from distorted failed in $PWD" $logfile c )
	
	date > .dsi_recon_complete
    fi
    rel "\n-------\nEnd processing subject: $s\n-------\n\n" $logfile c
    return 0
}

njobs=40
subdirs=$( find $rawdir -mindepth 1 -maxdepth 1 -type d )
pids=""
for s in $subdirs; do
    #wait here until number of jobs is <= 16
    while [ $( jobs -p | wc -l ) -ge 40 ]
    do
	sleep 20
    done

    proc_one_subject "$s" &
    pids="$pids $!"
done

wait $pids
