# Fred Denis -- Jan 2019 -- http://unknowndba.blogspot.com -- fred.denis3@gmail.com
#
# A simple script to launch exa-racklayout.sh on many hosts
# - SSH keys deployed to these hosts are needed
# - Fill the "LIST" variable below with your hosts in the user@IP/HOST form
# - OPTION contains the option for exa-racklayout.sh (see https://goo.gl/wv2z5m for more info)
#
# The current version of the script is 20190225
#
# 20190225 - Fred Denis - Initial release
#

# The Exadatas you want to connect to (1 connection per line and form shold be user@IP or user@hostname)
#
LIST="oracle@AN_IP
oracle@ANOTHER_IP"

#
# Variables
#
RACKLAYOUT=exa-racklayout.sh
 DBMACHINE=/opt/oracle.SupportTools/onecommand/databasemachine.xml
       TMP=/tmp/temp$$.txt
    OPTION=" -s "		# exa-racklayout.sh in its short form (empty U hidden)
#    OPTION=""			# exa-racklayout.sh in its whole form (empty U slots are shown)

#
# Check that exa-racklayout.sh is here
#
if [ ! -x ${RACKLAYOUT} ]
then
	cat << !

	${RACKLAYOUT} does not exist or is not executable; to fix this issue you can:
	- Have a look at https://goo.gl/wv2z5m and download ${RACKLAYOUT}
	- Make it executable :
		$ chmod u+x ${RACKLAYOUT}

!
	exit 123
fi


for X in `echo $LIST`
do
	printf "\033[1;37m%s\033[m" "Connecting to ... ${X} "
	scp -q ${X}:${DBMACHINE} ${TMP}
	if [ $? -eq 0 ]
	then
		printf "\t\033[1;32m%-8s\033[m\n" "OK"          ;
		if [[ -f ${TMP} ]]
		then
			./${RACKLAYOUT} ${OPTION} -f ${TMP}
			rm -f ${TMP}
		fi
	else
		printf "\t\033[1;31m%-8s\033[m\n" "Error $?"          ;
	fi
done


#*********************************************************************************************************
#                               E N D     O F      S O U R C E
#*********************************************************************************************************
