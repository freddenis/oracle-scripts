#!/bin/bash
#set -x
# Pythian -- CR 1186213
#
# Current version of the script is 20180305
#
#
# 20180305 - Fred Denis - Added timings when only 3 steps are needed
#
# 20180228 - Fred Denis - Starting to work on the subject :
#			    Remove -x when starting the script -- no more needed, we would use it again if needed, it polutes the logs
#			    Add CR number the subject has been working on  for a while
#			    Add some text in the logs like "Step 1 : XXX: to have more visible logs
#			    Add a test to check if the script is already running and then do not start a second one
#

PATH=$PATH:/usr/local/bin
ORAENV_ASK=NO
ORACLE_SID=$1

export ORAENV_ASK ORACLE_SID PATH

. /usr/local/bin/oraenv


#
# Check if another process is running then we do not start one more
#

if [[ `ps -ef | grep oracle_log_management.sh | grep $ORACLE_SID | grep -v grep | wc -l` -ge 4 ]]
then
	cat << !
	Log management already running, won't start a new one !
!
	ps -ef | grep oracle_log_management.sh | grep -v grep | wc -l
	ps -ef | grep oracle_log_management.sh | grep -v grep
	exit 123
else
        ps -ef | grep oracle_log_management.sh | grep -v grep | wc -l
        ps -ef | grep oracle_log_management.sh | grep -v grep
fi

filecontent=( `cat $2 `)
log_cnt=`cat $2 | wc -l`

if [[ $log_cnt -gt 1 ]]
then

sqlplus / as sysdba << EOF
set serveroutput on;
set timing on
select name from v\$database;

prompt Start steps

prompt Step 1 : init_log_temp
exec DBADMIN.MANAGE_ORACLE_LOGS.init_log_temp;

prompt Step 2 : manage_alert_log
exec DBADMIN.manage_oracle_logs.manage_alert_log('${filecontent[0]}','alert_${ORACLE_SID}_err.txt');

prompt Step 3 : manage_listener_log_a
exec DBADMIN.manage_oracle_logs.manage_listener_log('${filecontent[1]}','listener_a','listener_a_err.txt');

prompt Step 4 : manage_listener_log_b
exec DBADMIN.manage_oracle_logs.manage_listener_log('${filecontent[2]}','listener_b','listener_b_err.txt');

prompt Step 5 : manage_listener_log_d
exec DBADMIN.manage_oracle_logs.manage_listener_log('${filecontent[3]}','listener_d','listener_d_err.txt');

prompt Step 6 : manage_listener_log_e
exec DBADMIN.manage_oracle_logs.manage_listener_log('${filecontent[4]}','listener_e','listener_e_err.txt');

prompt Step 7 : clean_alert_log
exec DBADMIN.manage_oracle_logs.clean_alert_log(90);

prompt Step 8 : clean_listener_log
exec DBADMIN.manage_oracle_logs.clean_listener_log(90);

prompt End steps
exit
EOF

# Call logscan
# =====================
cd /u01/app/oracle/dba/scr
export logscan_cfg=logscan_oracle_log_mngm.cfg

# check for logscan cfg file updates
# ---------------------
if [[ -f /shares/dba/${logscan_cfg} ]]
   then
   if [[ /shares/dba/${logscan_cfg} -nt ${logscan_cfg} ]]
      then
      cp ${logscan_cfg} ${logscan_cfg}.`date +%Y%m%d_%H%M`
      cp /shares/dba/${logscan_cfg} ./${logscan_cfg}
   fi
fi

/u01/app/oracle/dba/scr/logscan.sh y y /u01/app/oracle/dba/log/alert_${ORACLE_SID}_err.txt ${logscan_cfg}
/u01/app/oracle/dba/scr/logscan.sh y y /u01/app/oracle/dba/log/listener_a_err.txt ${logscan_cfg}
/u01/app/oracle/dba/scr/logscan.sh y y /u01/app/oracle/dba/log/listener_b_err.txt ${logscan_cfg}
/u01/app/oracle/dba/scr/logscan.sh y y /u01/app/oracle/dba/log/listener_d_err.txt ${logscan_cfg}
/u01/app/oracle/dba/scr/logscan.sh y y /u01/app/oracle/dba/log/listener_e_err.txt ${logscan_cfg}

else

sqlplus / as sysdba << EOF
set serveroutput on;
select name from v\$database;
set timing on ;

prompt Step 1 : init_log_temp
exec DBADMIN.MANAGE_ORACLE_LOGS.init_log_temp;

prompt Step 2 : manage_alert_log
exec DBADMIN.manage_oracle_logs.manage_alert_log('${filecontent[0]}','alert_${ORACLE_SID}_err.txt');

prompt Step 3 : clean_alert_log
exec DBADMIN.manage_oracle_logs.clean_alert_log(90);
exit
EOF

# Call logscan
#  =====================
cd /u01/app/oracle/dba/scr
/u01/app/oracle/dba/scr/logscan.sh y y /u01/app/oracle/dba/log/alert_${ORACLE_SID}_err.txt logscan_oracle_log_mngm.cfg

fi
