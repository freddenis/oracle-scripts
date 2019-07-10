#!/bin/bash
# Fred Denis -- July 2019 -- http://unknowndba.blogspot.com -- fred.denis3@gmail.com
#
# Execute a script on many targets; use -h option to show the usage function for more information
#
# The current version of the script is 20190710
#
# History:
#
# 20190710 - Fred Denis - Initial release
#

#
# Default values
#
      DEFAULT_SCRIPT="rac-status.sh"                            # Script we want to execute
DEFAULT_USER_TO_COPY="opc"                                      # User used to connect to the target server
DEFAULT_USER_TO_EXEC="oracle"                                   # User used to execute the script on the target server
      DEFAULT_TARGET="/tmp"                                     # Target directory to copy the script before executing it
        DEFAULT_LIST="tgtdev1,tgtdev2,tgtdev3"                  # List of hosts to execute the script on
DEFAULT_NEED_TO_SUDO="yes"                                      # If needed to sudo to another user to execute the script (if not, execute as the user used to connect)
      DEFAULT_BEFORE=""                                         # Default command to execute before the script
       DEFAULT_AFTER=""                                         # Default command to execute after  the script
         CONFIG_FILE=".onmany.config"                           # Default config file containing default values overwritting these ones
               DEBUG="yes"                                      # Show debug info ?
               DEBUG="no"                                       # Show debug info ?

#
# Get values from the config file
#
if [[ -f ${CONFIG_FILE} ]]
then
              SCRIPT=`cat ${CONFIG_FILE} | grep -v "^#" | sed s'/^ *//g' | grep "^SCRIPT"       | sed s'/"//g' | awk -F "=" '{print $2}' | sed s'/ .*$//g'`
        USER_TO_COPY=`cat ${CONFIG_FILE} | grep -v "^#" | sed s'/^ *//g' | grep "^USER_TO_COPY" | sed s'/"//g' | awk -F "=" '{print $2}' | sed s'/ .*$//g'`
        USER_TO_EXEC=`cat ${CONFIG_FILE} | grep -v "^#" | sed s'/^ *//g' | grep "^USER_TO_EXEC" | sed s'/"//g' | awk -F "=" '{print $2}' | sed s'/ .*$//g'`
              TARGET=`cat ${CONFIG_FILE} | grep -v "^#" | sed s'/^ *//g' | grep "^TARGET"       | sed s'/"//g' | awk -F "=" '{print $2}' | sed s'/ .*$//g'`
                LIST=`cat ${CONFIG_FILE} | grep -v "^#" | sed s'/^ *//g' | grep "^LIST"         | sed s'/"//g' | awk -F "=" '{print $2}' | sed s'/ .*$//g'`
        NEED_TO_SUDO=`cat ${CONFIG_FILE} | grep -v "^#" | sed s'/^ *//g' | grep "^NEED_TO_SUDO" | sed s'/"//g' | awk -F "=" '{print $2}' | sed s'/ .*$//g'`
              BEFORE=`cat ${CONFIG_FILE} | grep -v "^#" | sed s'/^ *//g' | grep "^BEFORE"       | sed s'/"//g' | awk -F "=" '{print $2}' | sed s'/ .*$//g'`
               AFTER=`cat ${CONFIG_FILE} | grep -v "^#" | sed s'/^ *//g' | grep "^AFTER"        | sed s'/"//g' | awk -F "=" '{print $2}' | sed s'/ .*$//g'`
fi

#
# Use default values if not specified in the config file
#
if [[ -z ${SCRIPT}       ]]     ; then       SCRIPT=$DEFAULT_SCRIPT             ; fi
if [[ -z ${USER_TO_COPY} ]]     ; then USER_TO_COPY=$DEFAULT_USER_TO_COPY       ; fi
if [[ -z ${USER_TO_EXEC} ]]     ; then USER_TO_EXEC=$DEFAULT_USER_TO_EXEC       ; fi
if [[ -z ${TARGET}       ]]     ; then       TARGET=$DEFAULT_TARGET             ; fi
if [[ -z ${LIST}         ]]     ; then         LIST=$DEFAULT_LIST               ; fi
if [[ -z ${NEED_TO_SUDO} ]]     ; then NEED_TO_SUDO=$DEFAULT_NEED_TO_SUDO       ; fi
if [[ -z ${BEFORE}       ]]     ; then       BEFORE=$DEFAULT_BEFORE             ; fi
if [[ -z ${AFTER}        ]]     ; then        AFTER=$DEFAULT_AFTER              ; fi

#
# An usage function
#
usage()
{
printf "\n\033[1;37m%-8s\033[m\n" "NAME"                ;
cat << END
        `basename $0` - Execute a script on many targets
END

printf "\n\033[1;37m%-8s\033[m\n" "SYNOPSIS"            ;
cat << END
        $0 [-a] [-b] [-c] [-e] [-n] [-t] [-s] [-h]
END

printf "\n\033[1;37m%-8s\033[m\n" "DESCRIPTION"         ;
cat << END
        `basename $0` needs SSH equivalence already set between the user executing it and the target user (option -c)
        `basename $0` does not support different users to connect and execute per host
        With no option, `basename $0` use the values defined in the Default section on top of the script

END

printf "\n\033[1;37m%-8s\033[m\n" "OPTIONS"             ;
cat << END
        -a      Commands to execute before executing the script
        -b      Commands to execute after  executing the script
        -c      User to use to connect to the target server (opc for OCI for example)
        -e      User to use to execute the script and the commands on the target server (oracle ? grid ?)
        -n      No need to sudo so script and comands will be executed as the user we connect with
        -s      Name of the script to execute on the target hosts
        -t      A target list of host to execute the script on; each host has to be separated by a ","
        -h      Shows this help

        Experiment and enjoy  !

END
exit 123
}

#
# Options (overwrite default)
#
while getopts "s:c:e:t:na:b:h" OPT; do
        case ${OPT} in
        a)              AFTER=${OPTARG}                         ;;
        b)             BEFORE=${OPTARG}                         ;;
        c)       USER_TO_COPY=${OPTARG}                         ;;
        e)       USER_TO_EXEC=${OPTARG}                         ;;
        n)       NEED_TO_SUDO="no"                              ;;
        s)             SCRIPT=${OPTARG}                         ;;
        t)               LIST=${OPTARG}                         ;;
        h)      usage                                           ;;
        \?) echo "Invalid option: -$OPTARG" >&2; usage          ;;
        esac
done

#
# Input checks
#
if [[ ! -f ${SCRIPT} && -n ${SCRIPT} ]]
then
        cat << END
        Cannot find ${SCRIPT} is not executable -- cannot continue.
END
        exit 666
fi

#
# Debug ?
#
if [[ "${DEBUG}" = "yes" ]]
then
        echo "Script            :"      $SCRIPT
        echo "User to Copy      :"      $USER_TO_COPY
        echo "User to Exec      :"      $USER_TO_EXEC
        echo "List              :"      $LIST
        echo "Target            :"      $TARGET
        echo "Need to SUDO      :"      $NEED_TO_SUDO
        echo "Config File       :"      $CONFIG_FILE
        exit
fi

TO=${TARGET}"/"${SCRIPT}                                        # for better visibility below

#
# Let's go
#
for X in `echo ${LIST} | awk 'BEGIN {FS=","} {for (i=1;i<=NF;i++) { print $i}}'`
do
        if [[ -n ${BEFORE} ]]                   # A command to execute 
        then
                ssh -qT ${USER_TO_COPY}@${X} << END_SSH
                if [[ "$NEED_TO_SUDO" = "yes" ]]
                then
                        sudo su - ${USER_TO_EXEC} << END_SU
                        id
                        ${BEFORE}
END_SU
                else
                        id
                        ${BEFORE}
                fi
END_SSH
        fi
        if [[ -n ${SCRIPT} ]]                   # A script to execute
        then
                scp -q ${SCRIPT} ${USER_TO_COPY}@${X}:${TO}
                ssh -qT ${USER_TO_COPY}@${X} << END_SSH
                chmod 777 ${TO}
                if [[ "$NEED_TO_SUDO" = "yes" ]]
                then
                        sudo su - ${USER_TO_EXEC} << END_SU
                        id
                        . ${TO}
END_SU
                else
                        id
                        . ${TO}
                fi
                if [ -f ${TO} ]
                then
                        rm -f ${TO}
                fi
END_SSH
        fi
        if [[ -n ${AFTER} ]]                    # A command to execute 
        then
                ssh -qT ${USER_TO_COPY}@${X} << END_SSH
                if [[ "$NEED_TO_SUDO" = "yes" ]]
                then
                        sudo su - ${USER_TO_EXEC} << END_SU
                        id
                        ${AFTER}
END_SU
                else
                        id
                        ${AFTER}
                fi
END_SSH
        fi
done


#************************************************************************#
#                       E N D      O F      S O U R C E                 *#
#************************************************************************#
