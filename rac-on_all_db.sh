#!/bin/bash
#
# Fred Denis -- Nov 2017 -- http://unknowndba.blogspot.com -- fred.denis3@gmail.com
#
# Execute a SQL command on all databases wherever they have an instance opened
# -- The node where this script is executed should have ssh key deployed to all the other database nodes
# -- oraenv should be working on every server
# -- Look for "Query customization" to customize your query
#
# More information here : https://unknowndba.blogspot.com.au/2018/04/rac-onalldbsh-easily-execute-query-on.html
#
# Version of the script is 20180318
#

#
# Set the default output to 90% of the screen size
#
COLS=$(printf %.f $(bc <<< "`tput cols`*.9"))

#
# If for any reason we couldn't get the number of cols, we set it to 120
#
if ! [[ $COLS =~ ^[0-9]+$ ]]
then
        COLS=120         # Size of the output
fi

COLS=120        # Not sure the above dynamic output is useful here, set COLS to 120 for now
                # Comment this line if you want the output to be dynamic

#
# Set the ASM env to be able to use crsctl commands
#
ORACLE_SID=`ps -ef | grep pmon | grep asm | awk '{print $NF}' | sed s'/asm_pmon_//' | egrep "^[+]"`

export ORAENV_ASK=NO
. oraenv > /dev/null 2>&1


for X in `crsctl stat res -v -w "TYPE = ora.database.type" |\
        awk ' BEGIN {FS="="}
             {
                if (($1 ~ /^NAME/) && ($0 ~ //))
                {
                        sub("^ora.", "", $2)                                                            ;
                        sub(".db$" , "", $2)                                                            ;
                        DB=$2                                                                           ;
                        while(getline)
                        {
                                if (($1 ~ /STATE/) && ($2 ~/ONLINE/))
                                {
                                        gsub (".*on ",  "", $2)                                         ;
                                        print DB"|"$2                                                   ;
                                        next                                                            ;
                                }
                        }
                }
            }'`
do
              DB=`echo $X | awk -F "|" '{print $1}'`
          SERVER=`echo $X | awk -F "|" '{print $2}'`
        INSTANCE=${DB}`echo "${SERVER: -1}"`

        printf "\n\n\t\t\033[1;37m%30s\033[m\n" "Query Result on $INSTANCE@$SERVER"

        (ssh -q -o batchmode=yes oracle@${SERVER}  << END_SSH 2> /dev/null
                . oraenv <<< ${DB} > /dev/null 2>&1
                export ORACLE_SID=${INSTANCE}
                sqlplus -S / as sysdba << END_SQL
                set lines       $COLS                                                                   ;

                --------------------------------
                -- Query customization        --
                --------------------------------

                set echo        off                                                                     ;
                set term        off                                                                     ;
                set wrap        on                                                                      ;
                col name        for a50                                                                 ;
                col value       for a60                                                                 ;
                col host_name   for a26                                                                 ;
                col instance_name for a18                                                               ;
                set pages       5000                                                                    ;
                alter session set nls_date_format='DD/MM/YYYY HH24:MI:SS'                               ;
                select instance_name, host_name, version, sysdate from v\\\$instance                    ;
                -- select name, value from v\\\$parameter where name like '%exafusion%'                 ;
                select name, value from v\\\$parameter order by name                                    ;

                --------------------------------
                -- End of query customization --
                --------------------------------
END_SQL
END_SSH
)        | grep -v logout | grep -v altered | grep -v profile | tail -n +3 \
         | awk -v COLS="$COLS"    ' BEGIN\
                                  {     # some colors
                                     COLOR_BEGIN =       "\033[1;"                                      ;
                                       COLOR_END =       "\033[m"                                       ;
                                             RED =       "31m"                                          ;
                                           GREEN =       "32m"                                          ;
                                          YELLOW =       "33m"                                          ;
                                            BLUE =       "34m"                                          ;
                                            TEAL =       "36m"                                          ;
                                           WHITE =       "37m"                                          ;

                                        print_a_line()                                                  ;
                                  }
                                  function print_a_line()
                                  {
                                        printf("%s", COLOR_BEGIN BLUE)                                  ;
                                        for (k=1; k<3    ; k++) {printf("%s", " ")}                     ;
                                        for (k=3; k<=COLS; k++) {printf("%s", "-")}                     ;
                                        printf("%s\n", COLOR_END)                                       ;
                                  }
                                  {
                                        printf(COLOR_BEGIN BLUE " %1s" COLOR_END "%-118s\n", "|\t", $0) ;
                                  }
                                  END\
                                  {     print_a_line()                                                  ;
                                  }
                                '
done

#*******************************************************************************************************#
#                               E N D     O F      S O U R C E                                          #
#*******************************************************************************************************#
