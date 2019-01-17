#!/bin/bash
# Fred Denis -- Jan 2019 -- http://unknowndba.blogspot.com -- fred.denis3@gmail.com
# A script to monitore a RAC / GI 12c using rac-status.sh (https://goo.gl/LwQC1N)
#

#
# Variables
#
REFERENCE=/home/oracle/pythian/rac-status_reference             # The reference file where is saved the good status of your cluster
RACSTATUS=/home/oracle/pythian/rac-status.sh                    # The rac-status.sh script
  EMAILTO="denis@pythian.com"                                                   # The email to send the alert to
      TMP="/tmp/racmontempfile$$"                                               # A tempfile
     TMP2="/tmp/racmontempfile2$$"                                              # Another tempfile


#
# Variables verification
#
if [ ! -f ${REFERENCE} ]                                                                # No reference file, we cannot continue
then
        cat << !
        Cannot find the ${REFERENCE} file. A status reference file is needed to be able to compare the current status of the cluster with
        Please initialize this reference file as below:
        $ $RACSTATUS -a > $REFERENCE
!
        exit 123
fi
if [ ! -x ${RACSTATUS} ]
then
        cat << !
        Cannot find $RACSTATUS or $RACSTATUS is not executable; the rac-status.sh script is needed and needs to be executable to run this script, to fix this issue:
                - Please have a look at https://goo.gl/LwQC1N and downloada rac-status.sh
                - Adjust the RACSTATUS variable on top of this script to point to the location you saved rac-status.sh
                - Make $RACSTATUS executable:
                        $ chmod u+x $RACSTATUS
!
        exit 456
fi

#
# Check the current status of the cluster
#
${RACSTATUS} -a > ${TMP}
if [ $? -ne 0 ]
then
        cat << !
        There was an error executing ${RACSTATUS}, please try executing it manually first and reach out to the author if it doesn't work.
!
fi

#
# Check for any difference between the reference file $REFERENCE and the current status from $TMP
#
diff ${REFERENCE} ${TMP} > ${TMP2} 2>&1
if [ $? -eq 0 ]
then                            # All good
        cat << !
        No change has been identified across the cluster, all good !
!
else                            # Something is wrong, we send an email about it
        cat << !
        The below changes have been identified across the cluster; sending an email about it.
!
        cat ${TMP2}
fi


#
# Delete the tempfiles
#
for F in ${TMP} ${TMP2}
do
        if [ -f ${F} ]
        then
                rm -f ${F}
        fi
done

#*********************************************************************************************************
#                               E N D     O F      S O U R C E
#*********************************************************************************************************
