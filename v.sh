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
# Files
#
    IN=json.txt                 # Main   JSON input file
   IN2=json2.txt                # Second JSON input file
   TMP=/tmp/fictemp$$           # A tempfile
  TMP2=/tmp/fictemp2$$          # A tempfile
  TMP3=/tmp/fictemp3$$          # A tempfile
#
# Some default values
#
MASTER="."
DRYRUN=""
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
        $0 [-j] [-d] [-f] [-F] [-V] [-h]
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
while getopts "j:df:F:Vh" OPT; do
        case ${OPT} in
        j)        MASTER="${OPTARG}"                                    ;;
        d)        DRYRUN=" --dry-run"                                   ;;
        f)            IN=${OPTARG}                                      ;;
        F)           IN2=${OPTARG}                                      ;;
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
if [[ -z ${MASTER} ]]
then
        MASTER="."
fi
#
# Merge the jobs and the subparts details in one file
#
python -m json.tool ${IN} | sed s'/[",]//g' | sed s'/ *//' |\
        awk -v IN2="${IN2}" -v MASTER="${MASTER}"\
             'BEGIN {   FS=":";
                    }
             {  if (($1 == "name") && ($2 ~ MASTER))
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

cat ${TMP} | awk -v MASTER="${MASTER}"\
             'BEGIN {   FS=":";
                        srand() ;
                    }
             function print_txt_ts(in_txt)
             {          # Print a "@echo <TXT> <TIMESTAMP>" line
                        printf("\t%s\n", "@echo -e $(TS) $(TSM) \"" in_txt "\"" )                       ;
             }
             function print_exec(path)
             {          # Get one or more path, generates the execution commands
                        printf("\t%s\n", "@/home/oracle/scripts/exec_something.sh "path)                ;
                        x=int((rand()*100))                                                             ;
                        if (x>60){x=x-60}                                                               ;
                        print_txt_ts(""path " sleeps for " x " seconds" )                               ;
                        printf("\t%s\n", "sleep " x)                                                    ;
                        printf("\n")                                                                    ;
             }
             { if (($1 == "name") && ($2 ~ MASTER))
                {       master=tolower($2)                                                              ;
                        gsub (" ", "", master)                                                          ;

                        printf ("%s\n", "TS := `/bin/date \"+%Y-%m-%d-%H-%M-%S\"`")                     ;       # A date
                        printf ("%s\n", "TSM := `/bin/date \"+%s%6N\"`")                                ;       # epoch micro
                        printf ("%s: %s\n", "done", "end-"master)                                       ;
                        printf("%s:\n", master)                                                         ;
                        print_txt_ts("Begin " master)                                                   ;
                        printf ("\n")                                                                   ;

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
                                                if ($1 == "name")
                                                {       gsub("^ ", "", dep)                                                             ;
                                                        name = $2                                                                       ;
                                                        gsub(" ", "", name)                                                             ;

                                                        job = master"-"name                                                             ;
                                                        printf("%s: %s\n", job,  dep)                                                   ;
                                                        print_txt_ts("Begin "job )                                                      ;
                                                        printf("\t%s\n\n", "sleep " 1)                                                  ;
                                                        end_name="end-"job" "end_name                                                   ;
                                                }
                                                if ($1 == "START_DETAILS")
                                                {       while (getline)
                                                        {       gsub(" ", "", $2)                                                                           ;                                                                gsub(" ", "", $1)                                                                           ;                                                                if ($1 == "name")
                                                                {       sql_name = $2                                                                       ;                                                                }
                                                                if ($1 == "path")
                                                                {       tab_sql[sql_name] = $2                                                              ;                                                                }
                                                                if ($1 == "dependencies")
                                                                {       while (getline)
                                                                        {                                                                                   ;                                                                                gsub(" ", "", $1)                                                           ;                                                                                gsub(" ", "", $2)                                                           ;                                                                                sql_name = $1                                                               ;                                                                                if ($2 ~ /\[\]/)
                                                                                {       job_deps = job_deps" "job"-"$1                                      ;                                                                                        printf("%s: %s\n", job"-"sql_name, job)                             ;                                                                                        print_exec(job"-"$1)                                                ;                                                                                }
                                                                                if ($2 ~ /\[$/)
                                                                                {       job_deps = job_deps" "job"-"$1                                      ;                                                                                        sql_name = $1                                                       ;                                                                                        while(getline)
                                                                                        {       gsub(" ", "", $1)                                           ;                                                                                                if ($1 ~ /\]$/)
                                                                                                {       
                                                                                                        printf("%s: %s\n", job"-"sql_name, tab_dep[sql_name] )       ;
                                                                                                        print_exec(tab_sql[sql_name])                       ;                                                                                                        break                                               ;                                                                                                }
                                                                                                if ($1 ~ /[a-zA-Z]/)
                                                                                                {       tab_dep[sql_name] = tab_dep[sql_name]" "job"-"$1    ;                                                                                                }
                                                                                        }
                                                                                }
                                                                                if ($1 == "END_DETAILS")
                                                                                {       break   ;
                                                                                }
                                                                        }
                                                                }
                                                                if ($1 == "END_DETAILS")
                                                                {
                                                                        printf("%s: %s\n", "end-"job, job_deps)         ;
                                                                        print_txt_ts("End "job )                        ;
                                                                        printf("\n")                                    ;
                                                                        job_deps = ""                                   ;
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
                                if ($1 == "timeout")
                                {       
                                        printf("%s: %s\n", "end-"master, end_name)              ;
                                        printf("\t%s\n", "@echo \"End " master "\""" $(TS)")    ;
                                        printf ("\n")                                           ;
                                        break                                                   ;
                                }
                        }
                }
             }
            ' > ${TMP2}
cp $TMP a
cp $TMP2 b
#cat $TMP2
make -k -j -f ${TMP2} ${DRYRUN}

for F in ${TMP} ${TMP2} ${TMP3}
do
        if [[ -f ${F} ]]
        then
                rm -f ${F}
        fi
done

#****************************************************************#
#*              E N D      O F      S O U R C E                 *#
#****************************************************************#
