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
      HERE=`dirname $0`                                                 # Script directoey
      DIR="/home/autogen/teradata-migration-etl"                        # Project home directory
    YMLTMP=${HERE}"/tmp/dagopsymltmp$$.yml"                             # A temporary YAML file
    SQLTMP=${HERE}"/tmp/dagopssqltmp$$.sql"                             # A temporary SQL file
        TS="date "+%Y-%m-%d-%H-%M-%S""                                  # TS
        TS="date "+%Y-%m-%d_%H:%M:%S""                                  # TS
       TSM="date "+%s%6N""                                              # TS micro
  JOB_NAME="UNKNOWN"                                                    # A default job name
SYNC_SLEEP=2                                                            # Eventually consistency sleep
  STOP_NOW=${HERE}"/stop_now"                                           # If this file exists, we exit rigth now
       SEP="|"                                                          # Column separator for the logs

#
# Options
#
while getopts "s:r:f:t:j:c:d:p:w:Vh" OPT; do
        case ${OPT} in
        s)           SQL="${OPTARG}"                                    ;;
        r)        RUN_ID="${OPTARG}"                                    ;;
        f)       TS_FROM="${OPTARG}"                                    ;;
        t)         TS_TO="${OPTARG}"                                    ;;
        d)           DIR="${OPTARG}"                                    ;;
        p)      PARALLEL="${OPTARG}"                                    ;;      # Just for the logs
        j)      JOB_NAME="${OPTARG}"                                    ;;
        c)    SYNC_SLEEP="${OPTARG}"                                    ;;
        w)           DIR="${OPTARG}"                                    ;;
        V)      show_version; exit 567                                  ;;
        h)         usage                                                ;;
        \?)        echo "Invalid option: -$OPTARG" >&2; usage           ;;
        esac
done
#
# Build some pathes
#
  SQL_PATH=${DIR}"/bigquery"                                            # Where the SQL files are
  VAR_FILE=${DIR}"/environments/etl/bmas-edl-uat-7398.yml"              # Variables YAML file
  SQL_FILE=${SQL_PATH}"/"${SQL}                                         # Whole SQL file path
#
# echo for the logs in the same format
#
show_log()
{
        echo $($TS)${SEP}$($TSM)${SEP}${JOB_NAME}${SEP}${RUN_ID}${SEP}${PARALLEL}${SEP}${TS_FROM}${SEP}${TS_TO}${SEP}$@
}
#
# Option verification
#
if [[ ! -f ${SQL_FILE} ]]
then
        show_log "Error${SEP}Cannot find the SQL file $SQL_FILE; cannot continue.${SEP}$?"
        exit 1
fi
for i in RUN_ID TS_FROM TS_TO
do
        if [[ -z ${!i} ]]
        then
                show_log "Error${SEP}${i} cannot be null; cannot continue.${SEP}123"
                exit 147
        fi
        if [[ ! "${!i}" =~ ^[0-9]+$ ]]
        then
                show_log "Error${SEP}${i} has to be an integer; cannot continue.${SEP}123"
                exit 148
        fi
done
if [[ -f ${STOP_NOW} ]]                 # stop_now detected, we exit right away
then
        show_log "Error${SEP}${STOP_NOW} detected, exiting${SEP}666"
        exit 666
fi
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
show_log "Starting${SEP}${SQL}${SEP}0"
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
        show_log "Generated${SEP}${SQLTMP}${SEP}${RET}"
else
        show_log "Error${SEP}when executing j2 ${SQL_FILE} ${YMLTMP} > ${SQLTMP}${SEP}$RET"
        exit 149
fi
#
# We can now execute the SQLFILE where we have replaced the variables in
#
# Set env
#
gcloud config configurations activate dagops
RET=$?
if [ $RET -ne 0 ]
then
        show_log "Error${SEP}Impossible to set google env, cannot continue${SEP}${RET}"
        exit 765
fi
#
# Execute the query
#
show_log "Executing${SEP}${SQLTMP}${SEP}0"
cat ${SQLTMP} |  bq --location=EU query --use_legacy_sql=false
RETURN_CODE=$?
show_log "Executed${SEP}${SQL}${SEP}${RETURN_CODE}"
show_log "Sleeping${SEP}${SQL}${SEP}${SYNC_SLEEP}"
sleep ${SYNC_SLEEP}
#
# Reset env
#
gcloud config configurations activate default
RET=$?
if [ $RET -ne 0 ]
then
        show_log "Error${SEP}Impossible to reset google env to default, cannot continue${SEP}${RET}"
        exit 766
fi
#
# For the logs
#
show_log "Done${SEP}${SQL}${SEP}${RETURN_CODE}"
#
# Delete tempfiles
#
for X in ${SQLTMP} ${YMLTMP}
do
        if [[ -f ${X} ]]
        then
                rm -f ${X}
        fi
done

exit ${RETURN_CODE}

#************************************************************************#
#*                      E N D      O F      S O U R C E                 *#
#************************************************************************#
