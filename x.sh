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
        $0 [-j] [-d] [-V] [-h]
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
        -j        A job to execute (default is we execute all the jobs specified in the main JSON file)
        -d        A dry-run execution only (shows what it would be done but dont do anything)

        -V        Shows the version of the script
        -h        Shows this help

END
exit 123
}

#
# Options
#
while getopts "j:dVh" OPT; do
        case ${OPT} in
        j)        MASTER="${OPTARG}"                                                            ;;
        d)        DRYRUN=" --dry-run"                                                           ;;
        V)      show_version; exit 567                                                          ;;
        h)         usage                                                                        ;;
        \?)        echo "Invalid option: -$OPTARG" >&2; usage                                   ;;
        esac
done

# To specify a special job -- to be replaced by getopts
if [[ -z ${MASTER} ]] 
then
        MASTER="."
fi
#
# Get the steps name of the job(s) we want to run
# I could not make jq to work to combine the 2 JSON files so I did it manually
#
STEPS=`python -m json.tool ${IN} | sed s'/[",]//g' | sed s'/ *//' |\
        awk -v MASTER="${MASTER}"\
             'BEGIN {   FS=":";
                    }
             { if (($1 == "name") && ($2 ~ MASTER))
                {       master=tolower($2)                                      ;
                        gsub (" ", "", master)                                  ;

                        while(getline)
                        {
                                if ($1 == "nodes")
                                {       while(getline)
                                        {     
                                                if ($1 == "name")
                                                {       gsub(" ", "", $2)       ;
                                                        printf("%s|", $2)       ;
                                                }
                                                if ($1 == "timeout")
                                                {
                                                        break                   ;
                                                }
                                        }
                                }
                                if ($1 == "timeout")
                                {       
                                        break                                   ; 
                                }
                        }
                }
             }
            '`
# Prepare files
cat ${IN2}                | sed s'/[",]//g' | sed s'/ *//' > ${TMP2}
python -m json.tool ${IN} | sed s'/[",]//g' | sed s'/ *//' > ${TMP3}

awk -v STEPS="$STEPS" -v FILE1="$TMP2" -v FILE2="$TMP3" -v MASTER="${MASTER}"\
        'BEGIN {        FS=":"                                  ;
                        split (STEPS, steps, "|")               ;
                        for (i in steps) i_steps[steps[i]] = "" ;
                        srand()                                 ;
                }
        function print_txt_ts(in_txt)
        {       # Print a "@echo <TXT> <TIMESTAMP>" line
                printf("\t%s\n", "@echo -e \"" in_txt  "\""" $(TS)")                    ;
        }
        function print_exec(path)
        {       # Get one or more path, generates the execution commands
                split(path, temp, ";")                                                  ;
                for (i in temp)
                {       printf("\t%s\n", "@/home/oracle/scripts/exec_something.sh "temp[i])                     ;
                }
        }
        {       if (FILENAME == FILE1)
                {       if ($1 == "{")
                        {       getline                                                 ;
                                PATH=""                                                 ;
                                sub (" ", "", $1)                                       ;
                                if ($1 in i_steps)
                                {       current_step=$1 ;
                                        while (getline)
                                        {       if ($1 == "path")
                                                {       gsub (" ", "", $2)              ;
                                                        if (PATH == "")
                                                        {       PATH = $2               ;
                                                        } else {
                                                                PATH=PATH";"$2          ;
                                                        }
                                                }
                                                if ($1 == "dependencies")
                                                {
                                                        #print PATH                     ;
                                                        to_exec[current_step] = PATH    ;
                                                        break                           ;
                                                }
                                        }
                                }
                        }
                }
                if (FILENAME == FILE2)
                {
                  if (($1 == "name") && ($2 ~ MASTER))
                  {     master=tolower($2)                                      ;
                        gsub (" ", "", master)                                  ;

                        printf ("%s\n", "TS := `/bin/date \"+%Y-%m-%d-%H-%M-%S\"`")             ;
                        printf ("%s: %s\n", "done", "end-"master)             ;
                        printf("%s:\n", master)
                        print_txt_ts("Begin " master)   ;

                        while(getline)
                        {
                                if ($1 == "nodes")
                                {       while(getline)
                                        {       if ($1 == "dependencies")
                                                {       dep = ""                                ;
                                                        if ($2 ~ /\[\]/)
                                                        {       dep = master                    ;
                                                        } else
                                                        {       while(getline)
                                                                {
                                                                        if ($1 ~ /^\]/)
                                                                        {       break           ;
                                                                        }
                                                                        if (dep == "")
                                                                        {       dep = master"-"$0       ;
                                                                        } else
                                                                        {
                                                                                dep = dep" "master"-"$0 ;
                                                                        }
                                                                }
                                                        }
                                                }
                                                if ($1 == "name")
                                                {       gsub("^ ", "", dep)                     ;
                                                        name = $2                               ;
                                                        gsub(" ", "", name)                     ;

                                                        printf("%s: %s\n", master"-"name,  dep)         ;
                                                        print_txt_ts("\\tBegin "master"-"name )   ;
                                                        x=int((rand()*100));                                                    # dev
                                                        if (x>60){x=x-60};                                                      # dev
                                                        #print_txt_ts("\\t"master"-"name " sleeps for " x " seconds" )   ;      # dev
                                                        print_exec(master"_"name"_"to_exec[name])               ;
                                                        printf("\t%s\n", "sleep " x)                    ;                       # dev
                                                        print_txt_ts("\\tEnd "master"-"name )   ;
                                                        end_name=master"-"name" "end_name       ;
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
         }'  ${TMP2} ${TMP3} > ${TMP}

make -k -j -f ${TMP} ${DRYRUN}
#make -j -f ${TMP}

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
