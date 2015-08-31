#!/bin/sh

#--------------------------------------------------------------------
#
#  CMon_DE.sh (FKA:  CheckCmon.sh)
#
#  This is the top level data extractionscript for the Conventional 
#  Data Monitor (Cmon) package.  
#
#  The default is to run this with a suffix value (data source) of copr
#  meaning the Conventional data from the operational GDAS.  The value
#  of SUFFIX can be overriden in your envionment or calling script if 
#  this is to be run as a cron.
#
#  Similarly DATDIR and GDATDIR point to the operational data (GDAS). 
#  They can be overriden either in your interactive shell or in a 
#  script in order to point to another source.
#--------------------------------------------------------------------
set -ax

#--------------------------------------------------------------------
#  usage
#--------------------------------------------------------------------
function usage {
  echo "Usage:  CMon_DE.sh suffix run_envir [pdate]"
  echo "            Suffix is the indentifier for this data source."
  echo "            run_envir is either 'dev' or 'para'."
  echo "            Pdate is the full YYYYMMDDHH cycle to run.  This 
		    param is optional"
}

#--------------------------------------------------------------------
#  CMon_DE.sh begins here
#--------------------------------------------------------------------

nargs=$#
if [[ $nargs -lt 2 || $nargs -gt 3 ]]; then
   usage
   exit 1
fi

echo "Begin CMon_DE.sh"

this_file=`basename $0`
this_dir=`dirname $0`


export CMON_SUFFIX=$1

#--------------------------------------------------------------------
#  RUN_ENVIR:  can be either "dev" or "para".
#--------------------------------------------------------------------
export RUN_ENVIR=$2		

if [[ $nargs -ge 2 ]]; then
   export PDATE=$3;
   echo "PDATE set to $PDATE"
fi

echo CMON_SUFFIX = $CMON_SUFFIX
echo RUN_ENVIR = $RUN_ENVIR

top_parm=${this_dir}/../../parm

cmon_version_file=${cmon_version:-${top_parm}/CMon.ver}
if [[ -s ${cmon_version_file} ]]; then
   . ${cmon_version_file}
   echo "able to source ${cmon_version_file}"
else
   echo "Unable to source ${cmon_version_file} file"
   exit 2
fi

cmon_config=${cmon_config:-${top_parm}/CMon_config}
if [[ -s ${cmon_config} ]]; then
   . ${cmon_config}
   echo "able to source ${cmon_config}"
else
   echo "Unable to source ${cmon_config} file"
   exit 3
fi


#minmon_user_settings=${minmon_user_settings:-${top_parm}/MinMon_user_settings}
#if [[ -s ${minmon_user_settings} ]]; then
#   . ${minmon_user_settings}
#   echo "able to source ${minmon_user_settings}"
#else
#   echo "Unable to source ${minmon_user_settings} file"
#   exit 4
#fi




#--------------------------------------------------------------------
# Create any missing directories

if [[ ! -d ${TANKDIR} ]]; then
   mkdir -p ${TANKDIR}
fi
if [[ ! -d ${LOGDIR} ]]; then
   mkdir -p ${LOGDIR}
fi
if [[ ! -d ${IMGNDIR} ]]; then
   mkdir -p ${IMGNDIR}
fi

tmpdir=${STMP}/check_conv${SUFFIX}
rm -rf $tmpdir
mkdir -p $tmpdir
cd $tmpdir

#--------------------------------------------------------------------
# Check status of monitoring job.  Is it already running?  If so, exit
# this script and wait for job to finish.

count=`bjobs -u ${LOGNAME} -p -r -J "cmon_*_${SUFFIX}" | wc -l`
if [[ $count -ne 0 ]] ; then
   echo "Previous cmon jobs are still running for ${SUFFIX}" 
   exit
fi

#--------------------------------------------------------------------
# Get date of cycle to process.
#
GDATE=`${SCRIPTS}/find_cycle.pl 1 ${TANKDIR}`
PDATE=`$NDATE +06 $GDATE`

sdate=`echo $PDATE|cut -c1-8`
export CYA=`echo $PDATE|cut -c9-10`

export GCYA=`echo $GDATE|cut -c9-10`
export gydat=`echo $GDATE|cut -c1-8`

export DATDIR=${DATDIR:-/com/gfs/prod/gdas.$sdate}
export GDATDIR=${GDATDIR:-/com/gfs/prod/gdas.$gydat}


#--------------------------------------------------------------------
# If data is available, export variables, and submit driver for
# plot jobs.
#
# Modification here is for prhw14 and prhs13 parallels which only
# generate grib2 files for the analysis and forecast files.  The 
# operational GDAS creates grib and grib2 files.  The Cmon package
# was originally designed to use grib files, but it's clear that
# grib2 will be the only standard with the next major release of 
# GSI. 

if [[ $SUFFIX = "prhw14" || $SUFFIX = "prhs13" ]]; then
   export cnvstat=${DATDIR}/cnvstat.gdas.${PDATE}
   export pgrbanl=${DATDIR}/pgrbanl.gdas.${PDATE}.grib2
   export pgrbf06=${DATDIR}/pgrbf006.gdas.${GDATE}.grib2
else
   export cnvstat="${DATDIR}/gdas1.t${CYA}z.cnvstat"
   export pgrbanl="${DATDIR}/gdas1.t${CYA}z.pgrbanl"
   export pgrbf06="${GDATDIR}/gdas1.t${GCYA}z.pgrbf06"
fi


if [ -s $cnvstat  -a -s $pgrbanl ]; then
   if [ -s $pgrbf06 ]; then
      /bin/sh $SCRIPTS/convcopr.sh
   else
      echo data not available, missing $pgrbf06 file
   fi
else
   echo data not available -- missing $cnvstat and/or $pgrbanl files
fi


#--------------------------------------------------------------------
# Clean up and exit
cd $tmpdir
cd ../
rm -rf $tmpdir

echo "End CheckCmon.sh"
exit
