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
    IN=json.txt                 # JSON input file
   TMP=/tmp/fictemp$$           # A tempfile

# To specify a special job -- to be replaced by getopts
MASTER="$1"
if [[ -z $1 ]] 
then
        MASTER="."
fi

python -m json.tool ${IN} | sed s'/[",]//g' | sed s'/ *//' |\
        awk -v MASTER="${MASTER}"\
             'BEGIN {   FS=":";
                        srand() ;
                    }
             function print_txt_ts(in_txt)
             {  # Print a "@echo <TXT> <TIMESTAMP>" line
                        printf("\t%s\n", "@echo -e \"" in_txt  "\""" $(TS)")             ;
                        #printf("\t%s\n", "@echo -e \"" in_txt "\"" $(TS)")             ;
             }
             { if (($1 == "name") && ($2 ~ MASTER))
                {       master=tolower($2)                                      ;
                        gsub (" ", "", master)                                  ;

                        printf ("%s\n", "TS := `/bin/date \"+%Y-%m-%d-%H-%M-%S\"`")             ;
                        printf ("%s: %s\n", "done", "end-"master)             ;
                        printf("%s:\n", master)
                        #printf("\t%s\n", "echo \"starting " master "\" && sleep 1")             ;
                        #printf("\t%s\n", "@echo \"Begin " master "\""" $(TS)")             ;
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
                                                        #printf("\t%s\n", "echo \"Starting............. "name"\" && sleep 5")            ;
                                                        #printf("\t%s\n", "echo -e \"Starting............. "name"\" && sleep 5")            ;
                                                        print_txt_ts("\\tBegin "master"-"name )   ;
                                                        x=int((rand()*100));
                                                        if (x>60){x=x-60};
                                                        print_txt_ts("\\t"master"-"name " sleeps for " x " seconds" )   ;
                                                        printf("\t%s\n", "sleep " x)                    ;
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
                                        #printf("\t%s\n", "echo all done && sleep 1")            ;
                                        printf("\t%s\n", "@echo \"End " master "\""" $(TS)")    ;
                                        printf ("\n")                                           ;

                                        break                                                   ;
                                }
                        }
                }
             }
            ' > ${TMP}
#cat $TMP
make -j -f ${TMP}

if [[ -f ${TMP} ]] 
then
        rm -f ${TMP}
fi


#****************************************************************#
#*              E N D      O F      S O U R C E                 *#
#****************************************************************#
