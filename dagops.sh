#!/bin/bash
# Fred Denis -- Oct 23rd 2019 -- ERS-143
#
# Use of makefiles to schedule jobs
#
# - Parse a JSON file containing the list of jobs, dependencies, etc ...
# - Use json.tool to make it more usable
# - Generate the makefile with the jobs and the dependencies
# - Use make to execute the job, make taking care of the //, dependencies, etc ...
#
# The current version of the script is in dev
#
# 20190223 - Fred Denis - Dev starting
#
#
#
# Files
#
       HERE=`dirname $0`                                # Script directory
         IN=json.txt                                    # Main   JSON input file
        IN2=json2.txt                                   # Second JSON input file
 PRE_SCRIPT=${HERE}"/prescript.sh"                      # A potential pre  script to run
POST_SCRIPT=${HERE}"/postscript.sh"                     # A potential post script ro run
EXEC_SCRIPT="/home/autogen/dagops/run_on_bq.sh"         # Run a SQL on big query
#
# Some default values
#
        DIR="/home/autogen/teradata-migration-etl"      # Default project home directory
        LOG=${HERE}"/logs"                              # Logfiles directory
     TMPDIR=${HERE}"/tmp"                               # Tempfiles directory
 SYNC_SLEEP=1                                           # Seconds to let the eventual consistency to work
 START_DATE="Jan 1 00:00:00 2010"                       # Default start date to execute the SQLs        (-s)
   END_DATE=$(date "+%b %d %T %Y")                      # Default end date (now)                        (-e)
       INCR=1year                                       # Default date increment
   PARALLEL=""                                          # Job execution parallellism (empty string means as much // as the system can)
     DRYRUN=""                                          # Dryrun only
       UNIQ=$(date +%s)                                 # Epoch sec to have this unique pattern in the logfile names
        TMP=${TMPDIR}/fictemp$$                         # A tempfile
       TMP2=${TMPDIR}/fictemp2$$                        # A tempfile
       TMP3=${TMPDIR}/fictemp3$$                        # A tempfile
       TMP4=${TMPDIR}/fictemp4$$                        # A tempfile
   STOP_NOW=${HERE}"/stop_now"                          # If this file exists, we exit rigth now
         #TS="date "+%Y-%m-%d-%H-%M-%S""                 # TS
         TS="date "+%Y-%m-%d_%H:%M:%S""                 # TS
        TSM="date "+%s%6N""                             # TS micro
        SEP="|"                                         # Column separator for the logfiles
     TIDYUP="YES"                                       # Run pre and post script                       (-t and -T)


declare -ag logfile                                     # Global logfile name
#
# Check log and temp directories
#
for X in ${LOG} ${TMPDIR}
do
        if [[ ! -d "${X}" ]]
        then
                mkdir -p "${X}"
                if [ $? -eq 0 ]
                then
                        printf "\n\t\033[1;33m%s\033[m\n\n" "Directoy successfully created: "${X}"."
                else
                        printf "\n\t\033[1;36m%s\033[m\n\n" "Error when creating "${X}", you may want to investigate to get full features of the scripts."
                fi
        fi
done
#
# Show the version of the script (-V)
#
show_version()
{
        VERSION=`awk '{if ($0 ~ /^# 20[0-9][0-9][0-1][0-9]/) {print $2; exit}}' $0`
        printf "\n\t\033[1;36m%s\033[m\n\n" "The current version of "`basename $0`" is "$VERSION"."          ;
}
#
# An usage function
#
usage()
{
printf "\n\033[1;37m%-8s\033[m\n" "NAME"                ;
cat << END
        `basename $0` - Read 2 JSON files containing jobs to execute, dependencies, steps , etc ... and orchestrate their execution in //
END

printf "\n\033[1;37m%-8s\033[m\n" "SYNOPSIS"            ;
cat << END
        $0 [-j] [-d] [-f] [-F] [-l] [-n] [-e] [-c] [-s] [-i] [-t] [-T] [-V] [-h]
END

printf "\n\033[1;37m%-8s\033[m\n" "DESCRIPTION"         ;
cat << END
        $0 reads 2 JSON input file:
                A main   one which contains some jobs definition with steps and dependencies
                A second one which contains each step details with the SQL to execute

        $0 will orchestrate all these jobs with their dependencies in //
END

printf "\n\033[1;37m%-8s\033[m\n" "OPTIONS"             ;
cat << END
        -j      A job to execute (default is we execute all the jobs specified in the main JSON file)
        -d      A dry-run execution only (shows what it would be done but dont do anything)

        -l      List the jobs from the main JSON file
        -n      No Exec -- generate the files only

        -c      Seconds to let the eventual consistency to work (eventual consistency sleep)
        -p      Parallel job execution -- default is we use as many // as the system can
        -t      Tidy up !        run a prescript and a postscript before and after each RUN_ID (default)
        -T      Do NOT tidy up ! don't run any prescript or postscript
        -w      Way to the SQL files (a directory)

        -e      End date (same format as START_DATE -- see below)
        -s      A start date to execute the job -- must be in format "Jan 1 00:00:00 2010" which is the default; example:
                        -s "Jul 14 12:34:56 2015"

        -i      Date increment, default is 1year; example:
                        -i 2year
                        -i 1year+1month+1week

        -f      Main JSON input file
        -F      Second JSON input file containing the steps details

        -V      Shows the version of the script
        -h      Shows this help

END
exit 123
}
#
# Options
#
while getopts "j:df:F:c:lne:s:i:p:tTw:Vh" OPT; do
        case ${OPT} in
        j)         MASTER="${OPTARG}"                                   ;;
        d)         DRYRUN=" --dry-run"                                  ;;
        l) LIST_JOBS_ONLY="TRUE"                                        ;;
        n)        NO_EXEC=TRUE                                          ;;
        e)       END_DATE="${OPTARG}"                                   ;;
        c)     SYNC_SLEEP=${OPTARG}                                     ;;
        s)     START_DATE="${OPTARG}"                                   ;;
        p)       PARALLEL="${OPTARG}"                                   ;;
        i)           INCR="${OPTARG}"                                   ;;
        t)         TIDYUP="YES"                                         ;;
        T)         TIDYUP="NO"                                          ;;
        w)            DIR="${OPTARG}"                                   ;;
        f)             IN=${OPTARG}                                     ;;
        F)            IN2=${OPTARG}                                     ;;
        V)      show_version; exit 567                                  ;;
        h)         usage                                                ;;
        \?)        echo "Invalid option: -$OPTARG" >&2; usage           ;;
        esac
done
#
# Options check
#
for x in ${IN} ${IN2}
do
        if [[ ! -f ${x} ]]
        then
                printf "\n\t\033[1;31m%s\033[m\n\n" "Cannot find the input file "${x}"; cannot continue."
                exit 123
        fi
done
if [[ -z "${MASTER}" ]]
then
        TAG="MULTIJOBS"
else
        TAG=$MASTER
fi
if [[ "$PARALLEL" = "0" ]]
then
        PARALLEL=1
fi
if [[ -z $PARALLEL ]]                           # What to show in the logs
then
        SHOW_PARALLEL="Max"
else
        SHOW_PARALLEL=$PARALLEL
fi
#
# Logfile
#
 STATUS="RUNNING"
LOGFILE=$LOG"/dagops_$UNIQ"_""`date +%Y-%m-%d-%H-%M-%S`"_"$TAG"_P"$SHOW_PARALLEL"_"
logfile[1]=${LOGFILE}${STATUS}
#
# Rename the logfile with a status to see what was wrong from the logfile name
#
rename_logfile()
{
        mv ${logfile[1]} ${LOGFILE}$1
        logfile[1]=${LOGFILE}$1
        echo "Logfile:"${logfile[1]}
}
#
# A function to execute the makefile
#
make_it()
{
        if [[ -f $1 ]]
        then
                if [[ -f ${STOP_NOW} ]]         # stop_now detected, we exit
                then
                        rename_logfile "STOP_NOW"
                        echo "$($TS)${SEP}$($TSM)${SEP}${MASTER}${SEP}${RUN_ID}${SEP}${SHOW_PARALLEL}${SEP}${FROM_MIC}${SEP}${TO_MIC}${SEP}Error$SEP${STOP_NOW}${SEP}666" >> ${logfile[1]}
                        exit 666
                fi
                make -j ${PARALLEL} -f $1 ${DRYRUN}
                RET=$?
                if [ $RET -eq 0 ]
                then
                        rename_logfile "OK"
                else
                        rename_logfile "KO"
                fi
        else
                printf "\n\t\033[1;31m%s\033[m\n\n" "A makefile is needed; cannot continue without."
                exit 678
        fi
}
#
# A function to show the list of jobs contained in the JSON input file and exit 0
#
show_jobs()
{
        cat ${IN} | sed s'/[",]//g' | sed s'/ *//' |\
                awk -v IN="$IN" 'BEGIN\
                {       FS=":"                          ;
                        TITLE="List of jobs in the "IN" file"                   ;
                         SIZE=length(TITLE)+2                                   ;

                        printf("\n\033[1;37m%"SIZE"s\033[m\n", TITLE)           ;
                        printf("%s", "\033[1;37m")                              ;
                        for (k=1; k<=SIZE+4; k++) {printf("%s", "-")            ;}
                        printf("%s\n", "\033[m")                                ;

                }
                {       if ($1 == "name" )
                        {       job = $2                ;
                                gsub (" ","", job)      ;
                                getline                 ;
                                if ($1 == "schedule")
                                {
                                        printf("\033[1;37m| \033[m%-"SIZE"s\033[1;37m |\033[m\n", job)  ;
                                }
                        }
                } END { printf("%s", "\033[1;37m")                              ;
                        for (k=1; k<=SIZE+4; k++) {printf("%s", "-")            ;}
                        printf("%s\n\n", "\033[m")                              ;
                      }
                '
}
#
# Get a run id (from a file and later from mysql), increment it and save it
#
get_run_id()
{
        RUN_ID_FILE=".run_id"
        if ! [[ -f ${RUN_ID_FILE} ]]
        then
                echo "123" > ${RUN_ID_FILE}
        fi
        X=`cat ${RUN_ID_FILE} | grep -v "^#" | head -1`
        Y=$((X+1))
        echo $Y > ${RUN_ID_FILE}
        echo $X
}
#
# echo for the logs in the same format
#
show_log()
{
        MASTER_LOWER=$(echo "${MASTER}" | tr '[:upper:]' '[:lower:]')
        #TS_FOR_BQ=$(date --date "$TS" "+%Y-%m-%d %H:%M:%S")
        echo $($TS)${SEP}$($TSM)${SEP}${UNIQ}${SEP}${MASTER_LOWER}${SEP}"NONE"${SEP}${RUN_ID}${SEP}${SHOW_PARALLEL}${SEP}${FROM_MIC}${SEP}${TO_MIC}${SEP}$@
}
#
# Execute pre or post script, do some cleanup
#
cleanup()
{       a_script=$1
        if [[ "${TIDYUP}" = "YES" ]]
        then
                if [[ -f ${a_script} ]]
                then
                        /bin/bash ${a_script}
                        show_log "Executed${SEP}${a_script}${SEP}$?"
                else
                        show_log "Error${SEP}${a_script} does not exist${SEP}123"
                fi
        fi
}
#
# Check the logfile trying to see if something wrong happened
#
check_logs()
{
NB=$(grep "^20" ${logfile[1]} | awk '{if (($3 == "End")|| ($3 =="Begin")) {print $4}}' | sort  | uniq -c | awk '{if ($1 == 1){print $0}}' | wc -l)
if (( $NB > 1 ))
then
        printf "\n\t\033[1;36m%s\033[m\n\n" "Some jobs seems to have had issues; please investigate the below jobs."
        grep "^20" ${logfile[1]} | awk '{if (($3 == "End")|| ($3 =="Begin")) {print $4}}' | sort  | uniq -c | awk '{if ($1 == 1){print $0}}'
        rename_logfile "TO_INVESTIGATE"
        exit 1
fi
}
#
# Get a log and insert it in bq
#
function to_bq()
{
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

        gcloud config configurations activate dagops
#       bq query --location=EU --use_legacy_sql=false --format=pretty 'select count(*) from ONETM_INGEST_COPY.dagops_logs'
#       wc -l ${TMP4}
        bq load -F "|" ONETM_INGEST_COPY.dagops_logs ${TMP4}
#       bq query --location=EU --use_legacy_sql=false --format=pretty 'select count(*) from ONETM_INGEST_COPY.dagops_logs'
        gcloud config configurations activate default
}


if [[  "${LIST_JOBS_ONLY}" = "TRUE" ]]
then
        show_jobs                       | tee -a ${logfile[1]}
        rename_logfile "SHOW_ONLY"
        exit 0
fi
#
# Verify that the launcher script is there
#
if [[ ! -f ${EXEC_SCRIPT} ]]
then
        printf "\n\t\033[1;36m%s\033[m\n\n" "Cannot find "${EXEC_SCRIPT}"; cannot continue"     | tee -a  ${logfile[1]}
        rename_logfile "KO"
        exit 789
fi
#
# Merge the jobs and the subparts details in one file
#
python -m json.tool ${IN} | sed s'/[",]//g' | sed s'/ *//' |\
        awk -v IN2="${IN2}" -v MASTER="${MASTER}"\
             'BEGIN {   FS=":";
                    }
             {  if ($1 == "name")
                {       print $0                                                ;
                        master=tolower($2)                                      ;
                        gsub (" ", "", master)                                  ;
                        while(getline)
                        {       if ($1 == "nodes")
                                {       print $0                                ;
                                        while(getline)
                                        {
                                                print $0                        ;
                                                if ($1 == "name")
                                                {       name = $2               ;
                                                        gsub(" ", "", name)     ;
                                                        comm="echo START_DETAILS; sed -e \47/\42"name"\42:/,/^    },/!d\47 "IN2"; echo END_DETAILS"     ;
                                                        system(comm) ;
                                                }
                                                if ($1 == "timeout")
                                                {
                                                        print $0                ;
                                                        break                   ;
                                                }
                                        }
                                }
                                if ($1 == "timeout")
                                {
                                        break                                   ;
                                }
                        }
                } else {
                        print $0        ;
                }
             }
            ' | sed s'/[",]//g' > ${TMP}
#
# Generate and execute the makefiles
#
FROM_MIC=$(date -d "$START_DATE" "+%s%6N")
if [ $? -ne 0 ]                         # Verify that the date format is good
then
        cat << !
        Date format has to be like :
        Jan 1 00:00:00 2010
!
        exit
fi
    TO_MIC=$FROM_MIC
   NOW_MIC=$(date -d "$END_DATE" "+%s%6N")
if [ $? -ne 0 ]                         # Verify that the date format is good
then
        cat << !
        Date format has to be like :
        Jan 1 00:00:00 2010
!
        exit
fi

while [ ${TO_MIC} -lt ${NOW_MIC} ]
do
        #
        # Date work
        #
        # Dates in "Jan 1 00:00:00 2010" format
        FROM=$(date --date "$(date -d @$((${FROM_MIC}/1000000))     "+%b %d %T %Y")"           "+%b %d %T %Y"   )
          TO=$(date --date "$(date -d @$(((${FROM_MIC}-1)/1000000)) "+%b %d %T %Y") + ${INCR}" "+%b %d %T %Y"   )
        # Dates microseconds
    FROM_MIC=$(date --date "$FROM" "+%s%6N")
      TO_MIC=$(date --date "$(date -d @$((${FROM_MIC}/1000000))     "+%b %d %T %Y") + ${INCR}" "+%s%6N"         )
      TO_MIC=$((${TO_MIC}-1))
        if [ "$TO_MIC" -gt "$NOW_MIC" ]
        then
            TO_MIC=$NOW_MIC
                TO=$(date --date "$(date -d @$((${TO_MIC}/1000000)) "+%b %d %T %Y")"           "+%b %d %T %Y"   )
        fi
        #echo "from:"$FROM":"$TO":"$FROM_MIC":"${TO_MIC}
        #
        # RUN_ID and logfile
        #
            RUN_ID=$(get_run_id)
            STATUS="RUNNING"
           LOGFILE=$LOG"/dagops_$UNIQ"_""`date +%Y-%m-%d-%H-%M-%S`"_"$TAG"_P"$SHOW_PARALLEL"_"$RUN_ID"_"
        logfile[1]=${LOGFILE}${STATUS}
        #
        # A sum up banner
        #
        cat << END                      | tee -a ${logfile[1]}
#************************************************************************************************#
#*      JOB             : $MASTER
#*      RUN_ID          : $RUN_ID
#*      PARALLEL        : $SHOW_PARALLEL
#*      FROM_MIC        : $FROM_MIC     => (${FROM})
#*      TO_MIC          : $TO_MIC       => (${TO})
#************************************************************************************************#
END
        #
        # Pre script
        #
        #cleanup ${PRE_SCRIPT}          | tee -a ${logfile[1]}
        cleanup ${PRE_SCRIPT}           | to_bq
        #
        # Generate the makefile
        #
        cat ${TMP} | awk -v MASTER="${MASTER}" -v EXEC_SCRIPT="${EXEC_SCRIPT}" -v SYNC_SLEEP="${SYNC_SLEEP}" -v DIR="${DIR}" -v UNIQ="${UNIQ}"\
                    -v RUN_ID="${RUN_ID}" -v FROM_MIC="${FROM_MIC}" -v  TO_MIC="${TO_MIC}" -v PARALLEL="${SHOW_PARALLEL}"\
             'BEGIN {   FS=":";
                    }
             function print_txt_ts(txt1, txt2)
             {          # Print a "@echo <TXT> <TIMESTAMP>" line
                        #printf("\t%s\n", "@echo -e \42" $(TS) "|" $(TSM) "|"in_txt"|"RUN_ID"|"PARALLEL"|"FROM_MIC"|"TO_MIC"|Info||0\42")                     ;
#                      printf("\t%s\n", "@echo -e $(TS) $(TSM) \"" in_txt "\"" )                       ;
                       printf("\t%s\n", "@echo -e $(TS)${SEP}$(TSM)${SEP}"txt1"${SEP}"RUN_ID"${SEP}"PARALLEL"${SEP}"FROM_MIC"${SEP}"TO_MIC"${SEP}"txt2"${SEP}${SEP}0")                       ;
#        @echo -e $(TS) $(TSM) "demo_customer_e2e|Begin_master"
#        @echo -e $(TS)${SEP}$(TSM)${SEP}demo_customer_e2e${SEP}Begin_master

             }
             function print_exec(path, job_name, info)
             {          # Generate the SQL execution command line
                        if (info != "")
                        {       INFO_TAG="-i"   ;
                                    info=""     ;
                        } else {
                                INFO_TAG=""     ;
                        }
                        printf("\t%s\n", "@"EXEC_SCRIPT" -s "path" -r "RUN_ID" -f "FROM_MIC" -t "TO_MIC" -j "job_name" "INFO_TAG" -c "SYNC_SLEEP" -p "PARALLEL" -w " DIR" -m "master" -u "UNIQ)  ;
                        printf("\n")                                                                    ;
             }
             {  gsub (" ", "", $2)      ;
                if (($1 == "name") && (($2 == MASTER) || (MASTER == "")))
                {       master=tolower($2)                                                              ;
                        gsub (" ", "", master)                                                          ;
                        end_deps = ""                                                                   ;

                        #printf ("%s\n", "TS := `/bin/date \"+%Y-%m-%d-%H-%M-%S\"`")                     ;       # A date
                        printf ("%s\n", "TS := `/bin/date \"+%Y-%m-%d %H:%M:%S\"`")                     ;       # A date
                        printf ("%s\n", "TSM := `/bin/date \"+%s%6N\"`")                                ;       # epoch micro
                        printf ("%s\n", "SEP := \"|\"")                                                 ;       # logfile separator
                        printf ("%s: %s\n", "done", "end-"master)                                       ;       # Label for MASTER end
                        printf("%s:\n", master)                                                         ;       # MASTER start
                        #print_txt_ts(master,"Begin_master")                                            ;       # Print that MASTER starts
                        print_exec(master,"Begin_master","info")                                        ;
                        #print_exec(tab_sql[sql_name], job)                                             ;
                        #printf ("\n")                                                                   ;

                        while(getline)
                        {       if ($1 == "nodes")
                                {       while(getline)
                                        {       if ($1 == "dependencies")
                                                {       dep = ""                                        ;
                                                        if ($2 ~ /\[\]/)
                                                        {       dep = master                            ;
                                                        } else
                                                        {       while(getline)
                                                                {
                                                                        if ($1 ~ /^\]/)
                                                                        {       break                   ;
                                                                        }
                                                                        if (dep == "")
                                                                        {       dep = "end-"master"-"$0       ;
                                                                        } else
                                                                        {
                                                                                dep = dep" end-"master"-"$0 ;
                                                                        }
                                                                }
                                                        }
                                                }
                                                if ($1 == "name")                                                       # job
                                                {       gsub("^ ", "", dep)                                                             ;
                                                        name = $2                                                                       ;
                                                        gsub(" ", "", name)                                                             ;

                                                        job = master"-"name                                                             ;
                                                        printf("%s: %s\n", job,  dep)                                                   ;
                                                        #print_txt_ts(job,"Begin")                                                      ;
                                                        print_exec(job,"Begin","info")                                                  ;
                                                        #printf("\t%s\n\n", "sleep " 1)                                                 ;
                                                        end_name="end-"job" "end_name                                                   ;
                                                }
                                                if ($1 == "START_DETAILS")                                              # job details (substeps => SQL)
                                                {       while (getline)
                                                        {       gsub(" ", "", $2)                                                                                       ;
                                                                gsub(" ", "", $1)                                                                                       ;
                                                                job_deps = ""                                                                                           ;
                                                                if ($1 == "name")                                       # Name of the SQL to launch
                                                                {       sql_name = $2                                                                                   ;
                                                                }
                                                                if ($1 == "path")                                       # SQL script
                                                                {       tab_sql[sql_name] = $2                                                                          ;
                                                                }
                                                                if ($1 == "dependencies")                               # Substeps dependencies
                                                                {       while (getline)
                                                                        {                                                                                               ;
                                                                                gsub(" ", "", $1)                                                                       ;
                                                                                gsub(" ", "", $2)                                                                       ;
                                                                                sql_name = $1                                                                           ;
                                                                                if ($2 ~ /\[\]/)                        # No dependency
                                                                                {       job_deps = job_deps" "job"-"$1                                                  ;
                                                                                        printf("%s: %s\n", job"-"sql_name, job)                                         ;
                                                                                        print_exec(tab_sql[sql_name], job)                                              ;
                                                                                }
                                                                                if ($2 ~ /\[$/)                         # Dependencies list
                                                                                {       job_deps = job_deps" "job"-"$1                                                  ;
                                                                                        sql_name = $1                                                                   ;
                                                                                        tab_dep[sql_name] = ""  ;
                                                                                        while(getline)
                                                                                        {       gsub(" ", "", $1)                                                       ;
                                                                                                if ($1 ~ /\]$/)
                                                                                                {
                                                                                                        printf("%s: %s\n", job"-"sql_name, tab_dep[sql_name] )          ;
                                                                                                        print_exec(tab_sql[sql_name], job)                              ;
                                                                                                        break                                                           ;
                                                                                                }
                                                                                                if ($1 ~ /[a-zA-Z]/)
                                                                                                {       tab_dep[sql_name] = tab_dep[sql_name]" "job"-"$1                ;
                                                                                                }
                                                                                        }
                                                                                }
                                                                                if ($1 == "END_DETAILS")
                                                                                {       break   ;
                                                                                }
                                                                        }
                                                                }
                                                                if ($1 == "END_DETAILS")
                                                                {
                                                                        if (job_deps == "")                                     # Job has no deps => issue in the config file ?
                                                                        {       with_no_deps=with_no_deps" ""end-"job   ;
                                                                        }
                                                                        printf("%s: %s\n", "end-"job, job_deps)         ;       # End of the job substeps
                                                                        end_deps = end_deps" end-"job                   ;
                                                                        #print_txt_ts(job,"End")                        ;
                                                                        print_exec(job,"End","info")                    ;
                                                                        #printf("\n")                                    ;
                                                                        break                                           ;
                                                                }
                                                        }
                                                }
                                                if ($1 == "timeout")
                                                {
                                                        break                                   ;
                                                }
                                        }
                                }
                                if ($1 == "timeout")                                                    # End of the MASTER job
                                {
                                        printf("%s: %s\n", "end-"master, end_deps)              ;
                                        #print_txt_ts(master,"End_master")                      ;
                                        print_exec(master,"End_master","info")                  ;
                                        printf ("\n")                                           ;
                                        break                                                   ;
                                }
                        }
                }
             }
            ' > ${TMP2}

        # May be useful in case of debug
        cp $TMP  ${TMPDIR}/a                      # Merged JSON file
        cp $TMP2 ${TMPDIR}/b_$RUN_ID              # Makefile

        if ! grep -q "^done" $TMP2
        then
                cat << END                      | tee -a ${logfile[1]}
                It looks like you picked a job which is not defined in $IN.
                Please pick a job in the below list:
END
                show_jobs                       | tee -a ${logfile[1]}
                rename_logfile "WRONG_JOB"
        fi

        if [[ "$NO_EXEC" = "TRUE" ]]
        then
                cat << !                        | tee -a ${logfile[1]}

                File ${TMPDIR}/a is the JSON merged file.
                File ${TMPDIR}/b_$RUN_ID is the generated makefiles.
                We wont execute anything here.
!
                if [[ ${logfile[1]} == *"RUNNING"* ]]
                then
                   rename_logfile "NOEXEC"
                fi
        else
                make_it ${TMP2}                 | tee -a ${logfile[1]}  # Execute the makefile
                #make_it ${TMP2}                 | to_bq
        fi
        #
        # Post script
        #
        #cleanup ${POST_SCRIPT}                 | tee -a ${logfile[1]}
        cleanup ${POST_SCRIPT}                  | to_bq
        #
        # New FROM_MIC
        #
        FROM_MIC=$(date --date "$(date -d @$((${FROM_MIC}/1000000)) "+%b %d %T %Y") + ${INCR}" "+%s%6N"         )
done    # End of the date loop

#check_logs ${logfile[1]}
# Import the logs
#
#cat ${LOG}/*${UNIQ}* | grep "^2" | sed s'/_/ /' > ${TMP4}
#gcloud config configurations activate dagops
#printf "\n\033[1;36m%s\033[m\n" "Number of lines in ONETM_INGEST_COPY.dagops_logs"
#bq query --location=EU --use_legacy_sql=false --format=pretty 'select count(*) from ONETM_INGEST_COPY.dagops_logs'
#printf "\n\033[1;36m%s\033[m\n" "Loading the new logs . . ."
#bq load -F "|" ONETM_INGEST_COPY.dagops_logs ${TMP4}
#printf "\n\033[1;36m%s\033[m\n"\n "Number of lines in ONETM_INGEST_COPY.dagops_logs"
#bq query --location=EU --use_legacy_sql=false --format=pretty 'select count(*) from ONETM_INGEST_COPY.dagops_logs'
#gcloud config configurations activate default

for F in ${TMP} ${TMP2} ${TMP3} ${TMP4}
do
        if [[ -f ${F} ]]
        then
                rm -f ${F}
        fi
done

#****************************************************************#
#*              E N D      O F      S O U R C E                 *#
#****************************************************************#
