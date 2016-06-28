#!/bin/bash
# Fred Denis - fred.denis3@gmail.com - 2016
# Quickly show a status of all running instances over an Exadata cluster
#


      TMP=/tmp/status$$.tmp
DBMACHINE=/opt/oracle.SupportTools/onecommand/databasemachine.xml       # File where we should find the Exadata model as oracle user


#
# Set the ASM env
#
ORACLE_SID=`ps -ef | grep pmon | grep asm | awk '{print $NF}' | sed s'/asm_pmon_//' | egrep "^[+]"`


export ORAENV_ASK=NO
. oraenv > /dev/null 2>&1


#
# Llist of the nodes of the cluster
#
NODES=`olsnodes | awk '{if (NR<2){txt=$0} else{txt=txt","$0}} END {print txt}'`


#
# Show the Exadata model if possible
#
echo ""
if [ -f ${DBMACHINE} ]
then
        echo "Cluster is a " `grep -i MACHINETYPES ${DBMACHINE} | sed -e s':</*MACHINETYPES>::g' -e s'/^ *//' -e s'/ *$//'`
else
        echo "Cannot find ${DBMACHINE} then cannot know the Exadata model."
fi
echo ""


crsctl stat res -p -w "TYPE = ora.database.type" >  $TMP
crsctl stat res -v -w "TYPE = ora.database.type" >> $TMP
        gawk  -v NODES="$NODES" 'BEGIN\
             {  FS="="; split(NODES, nodes, ",") ;
                # some colors
             COLOR_BEGIN =       "\033[1;"                                      ;
               COLOR_END =       "\033[m"                                       ;
                     RED =       COLOR_BEGIN"31m"                               ;
                   GREEN =       COLOR_BEGIN"32m"                               ;
                  YELLOW =       COLOR_BEGIN"33m"                               ;
                    BLUE =       COLOR_BEGIN"34m"                               ;
                   WHITE =       COLOR_BEGIN"37m"                               ;


            OPENREADONLY = WHITE  "Open Read Only   "           COLOR_END       ;
                    OPEN = GREEN  "Open        "                COLOR_END       ;
                    SHUT = YELLOW "Instance Shutdown  "         COLOR_END       ;
                READONLY = YELLOW "Readonly"                    COLOR_END       ;
                ABNORMAL = RED    "Abnormal Termination"        COLOR_END       ;
                UNKNOWN  = BLUE   "         -         "         COLOR_END       ;
                   DUNNO = RED    "?"                           COLOR_END       ;
         ENABLED_MOUNTED = RED    "Enabled/Mounted"             COLOR_END       ;
         ENABLED_NOMOUNT = RED    "Enabled/Nomount"             COLOR_END       ;
                RECONFIG = RED    "Cluster Reconfig  "          COLOR_END       ;
           MOUNTEDCLOSED = RED    "Mounted (Closed)  "          COLOR_END       ;
             }
             {
                # Fill 2 tables with the OH and the version from "crsctl stat res -p -w "TYPE = ora.database.type""
                if ($1 ~ /^NAME/)
               {
                        sub("ora.", "", $2)     ;
                        sub(".db", "", $2)      ;
                        DB=$2                   ;


                        getline; getline        ;
                        if ($1 == "ACL")                # crsctl stat res -p output
                        {
                                if (DB in version == 0)
                                {
                                        while (getline)
                                        {
                                                if ($1 == "ORACLE_HOME")
                                                {       OH=$2                                           ;
                                                        match($2, /1[0-9]\.[0-9]\.[0-9]\.[0-9]/)        ;
                                                        VERSION=substr($2,RSTART,RLENGTH)               ;
                                                }
                                                if ($0 ~ /^$/)
                                                {       version[DB]     = VERSION                       ;
                                                        oh[DB]          = OH                            ;
                                                        break                                           ;
                                                }
                                        }
                                }
                        }
                        if ($1 == "LAST_SERVER")        # crsctl stat res -v output
                        {
                                SERVER = $2     ;
                                while (getline)
                                {
                                        if ($1 == "LAST_SERVER")        {       SERVER = $2             ;       }
                                        if ($1 == "CARDINALITY_ID")     {       card = $2               ;       }
                                        if ($1 == "STATE_DETAILS")      {       sub("STATE_DETAILS=", "", $0)   ;
                                                                                status[DB,SERVER] = $0          ; }
                                        if ($1 == "INSTANCE_COUNT")     {       if (card == $2) { break ;}      }
                                }
                        }
                }       # End of if ($1 ~ /^NAME/)
             }
            END {       # Print a header
                        printf("%1s", WHITE)                                    ;
                        printf("%12s|%10s|", "DB", "Version")                   ;
                        n=asort(nodes)                                          ;                 # sort array nodes
                        for (i = 1; i <= n; i++) {
                                        printf("%20s|", nodes[i]"   ")          ;
                        }
                        printf("\n")                                            ;


                        # a "---" line under the header
                        for (k=1; k<=12+(20*i); k++) {printf("%s", "-");}
                        printf("%s", COLOR_END"\n");


                        m=asorti(version, version_sorted)                       ;
                        for (j = 1; j <= m; j++)
                        {
                                printf("%12s|%10s|", version_sorted[j], version[version_sorted[j]])     ;
                                for (i = 1; i <= n; i++) {
                                        dbstatus = status[version_sorted[j],nodes[i]]                   ;
                                        txt=dbstatus                                                    ;
                                        if (dbstatus == "")                     {txt = UNKNOWN}         ;
                                        if (dbstatus == "Open")                 {txt = OPEN}            ;
                                        if (dbstatus == "Open,Readonly")        {txt = OPENREADONLY}    ;
                                        if (dbstatus == "Instance Shutdown")    {txt = SHUT}            ;
                                        if (dbstatus == "Abnormal Termination") {txt = ABNORMAL}        ;
                                        if (dbstatus == "Mounted (Closed)")     {txt = MOUNTEDCLOSED}   ;
                                        if (dbstatus ~ /^Cluster Reconfiguration/) {txt = RECONFIG}     ;
                                        printf("%30s|", txt)                                            ;
                                }
                                printf("\n");
                        }


                        # a "---" line as a footer
                        for (k=1; k<=12+(20*i); k++) {printf("%s", "-");}
                        printf("%s", COLOR_END"\n");
                }' $TMP


if [ -f ${TMP} ]
then
        rm -f ${TMP}
fi


#*********************************************************************************************************
#                               E N D     O F      S O U R C E
#*********************************************************************************************************