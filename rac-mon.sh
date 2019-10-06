#!/bin/bash
# Fred Denis -- Jan 2019 -- http://unknowndba.blogspot.com -- fred.denis3@gmail.com
#
# A script to monitor a RAC / GI 12c using rac-status.sh (https://goo.gl/LwQC1N)
# More information on the script on https://goo.gl/EwDeKn
# See the usage function or use the -h option for more details
#
# The current version of the script is 20190913
#
# 20190913 - Fred Denis - rac-status options can be passed as a parameter (-o)
# 20190118 - Fred Denis - Initial Release
#

#
# Variables
#
       REFERENCE=~/rac-status_reference                 # The reference file where is saved the good status of your cluster
       RACSTATUS=~/rac-status.sh                        # The rac-status.sh script location
             TMP="/tmp/racmontempfile$$"                # A tempfile
            TMP2="/tmp/racmontempfile2$$"               # Another tempfile
 AUTO_CREATE_REF="Yes"                                  # If yes, create the reference file if it does not exist (for first execution)
         OPTIONS="-a -w0"                               # Options to use with rac-status.sh
                                                        # If not yes, prompt about this and exit
#
# Email alerting
#
         EMAILTO="youremail@company.com"                # The email to send the alert to
EMAIL_ON_FAILURE="No"                                   # Default behavior to send an email if an error is detected (-e option) - put Yes to always send emails
EMAIL_ON_SUCCESS="No"                                   # Default behavior to send an email even if no error is detected (-s option) - put Yes to always send emails
FAILURE_SUBJECT="Error : Cluster status at "`date`      # Subject of the email sent
SUCCESS_SUBJECT="OK : Cluster status at "`date`         # Subject of the email sent

#
# usage function
#
usage()
{
printf "\n\033[1;37m%-8s\033[m\n" "NAME"                ;
cat << END
        `basename $0` - A quick and efficient RAC/GI 12c monitoring tool based on rac-status.sh (https://goo.gl/LwQC1N)
END

printf "\n\033[1;37m%-8s\033[m\n" "SYNOPSIS"            ;
cat << END
        $0 [-e] [-s] [-h]
END

printf "\n\033[1;37m%-8s\033[m\n" "DESCRIPTION"         ;
cat << END
        `basename $0` needs the rac-status.sh script to be downloaded and working (https://goo.gl/LwQC1N)

        `basename $0` executes rac-status.sh $OPTIONS and compares its output with a previously saved good status of your cluster
        If no reference file exists, `basename $0` will create it for you at the location pointed by the REFERENCE variable.

        If `basename $0` finds differences betwen the current status of the cluster and the good status from the reference file,
        you will be prompted about it and `basename $0` will exit 1. If no difference found, you will be prompted about it and `basename $0` will exit 0.

        `basename $0` can also send emails about this depending on the -e and -s option as well as the EMAIL_ON_FAILURE and EMAIL_ON_SUCCESS variables.
END

printf "\n\033[1;37m%-8s\033[m\n" "OPTIONS"             ;
cat << END
        -e      Sends an email to the email(s) defined in the EMAILTO parameter if an issue has been detected in the cluster
        -s      Sends an email to the email(s) defined in the EMAILTO parameter on success (even if no error has been detected)

                If you want to modify the script default to always send emails and not have to specify -e or -s,
                just change the values of these parameters on top of the script like this:
                        EMAIL_ON_FAILURE="Yes"
                        EMAIL_ON_SUCCESS="Yes"
        -o      Specify the options to use for rac-status
                        $ ./rac-mon.sh -s -o "-a -w0"

        -h      Show this help

END

exit 567
}
#
# Show the version of the script (-V)
#
show_version()
{
        VERSION=`awk '{if ($0 ~ /^# 20[0-9][0-9][0-1][0-9]/) {print $2; exit}}' $0`
        printf "\n\t\033[1;36m%s\033[m\n" "The current version of "`basename $0`" is "$VERSION"."          ;
}
#
# Command line options
#
while getopts "esho:V" OPT; do
        case ${OPT} in
        e)         EMAIL_ON_FAILURE="Yes"                               ;;
        s)         EMAIL_ON_SUCCESS="Yes"                               ;;
        o)                  OPTIONS="${OPTARG}"                         ;;
        V)      show_version; exit 567                                  ;;
        h)         usage                                                ;;
        \?)        echo "Invalid option: -$OPTARG" >&2; usage           ;;
        esac
done

#
# Variables verification
#
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
if [ ! -f ${REFERENCE} ]                                                                # No reference file, we cannot continue
then
        if [ "${AUTO_CREATE_REF}" = "Yes" ]
        then    # Reference file does not exist, we create it
                printf "\t%s" "No reference file found at $REFERENCE, creating it . . ."
                $RACSTATUS ${OPTIONS} > $REFERENCE
                if [ $? -eq 0 ]
                then
                        printf "\t\033[1;32m%-8s\033[m\n" "OK"          ;
                else
                        printf "\t\033[1;31m%-8s\n" "Error $ERR"          ;
                        printf "%s\033[m\n" "Could not create $REFERENCE using $RACSTATUS ${OPTIONS} > $REFERENCE; cannot continue."
                        exit 444
                fi
        else
        cat << !
                Cannot find the ${REFERENCE} file. A status reference file is needed to be able to compare the current status of the cluster with
                Please initialize this reference file as below:
                $ $RACSTATUS ${OPTIONS} > $REFERENCE
!
                exit 123
        fi
fi

#
# Check the current status of the cluster
#
${RACSTATUS} ${OPTIONS} > ${TMP}
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
        if [ "${EMAIL_ON_SUCCESS}" = "Yes" ]
        then
                printf "\t%s" "Sending en email to " ${EMAILTO} " . . ."
                echo "No change has been identified across the cluster, all good !" | mailx -s "${SUCCESS_SUBJECT}" ${EMAILTO}
                if [ $? -eq 0 ]
                then
                        printf "\t\033[1;32m%-8s\033[m\n" "OK"          ;
                else
                        printf "\t\033[1;31m%-8s\n" "Error $ERR"          ;
                        printf "%s\033[m\n" "There was an issue sending an email using mailx -s ${SUCCESS_SUBJECT} ${EMAILTO}"
                        exit 555
                fi
        fi
        RET=0
else                            # Something is wrong, we send an email about it
        cat << !
        The below changes have been identified across the cluster:
!
        cat ${TMP2}
        if [ "${EMAIL_ON_FAILURE}" = "Yes" ]
        then
                printf "\t%s" "Sending en email to " ${EMAILTO} " . . ."
                # Remove colors from the file before sending the email
                cat ${TMP2} | sed -r "s/\x1B\[([0-9]{1,2}(;[0-9]{1,2})?)?[m|K]//g" | mailx -s "${FAILURE_SUBJECT}" ${EMAILTO}
                if [ $? -eq 0 ]
                then
                        printf "\t\033[1;32m%-8s\033[m\n" "OK"          ;
                else
                        printf "\t\033[1;31m%-8s\n" "Error $ERR"          ;
                        printf "%s\033[m\n" "There was an issue sending an email using mailx -s ${FAILURE_SUBJECT} ${EMAILTO}"
                        exit 666
                fi
        fi
        RET=1
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

exit ${RET}

#*********************************************************************************************************
#                               E N D     O F      S O U R C E
#*********************************************************************************************************
