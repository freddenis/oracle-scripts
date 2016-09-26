#!/bin/bash
# Fred Denis -- denis@pythian.com -- June 18th 2015
# Launch the purge script from cron
#

         DIR=`dirname $0`
PURGE_SCRIPT=${DIR}/purge_fs.sh
         LOG=${DIR}/log/purge_fs`date +%Y%m%d%H%M`.log

if [ ! -d ${DIR}/log ]
then
        mkdir -p ${DIR}/log
fi

if [ ! -f ${PURGE_SCRIPT} ]
then
        echo "Error " ${PURGE_SCRIPT} " is not there !" | tee -a $LOG
        exit 345
fi

cat << !                                | tee -a $LOG

        S T A R T       P U R G E
!
date                                    | tee -a $LOG
. ${PURGE_SCRIPT}                       | tee -a $LOG
date                                    | tee -a $LOG
. ${PURGE_SCRIPT} -p                    | tee -a $LOG
date                                    | tee -a $LOG
. ${PURGE_SCRIPT}                       | tee -a $LOG
date                                    | tee -a $LOG

cat << !                                | tee -a $LOG
        E N D           P U R G E

!

grep -i error $LOG > /dev/null 2>&1

if [ $? -eq "0" ]
then    # Something went wrong
        echo "Something went wrong, please check the logs"

else    # All went fine
        echo "All went fine !"
fi
