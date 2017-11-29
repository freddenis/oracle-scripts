#!/bin/bash
# Fred Denis -- denis@pythian.com -- Nov 23rd 2017
# An Exadata version summary :
# -- has to run as root
# -- the server where this script is started should have the root ssh  keys deployed on all the other servers (DB Nodes, Cells and IB Swicthes)
#
# The current version of the script is 20171129
#

DBMACHINE=/opt/oracle.SupportTools/onecommand/databasemachine.xml       # File where we should find the Exadata model

#
# Few tempfiles
#
         DBS_GROUP=/tmp/dbsgroup$$.tmp
        CELL_GROUP=/tmp/cellgroup$$.tmp
          IB_GROUP=/tmp/ibgroup$$.tmp

#
# Set the ASM env to be able to use some commands (future use)
#
ORACLE_SID=`ps -ef | grep pmon | grep asm | awk '{print $NF}' | sed s'/asm_pmon_//' | egrep "^[+]"`

export ORAENV_ASK=NO
. oraenv > /dev/null 2>&1

#
# Show the Exadata model if possible (if this cluster is an Exadata)
#
if [ -f ${DBMACHINE} ] && [ -r ${DBMACHINE} ]
then
        cat << !

                Cluster is a `grep -i MACHINETYPES ${DBMACHINE} | sed s'/\t*//' | sed -e s':</*MACHINETYPES>::g' -e s'/^ *//' -e s'/ *$//'`

!
else
        printf "\n"
fi


# Fill the tempfiles
        ibhosts | grep db  | sed s'/"//g' | awk '{print $6}'  > ${DBS_GROUP}
        ibhosts | grep cel | sed s'/"//g' | awk '{print $6}'  > ${CELL_GROUP}
        ibswitches                        | awk '{print $10}' > ${IB_GROUP}


(dcli -g ${DBS_GROUP}  -l root imageinfo -ver                                                   | sort
 echo ""
 dcli -g ${CELL_GROUP} -l root imageinfo -ver                                                   | sort
 echo ""
 dcli -g ${IB_GROUP}   -l root version | grep -v BIOS | grep "version:" | awk '{print $1, $NF}' | sort
 echo "")\
        | awk ' BEGIN \
                { FS=":"        ;
                  # some colors
                     COLOR_BEGIN =       "\033[1;"              ;
                       COLOR_END =       "\033[m"               ;
                             RED =       "31m"                  ;
                           GREEN =       "32m"                  ;
                          YELLOW =       "33m"                  ;
                            BLUE =       "34m"                  ;
                            TEAL =       "36m"                  ;
                           WHITE =       "37m"                  ;

                  # Columns size
                        COL_SIZE = 20                           ;
                     NB_PER_LINE = 8                            ;               # Number of items per line (db nodes, cells, IB)

                  # Some variables
                        nb_node  =      0                       ;
                }
                function print_a_line(size)
                {
                        printf("%s", COLOR_BEGIN WHITE)                                                                 ;
                        for (k=1; k<=size;k++) {printf("%s", "-");}                                                     ;
                        printf("%s", COLOR_END"\n")                                                                     ;
                }
                #
                # A function to center the outputs with colors
                #
                function center( str, n, color)
                {       right = int((n - length(str)) / 2)                                                              ;
                        left  = n - length(str) - right                                                                 ;
                        return sprintf(COLOR_BEGIN color "%" left "s%s%" right "s" COLOR_END, "", str, "" )             ;
                }
                {       if ($0 !~ /^$/)
                        {
                                        nb_node++                                                                       ;
                                   db_node[nb_node] = $1                                                                ;
                                db_version[nb_node] = $2                                                                ;

                                while (getline)
                                {
                                        if ($0 ~ /^$/)
                                        {
                                                # A Header
                                                if (db_node[1] ~ /db[0-9]/ )      {printf("%s\n", center("-- Compute nodes",      40,RED))};
                                                if (db_node[1] ~ /cel[0-9]/)      {printf("%s\n", center("-- Storage Servers",    40,RED))};
                                                if (db_node[1] ~ /ib[0-9]/ )      {printf("%s\n", center("-- Infiniband Switches",40,RED))};
                                                printf("\n")                                                    ;
                                                version_ref = db_version[1]                                     ;

                                                for (a=1; a<nb_node; a=a+NB_PER_LINE)
                                                {
                                                        nb_printed = 0                                                  ;

                                                        # Print the node names
                                                        for (i=a; i<=a*NB_PER_LINE; i++)
                                                        {
                                                                if (length(db_node[i]) > 0)
                                                                {
                                                                        printf("%s", center(db_node[i],COL_SIZE,WHITE)) ;
                                                                        nb_printed++                                    ;
                                                                }
                                                        }

                                                        printf("\n")                                                    ;
                                                        print_a_line(COL_SIZE*nb_printed+NB_TO_SHOW)                    ;

                                                        # Print the nodes versions
                                                        for (i=a; i<=a*NB_PER_LINE; i++)
                                                        {
                                                                if (length(db_version[i]) > 0)
                                                                {
                                                                        if (db_version[i] == version_ref) { A_COLOR=BLUE;} else {A_COLOR=TEAL;}
                                                                        printf("%s", center(db_version[i],COL_SIZE,A_COLOR));
                                                                }
                                                        }
                                                        printf("\n")                                                    ;
                                                        print_a_line(COL_SIZE*nb_printed+NB_TO_SHOW)                    ;
                                                        printf("\n\n")                                                  ;
                                                } # END  for (a=1; a<=nb_node; a+=4)

                                                nb_node = 0                                                             ;
                                                delete db_node                                                          ;
                                                delete db_version                                                       ;
                                                break                                                                   ;
                                        }       # END if ($0 ~ /^$/)

                                        nb_node++                                                                       ;
                                           db_node[nb_node] = $1                                                        ;
                                        db_version[nb_node] = $2                                                        ;
                                }
                        } # END  if ($1 ~ /db[0-9]/)
                }'

# Delete tempfiles

if [ -f ${DBS_GROUP} ]  ; then rm -f ${DBS_GROUP}       ; fi
if [ -f ${CELL_GROUP} ] ; then rm -f ${CELL_GROUP}      ; fi
if [ -f ${IB_GROUP} ]   ; then rm -f ${IB_GROUP}        ; fi


#*********************************************************************************************************
#                               E N D     O F      S O U R C E
#*********************************************************************************************************
