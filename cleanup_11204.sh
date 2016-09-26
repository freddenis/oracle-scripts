#!/bin/bash
# Fred Denis -- denis@pythian.com -- Feb 2nd 2016
# Purge the files that are not purged by ADR for all the instances on the server (dynamic) :
# -- Use find for traces, core, etc...
# -- Use logrotate for alert.log and listener.log
#

     LOWER_HOST=`hostname -s | tr '[:upper:]' '[:lower:]'`      # Hostname in lower case
            DIR=`dirname $0`/logs/${LOWER_HOST}
  LOGROTATECONF=${DIR}/logrotate_oracle.conf
LOGROTATESTATUS=${DIR}/logrotate_status
        LOGFILE=${DIR}/purge_${LOWER_HOST}.log

. ~/.profile > /dev/null 2>&1

if [ ! -d ${DIR} ]
then
    mkdir -p ${DIR}
fi

cat << !                        | tee -a ${LOGFILE}
#
# Start cleanup `date`
#
!

(for I in ` ps -ef | egrep "(asm|ora)_pmon_" | awk '{print $NF}' | sed 's/.*pmon_//'`
do
    export ORACLE_SID=$I
    export ORAENV_ASK=NO
    . oraenv $I > /dev/null @>&1
    sqlplus -S / as sysdba << END_SQL
    set lines 200   ;
    set head off    ;
    set feed off    ;
    select 'BDUMP' || value || '/alert_${ORACLE_SID}.log' from v\$parameter where name in ('background_dump_dest') ;
    select 'ADUMP' || value from v\$parameter where name in ('audit_file_dest') ;
    select 'CDUMP' || value from v\$parameter where name in ('core_dump_dest') ;
END_SQL
for X in `ps -ef | grep tnslsnr | grep -v grep | sed s'/-inherit//g' | awk '{print $(NF-1) "|" $NF}'`
do
    LISTENER=`echo $X | cut -d "|" -f 2`
     LSNRCTL=`echo $X | cut -d "|" -f 1 | sed s'/tnslsnr/lsnrctl/g'`
    ${LSNRCTL} status ${LISTENER} | grep "Listener Log File" | awk '{print "LDUMP" $NF}' | sed s'/alert.*$/trace\/listener.log/'
done
done) | grep "DUMP" | sort | uniq |\
    awk     -v CONF="$LOGROTATECONF"\
        ' BEGIN {first=1};
         {  if ($1 ~ /^BDUMP/ || $1 ~ /^LDUMP/)
            {   sub(".DUMP", "", $1);
                if (NR == 1)
                {   LIST=$1     ;   }
                else
                {   LIST=LIST" "$1  ;   }
            }
            else {
                    if ($1 ~  /ADUMP/)
                    {
                        sub (".DUMP", "", $1) ;
                        tab[$0] = "*.aud"   ;
                    }
                    if ($1 ~  /CDUMP/)
                    {
                        sub (".DUMP", "", $1) ;
                        tab[$0] = "c*"  ;
                    }
            }
         }
        END {
            print LIST              > CONF  ;
            print "{"               > CONF  ;
            printf  ("\t monthly        \n")        > CONF  ;
            printf  ("\t rotate 7       \n")        > CONF  ;
            printf  ("\t copytruncate   \n")        > CONF  ;
            printf  ("\t missingok      \n")        > CONF  ;
            printf  ("\t compress       \n")        > CONF  ;
            printf  ("\t nodateext      \n")        > CONF  ;
            printf  ("\t notifempty     \n")        > CONF  ;
            print "}"               > CONF  ;

            for (path in tab)
            {
                printf ("find " path " -name \42" tab[path] "\42 -mtime +7 -print0 | xargs -0 rm -fr \n")    ;
                print "if [ $? -eq 0 ]; then echo Purge of  " path " : OK; else echo Rotate of  " path " : KO; fi"     ;
            }
        }
    '   | bash                                                          | tee -a ${LOGFILE}


if [ -f ${LOGROTATECONF} ]
then
    logrotate -d  ${LOGROTATECONF}                                      >> ${LOGFILE} 2>&1      # Show what will be done
    logrotate -s ${LOGROTATESTATUS} ${LOGROTATECONF}                    >> ${LOGFILE} 2>&1      # Rotate logs
    if [ $? -eq 0 ]
    then
        echo "Rotate of " `head -1 ${LOGROTATECONF}` " : OK"            | tee -a ${LOGFILE}
    else
        echo "Rotate of " `head -1 ${LOGROTATECONF}` " : KO"            | tee -a ${LOGFILE}
    fi
else
    echo "Cannot find ${LOGROTATECONF} ! "                              | tee -a ${LOGFILE}
fi

unset ORAENV_ASK

cat << !                                                                | tee -a ${LOGFILE}
#
# End cleanup `date`
#
!


echo "Logfile :" $LOGFILE
                                                                                                       
