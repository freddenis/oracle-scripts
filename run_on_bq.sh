#!/bin/bash
# Fred Denis -- Oct 29th 2019 -- ERS-143
#
# Receive parameters from dagops.sh and run scripts on bq :
# -- SQL file
# -- pipeline_cdc_start_ts_micros
# -- to pipeline_cdc_end_ts_micros
# -- run_id pipeline_etl_run_id
# Guess itself:
# -- pipeline_job_start_ts_micros
# -- stage_stage_start_ts_seconds
# -- stage_stage_start_ts_micros
# Then replace the variables in the SQL files from $VAR_FILE and execute the query against bigquery
#
# The current script version is 20191105
#
# History:
#
# 20191105 - Fred Denis - Initial release
#
#
      HERE=`dirname $0`                                                 # Script directoey
      DIR="/home/autogen/teradata-migration-etl"                        # Project home directory
    YMLTMP=${HERE}"/tmp/dagopsymltmp$$.yml"                             # A temporary YAML file
    SQLTMP=${HERE}"/tmp/dagopssqltmp$$.sql"                             # A temporary SQL file
        TS="date "+%Y-%m-%d-%H-%M-%S""                                  # TS
        TS="date "+%Y-%m-%d_%H:%M:%S""                                  # TS
       TSM="date "+%s%6N""                                              # TS micro
  JOB_NAME="UNKNOWN"                                                    # A default job name
SYNC_SLEEP=1                                                            # Eventually consistency sleep
  STOP_NOW=${HERE}"/stop_now"                                           # If this file exists, we exit rigth now
       SEP="|"                                                          # Column separator for the logs
      INFO=""                                                           # If it is an info, we just show and insert the log in bq, we dont execute anything (-i)
 BQ_INSERT=${HERE}"/bq_insert.sh"                                       # Insert into bq
     MYSQL="mysql -Ns -u dagops"                                        # MYSQL command line to insert the logs
 BQ_OUTPUT=${HERE}"/tmp/bqoutput$RANDOM$$.tmp"                          # bq output
#
# Options
#
while getopts "s:r:f:t:j:c:m:u:d:p:w:i:Vh" OPT; do
        case ${OPT} in
        s)           SQL="${OPTARG}"                                    ;;
        r)        RUN_ID="${OPTARG}"                                    ;;
        f)       TS_FROM="${OPTARG}"                                    ;;
        t)         TS_TO="${OPTARG}"                                    ;;
        d)           DIR="${OPTARG}"                                    ;;
        i)          INFO="${OPTARG}"                                    ;;
        p)      PARALLEL="${OPTARG}"                                    ;;      # Just for the logs
        j)      JOB_NAME="${OPTARG}"                                    ;;
        m)        MASTER="${OPTARG}"                                    ;;
        u)          UNIQ="${OPTARG}"                                    ;;
        c)    SYNC_SLEEP="${OPTARG}"                                    ;;
        w)           DIR="${OPTARG}"                                    ;;
        V)      show_version; exit 567                                  ;;
        h)         usage                                                ;;
        \?)        echo "Invalid option: -$OPTARG" >&2; usage           ;;
        esac
done
shift $((OPTIND -1))
#
# Build some pathes
#
  SQL_PATH=${DIR}"/bigquery"                                            # Where the SQL files are
  VAR_FILE=${DIR}"/environments/etl/bmas-edl-uat-7398.yml"              # Variables YAML file
  SQL_FILE=${SQL_PATH}"/"${SQL}                                         # Whole SQL file path
INSERT_LOG=/tmp/bq_insert_log${UNIQ}                                    # Insert into bq logfile
cat /dev/null > ${INSERT_LOG}
#
# Get a file separated by "|" and load it into the MYSQL table dagops_logs
#
to_mysql()
{
        TMP4=${HERE}"/tmp/insertintomysql$RANDOM$$"                      # A tempfile
        cat /dev/null > ${TMP4}
        while read data;
        do
                if [[ "$data" =~ ^2 ]]
                then
                        data2=$(echo $data | sed s'/_/ /')
                        echo $data2 | tee -a ${logfile[1]}
                        echo $data2 >> ${TMP4}
                else
                        echo $data | tee -a ${logfile[1]}
                fi
        done

        ${MYSQL} << END_MYSQL
        load data local infile '${TMP4}' into table dagops_logs FIELDS TERMINATED BY '|' LINES TERMINATED BY '\n' ;
END_MYSQL

        if [[ -f ${TMP4} ]]
        then
                rm -f ${TMP4}
        fi
}
#
# echo for the logs in the same format
#
show_log()
{
        echo "$($TS)${SEP}$($TSM)${SEP}${UNIQ}${SEP}${MASTER}${SEP}${JOB_NAME}${SEP}${RUN_ID}${SEP}${PARALLEL}${SEP}${TS_FROM}${SEP}${TS_TO}${SEP}$@" | to_mysql
        # Insert into bq in nohup as inserting into bq is slow
#       #nohup ${BQ_INSERT} "$($TS)${SEP}$($TSM)${SEP}${UNIQ}${SEP}${MASTER}${SEP}${JOB_NAME}${SEP}${RUN_ID}${SEP}${PARALLEL}${SEP}${TS_FROM}${SEP}${TS_TO}${SEP}$@" >> ${INSERT_LOG} 2>&1 &
}
#
# Get a log and insert it into bq
#
function to_bq()
{
        TMP=${HERE}"/tmp/runonbqtemp$RANDOM"                            # A tempfile
        cat /dev/null > ${TMP}
        while read data;
        do
                if [[ "$data" =~ ^2 ]]
                then
                #       echo "good" $data
                        data2=$(echo $data | sed s'/_/ /')
                        echo $data2 >> ${TMP}
                fi
                echo $data                      # For the logfile
        done
        #
        # Load in bq
        #
        gcloud config configurations activate dagops
        #bq query --location=EU --use_legacy_sql=false --format=pretty 'select count(*) from ONETM_INGEST_COPY.dagops_logs'
        #wc -l ${TMP}
        bq load -F "|" ONETM_INGEST_COPY.dagops_logs ${TMP}
        #bq query --location=EU --use_legacy_sql=false --format=pretty 'select count(*) from ONETM_INGEST_COPY.dagops_logs'
        gcloud config configurations activate default
}
#
# Options verification
#
# We stop right away if $STOP_NOW is detected
#
if [[ -f ${STOP_NOW} ]]                 # stop_now detected, we exit right away
then
        show_log "Error${SEP}${STOP_NOW} detected, exiting${SEP}666"
        exit 666
fi
#
# If INFO, we show the log and exit
#
if [[ -n "${INFO}" ]]
then
        show_log "${INFO}${SEP}${SQL}${SEP}0"
        exit 0
fi
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
#
# We need few more timestamps
#
pipeline_job_start_ts_micros=$(date "+%s%6N")
       stage_start_ts_micros=$(date "+%s%6N")
      stage_start_ts_seconds=$(($stage_start_ts_micros/1000000))
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
cat ${SQLTMP} | bq --location=EU query --use_legacy_sql=false > ${BQ_OUTPUT} 2>&1
RETURN_CODE=$?
cat ${BQ_OUTPUT}                        # Show the bq output on screen
#
# Force an error to test
#
#if [[ ${SQL} == *"W_STG_WRK_INTERACTOR_KEY_STAGE_create.sql"* ]]
#then
#       RETURN_CODE=789
#fi
#
FROM_BQ=$(strings ${BQ_OUTPUT} | grep -v "^$" |  awk '{if ($NF == "DONE") { printf $0; while(getline) { printf $0}}}')
show_log "Executed${SEP}${SQL}${SEP}${RETURN_CODE}${SEP}${FROM_BQ}"
FROM_BQ=""
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
for X in ${SQLTMP} ${YMLTMP} ${TMP} ${TMP4}
do
        if [[ -f ${X} ]]
        then
                rm -f ${X}
        fi
done
#
# Return code
#
exit ${RETURN_CODE}
#
#
#************************************************************************#
#*                      E N D      O F      S O U R C E                 *#
#************************************************************************#
