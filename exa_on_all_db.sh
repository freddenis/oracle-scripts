#!/bin/bash
# Fred Denis -- denis@pythian.com -- Mov 21st 2017 -- CR 1188842
# Execute a SQL command on all databases wherever they have an instance opened
# -- The node where this script is executed should have ssh key deployed to all the other database nodes
# -- oraenv should be working on every server
#


#
# Set the ASM env to be able to use crsctl commands
#
ORACLE_SID=`ps -ef | grep pmon | grep asm | awk '{print $NF}' | sed s'/asm_pmon_//' | egrep "^[+]"`

export ORAENV_ASK=NO
. oraenv > /dev/null 2>&1


for X in `crsctl stat res -v -w "TYPE = ora.database.type" |\
        awk ' BEGIN {FS="="}
             {
                if ($1 ~ /^NAME/)
                {
                        sub("^ora.", "", $2)             ;
                        sub(".db$", "", $2)              ;
                        DB=$2                           ;
                        while(getline)
                        {
                                if (($1 ~ /STATE/) && ($2 ~/ONLINE/))
                                {
                                        gsub (".*on ",  "", $2);
                                        print DB"|"$2   ;
                                        next    ;
                                }
                        }
                }
            }'`
do
            DB=`echo $X | awk -F "|" '{print $1}'`
        SERVER=`echo $X | awk -F "|" '{print $2}'`
        INSTANCE=${DB}`echo "${SERVER: -1}"`

#       echo "=>" $DB "=>" $SERVER "=>"$INSTANCE
        ssh -q -o batchmode=yes oracle@${SERVER}  << END_SSH 2> /dev/null | grep -v logout | grep -v altered | grep -v profile
                . oraenv <<< ${DB} > /dev/null 2>&1
                export ORACLE_SID=${INSTANCE}
                sqlplus -S / as sysdba << END_SQL
                set echo off    ;
                set term off    ;
                col name for a30        ;
                col value for a60       ;
                set lines 200           ;
                alter session set nls_date_format='DD/MM/YYYY HH24:MI:SS' ;
                select instance_name, version, sysdate from v\\\$instance ;
                select name, value from v\\\$parameter where name like '%exafusion%' ;
END_SQL
END_SSH
done
