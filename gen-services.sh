#!/bin/bash
#
#

RAC_STATUS="rac-status.sh"

if [[ ! -f ${RAC_STATUS} ]]
then
cat << !
	Cannot find ${RAC_STATUS}, please get it from http://bit.ly/2XEXa6j (doc is http://bit.ly/2MFkzDw)
!
	exit 666
fi

# Options
while getopts "n:w:h" OPT; do
        case ${OPT} in
        n)         N=${OPTARG}									;;
        w)      WHAT=${OPTARG}                                                             	;;
        h)         usage                                                                        ;;
        \?)        echo "Invalid option: -$OPTARG" >&2; usage                                   ;;
        esac
done

if [[ -n ${N} ]]
then
	NODE=$N
else
	NODE=`hostname -s`
fi
NODE_ID=`echo "${NODE: -1}"`

if [[ -z ${WHAT} ]]
then
	WHAT="disable"
fi

./${RAC_STATUS} -n -s -u | sed s'/ *//g' |\
	awk -F "|" -v NODE="$NODE" -v NODE_ID="$NODE_ID" -v WHAT="$WHAT" '\
	{	if ($0 ~  /----------------/)
		{	print "### " WHAT  " ###"		;
			while (getline)
			{	COL=NODE_ID+2				;
				if ($1 != "")
				{
					DB=$1				;
				}
				if ($COL == "Online")
				{
					print "srvctl "WHAT" service -d " DB " -s " $2 " -n " NODE 
				}
				if ($0 ~ /----------------/)
				{	printf("\n")			;
					break				;
				}
			}
		}
	}'

#*********************************************************************************************************
#                               E N D     O F      S O U R C E
#*********************************************************************************************************
