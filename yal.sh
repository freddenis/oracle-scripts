#!/bin/bash
# Fred Denis -- July 2019 -- http://unknowndba.blogspot.com -- fred.denis3@gmail.com
#
# Execute a script and/or some commands on many targets; use the -h option to show the usage function for more information
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
      DEFAULT_SCRIPT=""                                         # Script we want to execute
DEFAULT_USER_TO_COPY=""                                         # User used to connect to the target server
DEFAULT_USER_TO_EXEC=""                                         # User used to execute the script on the target server (sudo to this user privilege is needed)
      DEFAULT_TARGET="/tmp"                                     # Target directory to copy the script before executing it
        DEFAULT_LIST=""                                         # List of hosts to execute the script on
      DEFAULT_BEFORE=""                                         # Default command to execute before the script
       DEFAULT_AFTER=""                                         # Default command to execute after  the script
   DEFAULT_JUST_COPY="no"                                       # Just copy the file or also execute it ? if the file is not executed then it is not deleted

         CONFIG_FILE=".onmany.config"                           # Default config file containing default values overwritting these ones
              HEADER="echo BEGIN on `hostname` : `date`"        # Header to print before execution on  target
              FOOTER="echo END   on `hostname` : `date`"        # Footer to print after  execution on a target
        SHOW_OPTIONS="no"                                       # Show the options that would be used and exit -- do not do anything else (-o)

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
              BEFORE=`cat ${CONFIG_FILE} | grep -v "^#" | sed s'/^ *//g' | grep "^BEFORE"       | sed s'/"//g' | awk -F "=" '{print $2}' | sed s'/ .*$//g'`
               AFTER=`cat ${CONFIG_FILE} | grep -v "^#" | sed s'/^ *//g' | grep "^AFTER"        | sed s'/"//g' | awk -F "=" '{print $2}' | sed s'/ .*$//g'`
           JUST_COPY=`cat ${CONFIG_FILE} | grep -v "^#" | sed s'/^ *//g' | grep "^JUST_COPY"    | sed s'/"//g' | awk -F "=" '{print $2}' | sed s'/ .*$//g'`
fi

#
# Use default values if not specified in the config file
#
if [[ -z ${SCRIPT}       ]]     ; then       SCRIPT=$DEFAULT_SCRIPT             ; fi
if [[ -z ${USER_TO_COPY} ]]     ; then USER_TO_COPY=$DEFAULT_USER_TO_COPY       ; fi
if [[ -z ${USER_TO_EXEC} ]]     ; then USER_TO_EXEC=$DEFAULT_USER_TO_EXEC       ; fi
if [[ -z ${TARGET}       ]]     ; then       TARGET=$DEFAULT_TARGET             ; fi
if [[ -z ${LIST}         ]]     ; then         LIST=$DEFAULT_LIST               ; fi
if [[ -z ${BEFORE}       ]]     ; then       BEFORE=$DEFAULT_BEFORE             ; fi
if [[ -z ${AFTER}        ]]     ; then        AFTER=$DEFAULT_AFTER              ; fi
if [[ -z ${JUST_COPY}    ]]     ; then    JUST_COPY=$DEFAULT_JUST_COPY          ; fi

#
# An usage function
#
usage()
{
printf "\n\033[1;37m%-8s\033[m\n" "NAME"                                        ;
cat << END
        `basename $0` - Execute a script on many targets
END

printf "\n\033[1;37m%-8s\033[m\n" "SYNOPSIS"                                    ;
cat << END
        $0 [-a] [-b] [-c] [-e] [-j] [-t] [-s] [-h]
END

printf "\n\033[1;37m%-8s\033[m\n" "DESCRIPTION"                                 ;
cat << END
        `basename $0` needs SSH equivalence already set between the user executing it and the target user (option -c)
        `basename $0` does not support different users to connect and execute per host
        With no option, `basename $0` use the values defined in the Default section on top of the script

        Options precedence is:
                1/ Option through the command line
                2/ Defaults options defined on top of the script (variables DEFAULT_xxxx)
                3/ Options defined in the config file (if exists)

END

printf "\n\033[1;37m%-8s\033[m\n" "OPTIONS"                                     ;
cat << END
        -a      Commands to execute before executing the script
        -b      Commands to execute after  executing the script
        -c      User to use to connect to the target server (opc for OCI for example)
        -e      User to use to execute the script and the commands on the target server (sudo to this user privilege is needed)
        -j      Just copy the file on the targets hosts (do not execute it nor delete it)
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
while getopts "s:c:e:t:ja:b:oh" OPT; do
        case ${OPT} in
        a)              AFTER=${OPTARG}                         ;;
        b)             BEFORE=${OPTARG}                         ;;
        c)       USER_TO_COPY=${OPTARG}                         ;;
        e)       USER_TO_EXEC=${OPTARG}                         ;;
        j)          JUST_COPY="yes"                             ;;
        o)       SHOW_OPTIONS="yes"                             ;;
        s)             SCRIPT=${OPTARG}                         ;;
        t)               LIST=${OPTARG}                         ;;
        h)      usage                                           ;;
        \?) echo "Invalid option: -$OPTARG" >&2; usage          ;;
        esac
done

echo $LIST
exit

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

print_a_line()
{
        printf "\n"                                                                             ;
        for i in `seq 1 $1`
        do      printf "\033[1;37m%1s\033[m" "-"                                                ;
        done
}

#
# Show the value of the options with the current setting -- do not do anythongm just show and exit
#
if [[ "${SHOW_OPTIONS}" = "yes" ]]
then
        if (( ${#LIST} > 0 ))
        then
                COL2=$(( ${#LIST}+1 ))                                                          ;
        else    COL2=20                                                                         ;
        fi
        SIZE=$(( 24 + ${COL2} ))                                                                ;
        FORMAT_TITLE="\n\033[1;37m%-20s\033[m\033[1;37m| %-${COL2}s |\033[m"                    ;
        FORMAT_VALUE="\n\033[1;34m%-20s\033[m\033[1;37m|\033[m %-${COL2}s \033[1;37m|\033[m"    ;

        printf "${FORMAT_TITLE}" "Option"               "Value"                                 ;
        print_a_line $SIZE                                                                      ;
        printf "${FORMAT_VALUE}" "-a: After"            $AFTER                                  ;
        printf "${FORMAT_VALUE}" "-b: Before"           $BEFORE                                 ;
        printf "${FORMAT_VALUE}" "-c: User to copy"     $USER_TO_COPY                           ;
        printf "${FORMAT_VALUE}" "-e: User to exec"     $USER_TO_EXEC                           ;
        printf "${FORMAT_VALUE}" "-j: Just copy"        $JUST_COPY                              ;
        printf "${FORMAT_VALUE}" "-l: List"             $LIST                                   ;
        printf "${FORMAT_VALUE}" "-s: Script"           $SCRIPT                                 ;
        printf "${FORMAT_VALUE}" "-t: Target"           $TARGET                                 ;
        printf "${FORMAT_VALUE}" "    Config File"      $CONFIG_FILE                            ;
        print_a_line $SIZE                                                                      ;
        printf "\n\n"                                                                           ;

        exit 555
fi

TO=${TARGET}"/"${SCRIPT}                                        # for better visibility below

#
# Let's go
#
for X in `echo ${LIST} | awk 'BEGIN {FS="[,;]"} {for (i=1;i<=NF;i++) { print $i}}'`
do      if [[ -n ${HEADER} ]]
        then
                ssh -qT ${USER_TO_COPY}@${X} << END_SSH
                ${HEADER}
END_SSH
        fi
        if [[ -n ${BEFORE} ]]                   # A command to execute
        then
                ssh -qT ${USER_TO_COPY}@${X} << END_SSH
                if [[ -n ${USER_TO_EXEC} ]]
                then
                        sudo su - ${USER_TO_EXEC} << END_SU
                        ${BEFORE}
END_SU
                else
                        ${BEFORE}
                fi
END_SSH
        fi
        if [[ -n ${SCRIPT} ]]                   # A script to execute
        then
                scp  ${SCRIPT} ${USER_TO_COPY}@${X}:${TO}

                if [[ "$JUST_COPY" = "no" ]]
                then
                        ssh -qT ${USER_TO_COPY}@${X} << END_SSH
                        chmod 777 ${TO}
                        if [[ -n ${USER_TO_EXEC} ]]
                        then
                                sudo su - ${USER_TO_EXEC} << END_SU
                                . ${TO}
END_SU
                        else
                                . ${TO}
                        fi
                        if [[ -f ${TO} ]]
                        then
                                rm -f ${TO}
                        fi
END_SSH
                fi
        fi
        if [[ -n ${AFTER} ]]                    # A command to execute
        then
                ssh -qT ${USER_TO_COPY}@${X} << END_SSH
                if [[ -n ${USER_TO_EXEC} ]]
                then
                        sudo su - ${USER_TO_EXEC} << END_SU
                        ${AFTER}
END_SU
                else
                        ${AFTER}
                fi
END_SSH
        fi
        if [[ -n ${FOOTER} ]]
        then
                ssh -qT ${USER_TO_COPY}@${X} << END_SSH
                ${FOOTER}
END_SSH
        fi
done


#************************************************************************#
#                       E N D      O F      S O U R C E                 *#
#************************************************************************#
