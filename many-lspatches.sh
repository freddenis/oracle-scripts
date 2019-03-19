#!/bin/bash
# Fred Denis -- March 2019
#


LSPATCHES=/tmp/lspatches.sh
  OH_LIST=/tmp/oh_list


for X in `cat $OH_LIST | awk '{print $3"|"$4}'`
do
	   OH=`echo $X | awk -F "|" '{print $1}'`
   PREV_OWNER=$OWNER
	OWNER=`echo $X | awk -F "|" '{print $2}'`

	if [[ "$OWNER" = "''" ]]
	then
		OWNER=$PREV_OWNER
	fi
#	printf "%s%s%s\n" $OH, $OWNER $PREV_OWNER

	sudo su - $OWNER << END_SU
	$LSPATCHES -g $OH
END_SU
done
