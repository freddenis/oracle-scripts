#!/bin/bash
# Fred Denis -- Oct 29th 2019 -- ERS-143
#
# Receive:
# -- SQL file
# -- pipeline_cdc_start_ts_micros
# -- to pipeline_cdc_end_ts_micros
# -- run_id pipeline_etl_run_id
# Guess itself:
# -- pipeline_job_start_ts_micros
# -- stage_stage_start_ts_seconds
# -- stage_stage_start_ts_micros
#
# Then replace the variables in the SQL files from $VAR_FILE and execute the query against bigquery
#

SQL_PATH="/home/autogen/teradata-migration-etl/bigquery"                # Where the SQL files are
VAR_FILE="/home/autogen/dagops/bmas-edl-uat-7398.yml"                   # The YAML parameter file with the variables values
  YMLTMP="/tmp/dagopsymltmp$$.yml"                                      # A temporary YAML file
  SQLTMP="/tmp/dagopssqltmp$$.sql"                                      # A temporary SQL file
      TS="date "+%Y-%m-%d-%H-%M-%S""                                    # TS
     TSM="date "+%s%6N""                                                # TS micro
JOB_NAME="UNKNOWN"                                                      # A default job name

#
# Options
#
while getopts "s:r:f:t:j:Vh" OPT; do
        case ${OPT} in
        s)      SQL_FILE=${SQL_PATH}"/""${OPTARG}"                      ;;
        r)        RUN_ID="${OPTARG}"                                    ;;
        f)       TS_FROM="${OPTARG}"                                    ;;
        t)         TS_TO="${OPTARG}"                                    ;;
        j)      JOB_NAME="${OPTARG}"                                    ;;
        V)      show_version; exit 567                                  ;;
        h)         usage                                                ;;
        \?)        echo "Invalid option: -$OPTARG" >&2; usage           ;;
        esac
done
#
# Option verification
#
if [[ ! -f ${SQL_FILE} ]]
then
        echo $($TS) $($TSM) ${JOB_NAME} "Cannot find the SQL file $SQL_FILE; cannot continue."
        exit 1
fi
for i in RUN_ID TS_FROM TS_TO
do
        if [[ -z ${!i} ]]
        then
                echo $($TS) $($TSM) ${JOB_NAME} "${i} cannot be null; cannot continue."
                exit 147
        fi
        if [[ ! "${!i}" =~ ^[0-9]+$ ]]
        then
                echo $($TS) $($TSM) ${JOB_NAME} "${i} has to be an integer; cannot continue."
                exit 148
        fi
done
#
# We need few more timestamps
#
pipeline_job_start_ts_micros=$(date "+%s%6N")
       stage_start_ts_micros=$(date "+%s%6N")
      stage_start_ts_seconds=$(($stage_start_ts_micros/1000000))
#
#for i in pipeline_job_start_ts_micros stage_start_ts_micros stage_start_ts_seconds
#do
#       echo $i ${!i}
#done
#
# For the logs
#
echo $($TS) $($TSM) ${JOB_NAME} Starting with ${SQL_FILE}
#
# We add our variables to the template YAML file which has the other variables values
#
cp $VAR_FILE $YMLTMP
cat << ! >> $YMLTMP

pipeline:
  etl_run_id: ${RUN_ID}
  cdc_start_ts_micros: ${TS_FROM}
  cdc_end_ts_micros: ${TS_TO}
  job_start_ts_micros: ${pipeline_job_start_ts_micros}

stage:
  stage_start_ts_seconds: ${stage_start_ts_seconds}
  stage_start_ts_micros: ${stage_start_ts_micros}
!
#
# We use j2cli to replace the variables from the YAML file into the SQL file
#
j2 ${SQL_FILE} ${YMLTMP} > ${SQLTMP}
RET=$?
if [ $RET -eq 0 ]
then
        echo $($TS) $($TSM) ${JOB_NAME} ${SQLTMP} has been generated successfully
else
        echo $($TS) $($TSM) ${JOB_NAME} "Error "$RET" when executing j2 "${SQL_FILE} ${YMLTMP} ">"${SQLTMP}"; cannot continue"
        exit 149
fi
#
# We can now execute the SQLFILE where we have replaced the variables in
#
# Set env
#
gcloud config configurations activate dagops
if [ $? -ne 0 ]
then
        echo $($TS) $($TSM) ${JOB_NAME} "Impossible to set google env, cannot continue"
        exit 765
fi
#
# Execute the query
#
echo $($TS) $($TSM) ${JOB_NAME} ${SQLTMP} "Executing . . . " ${SQL_FILE}
cat ${SQLTMP} |  bq --location=EU query --use_legacy_sql=false
#
# Reset env
#
gcloud config configurations activate default
if [ $? -ne 0 ]
then
        echo $($TS) $($TSM) ${JOB_NAME} "Impossible to reset google env to default, cannot continue"
        exit 766
fi
#
# For the logs
#
echo $($TS) $($TSM) ${JOB_NAME} Done with ${SQL_FILE}
#
# Delete tempfiles
#
for X in ${SQLTMP}  ${YMLTMP}
do
        if [[ -f ${X} ]]
        then
                rm -f ${X}
        fi
done

#************************************************************************#
#*                      E N D      O F      S O U R C E                 *#
#************************************************************************#
