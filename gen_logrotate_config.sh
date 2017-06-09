#!/bin/bash
# Fred Denis -- denis@pythian.com -- June 6th 2017
#
# Generate the logrotate configuration files for the trace alert.log and listener.log of the running instances and listeners
#
# The current version of the script is 20170609
#
# 20170609 -- Fred Denis -- Initial release
#

#DEST="/tmp"			# Target directory where we generate the logrotate configuration files -- to test
DEST="/etc/logrotate.d"		# Real target directory to put the logrotate config files

if [ ! -d ${DEST} ]		# Check that the target directory exists to avoid mistakes
then
	cat << !
	The ${DEST} target directory for the logrotate configuration files does not exist. I cannot continue.
!
exit 123
fi

#
# Generate the alert.log logrotates
#

(for I in `\ps -ef | egrep "(asm|ora)_pmon_" | awk '{print $NF}' | sed 's/.*pmon_//'`
do
	DB=`echo ${I} | sed s/'[1-9]$//'`

	#
	# As oratab only contains the databases names and not the instances names (except for ASM), we have to use this worakound to properly set the env
	#
	if [[ ${I} == *"ASM"* ]]
	then
		. oraenv <<< ${I} 	> /dev/null 2>&1
	else
		. oraenv <<< ${DB}	> /dev/null 2>&1
		export ORACLE_SID=${I}
	fi

	#
	# Generate the whole alert.log path
	#
	sqlplus -S / as sysdba << END_SQL
	set lines 200   ;
	set head off    ;
	set feed off    ;
	select '${I}:' || value || '/alert_${ORACLE_SID}.log' from v\$parameter where name in ('background_dump_dest') ;
END_SQL
done) | grep -v "^$" |\
	awk -v dest="$DEST" ' BEGIN {FS=":"}
		{	OUT=dest"/logrotate_"$1  ;
			print $2 " {" 			>  OUT ;
			print "\tdaily"			>> OUT ;
			print "\trotate 15" 		>> OUT ;
			print "\tcompress" 		>> OUT ;
			print "\tcopytruncate" 		>> OUT ;
			print "\tdelaycompress" 	>> OUT ;
			print "\tcreate 0640 root dba"	>> OUT ;
			print "\tnotifempty" 		>> OUT ;
			print "}" 			>> OUT ;

			print OUT " configuration file has been generated."
		}
	    '

#
# Generate the listeners logrotates config files
#

# We need to have the CRS env to check the listeners
. oraenv <<< `\ps -ef | grep asm_pmon | grep -v grep | sed s'/^.*_//g'` > /dev/null 2>&1

for L in `\ps -ef | grep tnslsnr | grep -v grep | sed s'/-.*$//g' | awk '{print $NF}'`
do
	OUT=${DEST}/"logrotate_"${L}
	LSRN_LOG=`lsnrctl status ${L} | grep "Listener Log File" | awk '{print $NF}' | sed s/'alert.*$/trace\//'``echo ${L} | tr '[:upper:]' '[:lower:]'`".log"
	echo $LSRN_LOG " {"		>  ${OUT}
	cat << !			>> ${OUT}
	daily
	rotate 15
	compress
	copytruncate
	delaycompress
	create 0640 root dba
	notifempty
}
!
	echo ${OUT} has been generated
done


#***********************************************************************************************#
#				E N D      O F      S O U R C E					#
#***********************************************************************************************#

