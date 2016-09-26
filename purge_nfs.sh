/home/oracle : MOX103> cat /opt/oranfs/cleanup_nfs/purge_fs/purge_fs.sh
#!/bin/bash
# Fred Denis -- purge exports FS
# Purge directories according to the config file $CONF
# Ignore the "oneoff" subdirectories (asked by Covidien)
#
# Variables definition
#
   THE_DATE=`date +%d%m%Y_%H%M`         # a timestamp
      PURGE="NO"                        # With no option, do not purge, just show a report of the FS
     DEBUG="YES"                        # comment to remove debug
         DIR=`dirname $0`
       CONF=${DIR}/purge_fs.conf        # Config file

# Usage function
#
function usage {
cat <<!
Usage: $0 -p
    -p: purge the files
!
exit 0 ;
}

#
# Get the options of the script
#
while getopts :p name
do
    case ${name} in
    p)   PURGE="YES" ;;
    ?)  usage ;;
    esac
done

#
# Check that the config file exists
#
if [ ! -f $CONF ]
then
        cat << !
        Config file ${CONF} not found !
!
fi

#
# A little debug if needed
#
if [[ -n $DEBUG ]]
then
        echo "Config file       :"      $CONF
fi

IFS=$'\n'
for X in `cat $CONF | grep "^\/" | grep -v DIRECTORY_TO_IGNORE`
do
         FS=`echo $X | awk '{print $1}'`
        RET=`echo $X | awk '{gsub(" ", "", $2); print $2}'`

        if [ ! -d ${FS} ]
        then
                echo "${FS} does not exists !"
        else
                if [ "$PURGE" = "YES" ]
                then
                        #
                        # Directories to ignore
                        #
                                IFS=","
                        IGNORE_LIST=""
                        for DIR in $(cat ${CONF} | grep "^DIRECTORY_TO_IGNORE" | sed s'/^.*=//g' | sed s'/ //g')
                        do
                                if [[ -n $DEBUG ]]
                                then
                                        echo "To ignore :  ${FS}/${DIR}"
                                fi
                                IGNORE_LIST=`echo $IGNORE_LIST " ! \( -path \"${FS}/${DIR}\" -prune \)"`
                        done

                        #
                        # Build the find command
                        #
                        FIND_COMMAND=`echo "find ${FS} ${IGNORE_LIST} -type f -name \"*.dp\" -mtime +${RET} | xargs rm -f"`

                        if [[ -n $DEBUG ]]
                        then
                                echo "purge ${FS} !"
                                echo "Ignore list : " ${IGNORE_LIST}
                                echo $FIND_COMMAND
                        fi

                        #
                        # Execute the purge
                        #
                        eval ${FIND_COMMAND}

                        #
                        # Check the results of the find
                        #
                        if [[ $? -eq 0 ]]
                        then
                                echo "${FS} has been purged successfully removing files older than ${RET} days. "
                        else
                                echo "Error $? occured during ${FS} purged."
                        fi
                else

                cat <<!

Config ${FS} is to purge files older than ${RET} days
**********************************************************************************
!
                        for i in 3 7 10 14 21 28 45 60 90 120
                        do
                                NB_FILES_TO_PURGE=`find ${FS} -type f -name "*.dp" -mtime +${i} | wc -l`
                                if [ "$NB_FILES_TO_PURGE" = "0" ]
                                then
                                        SIZE="0"
                                else
                                        SIZE=`find ${FS} -type f -name "*.dp" -mtime +${i} | xargs ls -l | awk '{size+=$5}END{print size/1024/1024/1024}' | sed s'/\..*$//'`
                                fi
                                echo files older than ${i} days : ${NB_FILES_TO_PURGE} \(${SIZE} GB\)
                        done

                        if [[ -n $DEBUG ]]
                        then
                                echo "x                 :"      $X
                                echo "FS to purge       :"      $FS
                                echo "Retention days    :"      $RET
                        fi
                fi
        fi
done
