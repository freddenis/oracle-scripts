#!/bin/bash
# Fred Denis -- July 2019 -- http://unknowndba.blogspot.com -- fred.denis3@gmail.com
#
# yal.sh -- Yet Another Launcher !
#
# Copy and/or execute a script and/or some commands on many hosts; use the -h option to show the usage function for more information
#
# https://unix.stackexchange.com/questions/122616/why-do-i-need-a-tty-to-run-sudo-if-i-can-sudo-without-a-password/122624
#
# The current version of the script is DEV20190807
#
# History:
#
# DEV20190807 - Fred Denis - Better parameter search in the config file
# DEV20190802 - Fred Denis - -s for ssh option ans -S for scp options
#                            SSH_OPTIONS and SCP_OPTIONS are supported on the config file
#
#

#
# Default values
#
# You can update the below default values (variables starting with DEFAULT_) but I recommend using a configuration file (see variable CONFIG_FILE)
#
       DEFAULT_AFTER=""                                         # Default command to execute after  the script
      DEFAULT_BEFORE=""                                         # Default command to execute before the script
 DEFAULT_SERVER_LIST=""                                         # List of hosts to execute the script on
        DEFAULT_DEST="/tmp"                                     # Target directory to copy the script before executing it
DEFAULT_USER_TO_EXEC=""                                         # User used to execute the script on the target server (sudo to this user privilege is needed)
DEFAULT_FILE_TO_COPY=""                                         # A file to copy to the target servers
  DEFAULT_GROUP_FILE=""                                         # A file to copy to the target servers
      DEFAULT_SCRIPT=""                                         # A file containing a list of target servers (1 server per line)
 DEFAULT_USER_TO_LOG=""                                         # User used to connect to the target server

              HEADER="echo BEGIN on \`hostname -s\` : \`date\`"    # Header to print before execution on  target
              FOOTER="echo END\ \ \ on \`hostname -s\` : \`date\`" # Footer to print after  execution on a target

         CONFIG_FILE=".yal.config"                              # Default config file containing default values overwritting these ones
        SHOW_OPTIONS="no"                                       # Show the options that would be used and exit -- do not do anything else (-o)
        SHOW_ELAPSED="yes"                                      # Show the elapsed time
 DEFAULT_SSH_OPTIONS="-qT"                                      # SSH options when connecting to the hostsa (you may not want to modify this one)
 DEFAULT_SCP_OPTIONS="-q"                                       # SCP options when there is a file to copy and/or execute (you may not want to modify this one)

#
# List of parameters that can be modified (config file, top of the script or command line option)
#
list_param=('AFTER' 'BEFORE' 'SERVER_LIST' 'DEST' 'USER_TO_EXEC' 'FILE_TO_COPY' 'GROUP_FILE' 'USER_TO_LOG' 'SCRIPT' 'SSH_OPTIONS' 'SCP_OPTIONS')


        # Used for the header, footer and elapsed
       BLUE_BOLD="1;34m"
            BLUE="34m"
           COLOR=${BLUE_BOLD}

#
# Function to get values from the config file, receive a pattenr and retuen the value specified in the config file
# Form should be : PATTERN=value or PATTERN="list of values"
#
get_from_config_file()
{
        A=$(grep "$1" ${CONFIG_FILE} | grep -v "^#" | sed s'/^[[:space:]]*//g' | sed s'/#.*$//' | sed s'/^.*=[[:space:]]*//' | sed s'/[[:space:]]*$//' | sed s'/"//g')
        echo "$A"
}

#
# Get the values from the config file
#
if [[ -f ${CONFIG_FILE} ]]
then
        for name in "${list_param[@]}"
        do
                declare -x "$name"="$(get_from_config_file "$name")"
        done
fi

#
# Use default values if not specified in the config file
#
if [[ -z ${AFTER}        ]]     ; then        AFTER="$DEFAULT_AFTER"            ; fi
if [[ -z ${BEFORE}       ]]     ; then       BEFORE="$DEFAULT_BEFORE"           ; fi
if [[ -z ${SERVER_LIST}  ]]     ; then  SERVER_LIST=$DEFAULT_SERVER_LIST        ; fi
if [[ -z ${DEST}         ]]     ; then         DEST=$DEFAULT_DEST               ; fi
if [[ -z ${USER_TO_EXEC} ]]     ; then USER_TO_EXEC=$DEFAULT_USER_TO_EXEC       ; fi
if [[ -z ${FILE_TO_COPY} ]]     ; then FILE_TO_COPY=$DEFAULT_FILE_TO_COPY       ; fi
if [[ -z ${GROUP_FILE}   ]]     ; then   GROUP_FILE=$DEFAULT_GROUP_FILE         ; fi
if [[ -z ${USER_TO_LOG}  ]]     ; then  USER_TO_LOG=$DEFAULT_USER_TO_LOG        ; fi
if [[ -z ${SCRIPT}       ]]     ; then       SCRIPT=$DEFAULT_SCRIPT             ; fi
if [[ -z ${SSH_OPTIONS}  ]]     ; then  SSH_OPTIONS="$DEFAULT_SSH_OPTIONS"      ; fi
if [[ -z ${SCP_OPTIONS}  ]]     ; then  SCP_OPTIONS="$DEFAULT_SCP_OPTIONS"      ; fi

#
# An usage function
#
usage()
{
printf "\n\033[1;37m%-8s\033[m\n" "NAME"                                        ;
cat << END
        `basename $0` - Execute or copy a script on many hosts; can also execute commands on many hosts
END

printf "\n\033[1;37m%-8s\033[m\n" "SYNOPSIS"                                    ;
cat << END
        $0 [-a] [-b] [-c] [-d] [-e] [-f] [-g] [-l] [-o] [-x] [-s] [-S] [-h]
END

printf "\n\033[1;37m%-8s\033[m\n" "DESCRIPTION"                                 ;
cat << END
        `basename $0` needs SSH equivalence already set between the user executing it and the target user (option -l)
        `basename $0` does not support different users to connect and execute per host (yet)
        `basename $0` can also sudo to a user to execute a script (option -e)
        With no option, `basename $0` use the values defined in the config file and if not, the default values from the top of the script

        Options precedence is:
                1/ Option through the command line
                2/ Defaults options defined on top of the script (variables DEFAULT_xxxx)
                3/ Options defined in the config file (if exists)

END

printf "\n\033[1;37m%-8s\033[m\n" "OPTIONS"                                     ;
cat << END
        -a      Commands to execute before copying and/or executing the script
        -b      Commands to execute after  copying and/or executing the script
        -c      Comma separated list of target servers to log in to
        -d      Destination of the file on the target servers
        -e      User to use to Execute the script and the commands on the target server (sudo to this user privilege is needed)
        -f      File to be copied to the target servers (see -x to have the file also executed)
        -g      Specify a file containing a list of target servers to connect to (1 server per line)
        -l      User to use to Login to the target servers
        -o      Only shows the values of the options and exit (do not do anything else)
        -s      SSH options
        -S      SCP options
        -x      Copy and eXecute the script on the target hosts (see -f to only copy a file)
        -h      Shows this help

        Experiment and enjoy  !

END
        exit 123
}
#
# Print a line of "-"
#
print_a_line()
{
        printf "\n"                                                                             ;
        for i in `seq 1 $1`
        do      printf "\033[1;37m%1s\033[m" "-"                                                ;
        done
}
#
# Options (overwrite the default values)
#
while getopts "a:b:c:d:e:f:g:l:ox:hs:S:" OPT; do
        case ${OPT} in
        a)              AFTER=${OPTARG}                         ;;
        b)             BEFORE=${OPTARG}                         ;;
        c)        SERVER_LIST=${OPTARG}                         ;;
        d)               DEST=${OPTARG}                         ;;
        e)       USER_TO_EXEC=${OPTARG}                         ;;
        f)       FILE_TO_COPY=${OPTARG}                         ;;
        g)         GROUP_FILE=${OPTARG}                         ;;
        l)        USER_TO_LOG=${OPTARG}                         ;;
        o)       SHOW_OPTIONS="yes"                             ;;
        s)        SSH_OPTIONS=${OPTARG}                         ;;
        S)        SCP_OPTIONS=${OPTARG}                         ;;
        x)             SCRIPT=${OPTARG}                         ;;
        h)      usage                                           ;;
        \?) echo "Invalid option: -$OPTARG" >&2; usage          ;;
        esac
done

if [[ -n ${GROUP_FILE} && -n ${SERVER_LIST} ]]
then
        printf "\n\033[1;33m%s\033[m\n\n" "Info: when both a server list (-c) and a group file (-g) are specified, the group file is used."           ;
fi

if [[ -n ${GROUP_FILE} ]]               # A group file is specifiedm we will use the hosts from it
then
        if [[ -f ${GROUP_FILE} ]]
        then
                SERVER_LIST=`cat ${GROUP_FILE} | awk '{printf("%s,",$1)}' | sed s'/,$//'`
        else
                printf "\n\t\033[1;31m%s\033[m\n\n" "Cannot find ${GROUP_FILE}, cannot continue."           ;
                exit 669
        fi
fi

#
# Show the value of the options with the current setting -- do not do anythongm just show and exit
#
if [[ "${SHOW_OPTIONS}" = "yes" ]]
then
        # Adapt the colum size to the longest value of the variales
        COL2=${#CONFIG_FILE}
        for X in "${list_param[@]}"
        do
                A="${!X}"                                                                       ;
                if (( ${#A} > $COL2 ))
                then
                        COL2=$(( ${#A}+1 ))                                                     ;
                fi
        done

        SIZE=$(( 24 + ${COL2} ))                                                                ;
        FORMAT_TITLE="\n\033[1;37m%-20s\033[m\033[1;37m| %-${COL2}s |\033[m"                    ;
        FORMAT_VALUE="\n\033[1;34m%-20s\033[m\033[1;37m|\033[m %-${COL2}s \033[1;37m|\033[m"    ;

        printf "${FORMAT_TITLE}" "Option"               "Value"                                 ;
        print_a_line $SIZE                                                                      ;
        printf "${FORMAT_VALUE}" "-a: After"            "$AFTER"                                ;
        printf "${FORMAT_VALUE}" "-b: Before"           "$BEFORE"                               ;
        printf "${FORMAT_VALUE}" "-c: Servers List"     "$SERVER_LIST"                          ;
        printf "${FORMAT_VALUE}" "-d: Dest"             "$DEST"                                 ;
        printf "${FORMAT_VALUE}" "-e: User to exec"     "$USER_TO_EXEC"                         ;
        printf "${FORMAT_VALUE}" "-f: File to copy"     "$FILE_TO_COPY"                         ;
        printf "${FORMAT_VALUE}" "-g: Group File"       "$GROUP_FILE"                           ;
        printf "${FORMAT_VALUE}" "-l: User to login"    "$USER_TO_LOG"                          ;
        printf "${FORMAT_VALUE}" "-s: SSH Options"      "$SSH_OPTIONS"                          ;
        printf "${FORMAT_VALUE}" "-S: SCP Options"      "$SCP_OPTIONS"                          ;
        printf "${FORMAT_VALUE}" "-x: Script to exec"   "$SCRIPT"                               ;
        printf "${FORMAT_VALUE}" "    Config File"      "$CONFIG_FILE"                          ;
        print_a_line $SIZE                                                                      ;
        printf "\n\n"                                                                           ;

        exit 555
fi

#
# Input checks
#
if [[ -n ${SCRIPT} && ! -f ${SCRIPT} ]]
then
        printf "\n\t\033[1;31m%s\033[m\n\n" "Cannot find ${SCRIPT}, cannot continue."           ;
        exit 666
fi
if [[ -n ${FILE_TO_COPY} && ! -f ${FILE_TO_COPY} ]]
then
        printf "\n\t\033[1;31m%s\033[m\n\n" "Cannot find ${FILE_TO_COPY}, cannot continue."      ;
        exit 667
fi
if [[ -n ${SCRIPT} ]]
then
        FILE_TO_COPY=${SCRIPT}
fi
if [[ -z ${USER_TO_LOG} ]]
then
        printf "\n\t\033[1;31m%s\033[m\n\n" "A user to log in is needed (option -l), cannot continue."           ;
        exit 668
fi

TO=${DEST}"/"${FILE_TO_COPY}                       # for better visibility below

#
# Let's go
#
for X in `echo ${SERVER_LIST} | awk 'BEGIN {FS="[,;]"} {for (i=1;i<=NF;i++) { print $i}}'`
do 
        if [[ "${SHOW_ELAPSED}" = "yes" ]]
        then
                START_TIME="$(date -u +%s)"
        fi
        #
        # Header and Before
        #
        if [[ -n "${HEADER}" || -n "${BEFORE}" ]]     
        then
                ssh ${SSH_OPTIONS} ${USER_TO_LOG}@${X} << END_SSH
                        if [[ -n "${HEADER}" ]]
                        then
                                echo -ne "\e[${COLOR}"                                  ;
                                eval "${HEADER}"                                        ;
                                echo -ne "\e[0m"                                        ;
                        fi
                        if [[ -n "${BEFORE}" ]]        
                        then
                                if [[ -n "${USER_TO_EXEC}" ]]
                                then
                                        sudo su - ${USER_TO_EXEC} << END_SU 
                                        eval "${BEFORE}"                                ;
END_SU
                                else
                                        eval "${BEFORE}"                                ;
                                fi
                        fi
END_SSH
        fi

        #
        # Script copy
        #
        if [[ -f "${FILE_TO_COPY}" ]]                   # A file to copy
        then
                scp ${SCP_OPTIONS} ${FILE_TO_COPY} ${USER_TO_LOG}@${X}:${TO}
        fi

        #
        # Script execution, After and Footer
        #
        if [[ -n "${SCRIPT}" || -n "${AFTER}" || -n "${FOOTER}" ]]
        then
                ssh ${SSH_OPTIONS} ${USER_TO_LOG}@${X} << END_SSH
                        if [[ -n "${SCRIPT}" ]]
                        then
                                chmod 777 ${TO}
                                if [[ -n "${USER_TO_EXEC}" ]]
                                then
                                        sudo su - ${USER_TO_EXEC} << END_SU
                                        . ${TO}                                         ;
END_SU
                                else
                                        . ${TO}                                         ;
                                fi
                                if [[ -f "${TO}" ]]                             
                                then
                                        rm -f ${TO}                                     ;
                                fi
                        fi
                        if [[ -n "${AFTER}" ]]                    
                        then
                                if [[ -n "${USER_TO_EXEC}" ]]
                                then
                                        sudo su - ${USER_TO_EXEC} << END_SU
                                        eval "${AFTER}"                                 ;
END_SU
                                else
                                        eval "${AFTER}"                                 ;
                                fi
                        fi
                        if [[ -n "${FOOTER}" ]]
                        then
                                echo -ne "\e[${COLOR}"                                  ;
                                eval "${FOOTER}"                                        ;
                                echo -ne "\e[0m"                                        ;
                        fi
END_SSH
        fi
        if [[ "${SHOW_ELAPSED}" = "yes" ]] 
        then
                END_TIME="$(date -u +%s)"                                               ;
                 ELAPSED="$(($END_TIME-$START_TIME))"                                   ;
                printf "\033[${COLOR}%-8s: %s\033[m\n" "ELAPSED" "$ELAPSED seconds"     ;
        fi
done


#************************************************************************#
#                       E N D      O F      S O U R C E                 *#
#************************************************************************#
