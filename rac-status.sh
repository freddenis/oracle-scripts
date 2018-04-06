#!/bin/bash
# Fred Denis -- Jan 2016 -- http://unknowndba.blogspot.com -- fred.denis3@gmail.com
#
#
# Quickly shows a status of all running instances accross a 12c cluster
# The script just need to have a working oraenv
#
# Please have a look at https://unknowndba.blogspot.com/2018/04/rac-statussh-overview-of-your-rac-gi.html for some details and screenshots
# The script last version can be downloaded here : https://raw.githubusercontent.com/freddenis/oracle-scripts/master/rac-status.sh
#
# The current script version is 20180227
#
# History :
#
# 20180227 - Fred Denis - Make the the size of the DB column dynamic to handle very long database names (Thanks Michael)
#                       - Added a (P) for Primary databases and a (S) for Stanby for color blind people who
#                         may not see the difference between white and red (Thanks Michael)
# 20180225 - Fred Denis - Make the multi status like "Mounted (Closed),Readonly,Open Initiated" clear in the table by showing only the first one
# 20180205 - Fred Denis - There was a version alignement issue with more than 10 different ORACLE_HOMEs
#                       - Better colors for the label "White for PRIMARY, Red for STANBY"
# 20171218 - Fred Denis - Modify the regexp to better accomodate how the version can be in the path (cannot get it from crsctl)
# 20170620 - Fred Denis - Parameters for the size of the columns and some formatting
# 20170619 - Fred Denis - Add a column type (RAC / RacOneNode / Single Instance) and color it depending on the role of the database
#                         (WHITE for a PRIMARY database and RED for a STANDBY database)
# 20170616 - Fred Denis - Shows an ORACLE_HOME reference in the Version column and an ORACLE_HOME list below the table
# 20170606 - Fred Denis - A new 12cR2 GI feature now shows the ORACLE_HOME in the STATE_DETAILS column from "crsctl -v"
#                       - Example :     STATE_DETAILS=Open,HOME=/u01/app/oracle/product/11.2.0.3/dbdev_1 instead of STATE_DETAILS=Open in 12cR1
# 20170518 - Fred Denis - Add  a readable check on the ${DBMACHINE} file - it happens that it exists but is only root readable
# 20170501 - Fred Denis - First release
#

      TMP=/tmp/status$$.tmp                                             # A tempfile
DBMACHINE=/opt/oracle.SupportTools/onecommand/databasemachine.xml       # File where we should find the Exadata model as oracle user

#
# Set the ASM env to be able to use crsctl commands
#
ORACLE_SID=`ps -ef | grep pmon | grep asm | awk '{print $NF}' | sed s'/asm_pmon_//' | egrep "^[+]"`

export ORAENV_ASK=NO
. oraenv > /dev/null 2>&1

#
# List of the nodes of the cluster
#
NODES=`olsnodes | awk '{if (NR<2){txt=$0} else{txt=txt","$0}} END {print txt}'`

#
# Show the Exadata model if possible (if this cluster is an Exadata)
#
if [ -f ${DBMACHINE} ] && [ -r ${DBMACHINE} ]
then
        cat << !

                Cluster is a `grep -i MACHINETYPES ${DBMACHINE} | sed -e s':</*MACHINETYPES>::g' -e s'/^ *//' -e s'/ *$//'`

!
else
        printf "\n"
fi

crsctl stat res -p -w "TYPE = ora.database.type" >  $TMP
crsctl stat res -v -w "TYPE = ora.database.type" >> $TMP
        awk  -v NODES="$NODES" 'BEGIN\
        {             FS = "="                          ;
                      split(NODES, nodes, ",")          ;       # Make a table with the nodes of the cluster
                # some colors
             COLOR_BEGIN =       "\033[1;"              ;
               COLOR_END =       "\033[m"               ;
                     RED =       "31m"                  ;
                   GREEN =       "32m"                  ;
                  YELLOW =       "33m"                  ;
                    BLUE =       "34m"                  ;
                    TEAL =       "36m"                  ;
                   WHITE =       "37m"                  ;

                 UNKNOWN = "-"                          ;       # Something to print when the status is unknown

                # Default columns size
                COL_NODE = 18                           ;
                  COL_DB = 12                           ;
                 COL_VER = 15                           ;
                COL_TYPE = 14                           ;
        }

        #
        # A function to center the outputs with colors
        #
        function center( str, n, color)
        {       right = int((n - length(str)) / 2)                                                              ;
                left  = n - length(str) - right                                                                 ;
                return sprintf(COLOR_BEGIN color "%" left "s%s%" right "s" COLOR_END "|", "", str, "" )         ;
        }

        #
        # A function that just print a "---" white line
        #
        function print_a_line()
        {
                printf("%s", COLOR_BEGIN WHITE)                                                                 ;
                for (k=1; k<=COL_DB+COL_VER+(COL_NODE*n)+COL_TYPE+n+3; k++) {printf("%s", "-");}                ;       # n = number of nodes
                printf("%s", COLOR_END"\n")                                                                     ;
        }
        {
               # Fill 2 tables with the OH and the version from "crsctl stat res -p -w "TYPE = ora.database.type""
               if ($1 ~ /^NAME/)
               {
                        sub("^ora.", "", $2)                                                                    ;
                        sub(".db$", "", $2)                                                                     ;
                        DB=$2                                                                                   ;
                        if (length(DB)+2 > COL_DB)              # Adjust the size of the DB column in case of very long DB name
                        {                                       # +2 is to have 1 blank character before and after the DB name
                                COL_DB = length(DB)+2                                                           ;
                        }

                        getline; getline                                                                        ;
                        if ($1 == "ACL")                        # crsctl stat res -p output
                        {
                                if (DB in version == 0)
                                {
                                        while (getline)
                                        {
                                                if ($1 == "ORACLE_HOME")
                                                {                    OH = $2                                    ;
                                                        match($2, /1[0-9]\.[0-9]\.?[0-9]?\.?[0-9]?/)            ;       # Grab the version from the OH path)
                                                                VERSION = substr($2,RSTART,RLENGTH)             ;
                                                }
                                                if ($1 == "DATABASE_TYPE")                                              # RAC / RACOneNode / Single Instance are expected here
                                                {
                                                             dbtype[DB] = $2                                    ;
                                                }
                                                if ($1 == "ROLE")                                                       # Primary / Standby expected here
                                                {              role[DB] = $2                                    ;
                                                }
                                                if ($0 ~ /^$/)
                                                {           version[DB] = VERSION                               ;
                                                                 oh[DB] = OH                                    ;

                                                        if (!(OH in oh_list))
                                                        {
                                                                oh_ref++                                        ;
                                                            oh_list[OH] = oh_ref                                ;
                                                        }
                                                        break                                                   ;
                                                }
                                        }
                                }
                        }
                        if ($1 == "LAST_SERVER")        # crsctl stat res -v output
                        {           NB = 0      ;       # Number of instance as CARDINALITY_ID is sometimes irrelevant
                                SERVER = $2     ;
                                while (getline)
                                {
                                        if ($1 == "LAST_SERVER")        {       SERVER = $2                     ;}
                                        if ($1 == "STATE_DETAILS")      {       NB++                            ;       # Number of instances we came through
                                                                                sub("STATE_DETAILS=", "", $0)   ;
                                                                                status[DB,SERVER] = $0          ; }
                                        if ($1 == "INSTANCE_COUNT")     {       if (NB == $2) { break           ;}}
                                }
                        }
                }       # End of if ($1 ~ /^NAME/)
            }
            END {       # Print a header
                        printf("%s", center("DB"        , COL_DB, WHITE))                                       ;
                        printf("%s", center("Version"   , COL_VER, WHITE))                                      ;
                        n=asort(nodes)                                                                          ;       # sort array nodes
                        for (i = 1; i <= n; i++) {
                                printf("%s", center(nodes[i], COL_NODE, WHITE))                                 ;
                        }
                        printf("%s", center("DB Type"    , COL_TYPE, WHITE))                                    ;
                        printf("\n")                                                                            ;


                        # a "---" line under the header
                        print_a_line()                                                                          ;

                        m=asorti(version, version_sorted)                                                       ;
                        for (j = 1; j <= m; j++)
                        {
                                printf("%s", center(version_sorted[j]   , COL_DB, WHITE))                       ;                       # Database name
                                printf(COLOR_BEGIN WHITE " %-8s" COLOR_END, version[version_sorted[j]], COL_VER, WHITE)         ;       # Version
                                printf(COLOR_BEGIN WHITE "%6s" COLOR_END"|"," ("oh_list[oh[version_sorted[j]]] ") ")            ;       # OH id

                                for (i = 1; i <= n; i++) {
                                        dbstatus = status[version_sorted[j],nodes[i]]                           ;

                                        sub(",HOME=.*$", "", dbstatus)                                          ;       # Manage the 12cR2 new feature, check 20170606 for more details
                                        sub("),.*$", ")", dbstatus)                                             ;       # To make clear multi status like "Mounted (Closed),Readonly,Open Initiated"

                                        #
                                        # Print the status here, all that are not listed in that if ladder will appear in RED
                                        #
                                        if (dbstatus == "")                     {printf("%s", center(UNKNOWN , COL_NODE, BLUE         ))      ;}      else
                                        if (dbstatus == "Open")                 {printf("%s", center(dbstatus, COL_NODE, GREEN        ))      ;}      else
                                        if (dbstatus == "Open,Readonly")        {printf("%s", center(dbstatus, COL_NODE, WHITE        ))      ;}      else
                                        if (dbstatus == "Readonly")             {printf("%s", center(dbstatus, COL_NODE, YELLOW       ))      ;}      else
                                        if (dbstatus == "Instance Shutdown")    {printf("%s", center(dbstatus, COL_NODE, YELLOW       ))      ;}      else
                                                                                {printf("%s", center(dbstatus, COL_NODE, RED          ))      ;}
                                }
                                #
                                # Color the DB Type column depending on the ROLE of the database (20170619)
                                #
                                if (role[version_sorted[j]] == "PRIMARY") { ROLE_COLOR=WHITE ; ROLE_SHORT=" (P)"; } else { ROLE_COLOR=RED ; ROLE_SHORT=" (S)" }
                                printf("%s", center(dbtype[version_sorted[j]] ROLE_SHORT, COL_TYPE, ROLE_COLOR))           ;

                                printf("\n")                                                                    ;
                        }

                        # a "---" line as a footer
                        print_a_line()                                                                          ;

                        #
                        # Print the OH list and a legend for the DB Type colors underneath the table
                        #
                        printf ("\n\t%s", "ORACLE_HOME references listed in the Version column :")              ;

                        # Print the output in many lines for code visibility
                        #printf ("\t\t%s\t", "DB Type column =>")                                               ;       # Most likely useless
                        printf ("\t\t\t\t\t")                                                                   ;
                        printf("%s" COLOR_BEGIN WHITE "%-6s" COLOR_END    , "Primary : ", "White")              ;
                        printf("%s" COLOR_BEGIN WHITE "%s"   COLOR_END"\n", "and "      , "(P)"  )              ;
                        printf ("\t\t\t\t\t\t\t\t\t\t\t\t")                                                     ;
                        printf("%s" COLOR_BEGIN RED "%-6s"   COLOR_END    , "Standby : ", "Red"  )              ;
                        printf("%s" COLOR_BEGIN RED "%s"     COLOR_END"\n", "and "      , "(S)" )               ;


                        for (x in oh_list)
                        {
                                printf("\t\t%s\n", oh_list[x] " : " x) | "sort"                                 ;
                        }
        }' $TMP

        printf "\n"

if [ -f ${TMP} ]
then
        rm -f ${TMP}
fi

#*********************************************************************************************************
#                               E N D     O F      S O U R C E
#*********************************************************************************************************
