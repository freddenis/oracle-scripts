#!/bin/bash
# Fred Denis -- September 2019 -- http://unknowndba.blogspot.com -- fred.denis3@gmail.com
#
# yal.sh -- Yet Another Launcher !
#
# Copy and/or execute a script and/or some commands on many hosts; can connect and sudo to execute as different user per server
# Use the -h option to show the usage function and the available options
# Also, detailed explanations about yal.sh are available on http://bit.ly/2lNiLLF
#
# The current version of the script is 20191008
#
# History:
#
# 20191008 - Fred Denis - -a and -b support different parameters values per server: server1:date,server2:uptime
# 20191002 - Fred Denis - Implemented the "user_to_log:user_to_exec@server" syntax
# 20190912 - Fred Denis - Initial release
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
       DEFAULT_QUIET="NO"                                       # Show the temporary file copy and remove when we execute a file on a remote server
DEFAULT_SCRIPT_OPTIONS=""                                       # Default options to append to a script we execute

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
list_param=('AFTER' 'BEFORE' 'SERVER_LIST' 'DEST' 'USER_TO_EXEC' 'FILE_TO_COPY' 'GROUP_FILE' 'USER_TO_LOG' 'SCRIPT' 'SSH_OPTIONS' 'SCP_OPTIONS' 'QUIET' 'SCRIPT_OPTIONS')
#
# Colors used for the header, footer and elapsed time
#
       BLUE_BOLD="1;34m"
            BLUE="34m"
           COLOR=${BLUE_BOLD}
#
# Function to get values from the config file, receive a pattern and return the value specified in the config file
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
# Show the version of the script (-V)
#
show_version()
{
        VERSION=`awk '{if ($0 ~ /^# 20[0-9][0-9][0-1][0-9]/) {print $2; exit}}' $0`
        printf "\n\t\033[1;36m%s\033[m\n\n" "The current version of "`basename $0`" is "$VERSION"."          ;
}
#
# Function to get a value from a parameter list
#
get_value_from()
{       # Get a pattern ($1) to search in $2 which is of the form:
        # server1:pattern;blabla,server2:another_pattern
        PATTERN="$1"    ;
           FROM="$2"    ;

        if [[ "$2" =~ "," ]]            # More than one server, we search for the one in PATTERN
        then
                echo $FROM | awk -F ":" -v PATTERN="$PATTERN"\
                 ' BEGIN {RS=","}
                   {
                        if ($1 == PATTERN)
                        {       printf $2                       ;
                                exit                            ;
                        }
                        if ($1 == "*")
                        {       DEFAULT = $2                    ;
                        }
                  } END \
                  {     print DEFAULT                           ;
                  }
                 '
        else                            # Only a generic command we always return it 
                echo $FROM | sed s'/..*://g'
        fi
}
#
# Use default values if not specified in the config file
#
if [[ -z ${AFTER}          ]]     ; then          AFTER="$DEFAULT_AFTER"            ; fi
if [[ -z ${BEFORE}         ]]     ; then         BEFORE="$DEFAULT_BEFORE"           ; fi
if [[ -z ${SERVER_LIST}    ]]     ; then    SERVER_LIST=$DEFAULT_SERVER_LIST        ; fi
if [[ -z ${DEST}           ]]     ; then           DEST=$DEFAULT_DEST               ; fi
if [[ -z ${USER_TO_EXEC}   ]]     ; then   USER_TO_EXEC=$DEFAULT_USER_TO_EXEC       ; fi
if [[ -z ${FILE_TO_COPY}   ]]     ; then   FILE_TO_COPY=$DEFAULT_FILE_TO_COPY       ; fi
if [[ -z ${GROUP_FILE}     ]]     ; then     GROUP_FILE=$DEFAULT_GROUP_FILE         ; fi
if [[ -z ${USER_TO_LOG}    ]]     ; then    USER_TO_LOG=$DEFAULT_USER_TO_LOG        ; fi
if [[ -z ${SCRIPT}         ]]     ; then         SCRIPT=$DEFAULT_SCRIPT             ; fi
if [[ -z ${SSH_OPTIONS}    ]]     ; then    SSH_OPTIONS="$DEFAULT_SSH_OPTIONS"      ; fi
if [[ -z ${SCP_OPTIONS}    ]]     ; then    SCP_OPTIONS="$DEFAULT_SCP_OPTIONS"      ; fi
if [[ -z ${QUIET}          ]]     ; then          QUIET="$DEFAULT_QUIET"            ; fi
if [[ -z ${SCRIPT_OPTIONS} ]]     ; then SCRIPT_OPTIONS="$DEFAULT_SCRIPT_OPTIONS"   ; fi
#
# An usage function
#
usage()
{
printf "\n\033[1;37m%-8s\033[m\n" "NAME"                                        ;
cat << END
        `basename $0` - Execute or copy a script and/or commands on many hosts
END
printf "\n\033[1;37m%-8s\033[m\n" "SYNOPSIS"                                    ;
cat << END
        $0 [-a] [-b] [-c] [-d] [-e] [-f] [-g] [-l] [-o] [-q] [-Q] [-x] [-s] [-S] [-h] [-V]
END
printf "\n\033[1;37m%-8s\033[m\n" "DESCRIPTION"                                 ;
cat << END
        `basename $0` needs SSH equivalence already set between the user executing it and the target user (option -l)
        `basename $0` can also sudo to a user to execute a script (option -e)
        `basename $0` supports a "user_to_log:user_to_exec@server" syntax to connect and sudo as different user per server
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
        -g      Specify a file containing a list of target servers to connect to (1 server per line)
                  The comma separated list (-c), the list of servers in a file (-g) and the SERVER_LIST parameter in the config file
                  also support a "user_to_log:user_to_exec@server" syntax to bypass the user to login (-l) and the user to exec (-e)
                  for specific servers; please find an example below:
                        $ `basename $0` -c root:oracle@server1,:oragrid@server2,opc@server3,server4 -l oracle -e grid -x asmdu.sh
                        this will be resolved as:
                        root:oracle@server1 => ssh root             @server1 then sudo oracle         to execute asmdu.sh
                        :oragrid@server2    => ssh oracle (from -l) @server2 then sudo oragrid        to execute asmdu.sh
                        opc@server3         => ssh opc              @server3 then sudo grid (from -e) to execute asmdu.sh
                        server4             => ssh oracle (from -l) @server4 then sudo grid (from -e) to execute asmdu.sh

        -d      Destination of the file on the target servers
        -e      User to use to Execute the script and the commands on the target server (sudo to this user privilege is needed)
        -f      File to be copied to the target servers (see -x to have the file also executed)
        -l      User to use to Login to the target servers
        -o      Only shows the values of the options and exit (do not do anything else)
        -q      Do not show the copy and remove temporary file operations when executing a script
        -Q      Show the copy and remove temporary file operations when executing a script
        -s      SSH options
        -S      SCP options
        -x      Copy and eXecute the script on the target hosts (see -f to only copy a file)
        -V      Show the version
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
        printf "\n"                                             ;
        for i in `seq 1 $1`
        do      printf "\033[1;37m%1s\033[m" "-"                ;
        done
}
#
# Options (overwrite the default values)
#
while getopts "a:b:c:d:e:f:g:l:ox:hs:S:VqQO:" OPT; do
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
        O)     SCRIPT_OPTIONS=${OPTARG}                         ;;
        s)        SSH_OPTIONS=${OPTARG}                         ;;
        q)              QUIET="YES"                             ;;
        Q)              QUIET="NO"                              ;;
        S)        SCP_OPTIONS=${OPTARG}                         ;;
        x)             SCRIPT=${OPTARG}                         ;;
        V)      show_version; exit 555                          ;;
        h)      usage                                           ;;
        \?) echo "Invalid option: -$OPTARG" >&2; usage          ;;
        esac
done

if [[ -n ${GROUP_FILE} && -n ${SERVER_LIST} ]]
then
        printf "\n\033[1;33m%s\033[m\n\n" "Info: when both a server list (-c) and a group file (-g) are specified, the group file is used."           ;
fi

if [[ -n ${GROUP_FILE} ]]               # A group file is specified, we will use the hosts from it
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
# Show the value of each option with the current setting -- do not do anything, just show and exit
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
        printf "${FORMAT_VALUE}" "-q: Quiet"            "$QUIET"                                ;
        printf "${FORMAT_VALUE}" "-s: SSH Options"      "$SSH_OPTIONS"                          ;
        printf "${FORMAT_VALUE}" "-S: SCP Options"      "$SCP_OPTIONS"                          ;
        printf "${FORMAT_VALUE}" "-x: Script to exec"   "$SCRIPT"                               ;
        printf "${FORMAT_VALUE}" "-O: Script options"   "$SCRIPT_OPTIONS"                       ;
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
if [[ -z ${SERVER_LIST} ]]
then
        printf "\n\t\033[1;31m%s\033[m\n\n" "A server to connect to is needed (-c or -g option), cannot continue."           ;
        exit 670
fi
#
# Getting ready
#
TO=${DEST}"/"${FILE_TO_COPY}                       # for better visibility below
if [[ -n ${SCRIPT} ]]
then
        TO=${DEST}"/"${FILE_TO_COPY}$$             # A temporary name for the copied script if we execute the script
fi
servers=(${SERVER_LIST//,/ })                      # Split every server in an array
#
# Let's go
#
for X in ${servers[@]}
do
        #
        # Management of the "user_to_log:user_to_exec@server" syntax
        #
        if [[ ! $X =~ "@" ]] &&  [[ ! $X =~ ":" ]]
        then
                X=":@"$X
        fi
        if ! [[ $X =~ ":" ]]
        then
                X=`echo $X | sed s'/@/:@/'`
        fi

         LOGIN=`echo $X | awk -F "[:@]" '{print $1}'`
          EXEC=`echo $X | awk -F "[:@]" '{print $2}'`
        SERVER=`echo $X | awk -F "[:@]" '{print $3}'`

        if [[ -z ${LOGIN} ]]; then      LUSER=${USER_TO_LOG}    ; else LUSER=${LOGIN}   ;       fi
        if [[ -z ${EXEC}  ]]; then      XUSER=${USER_TO_EXEC}   ; else XUSER=${EXEC}    ;       fi

        #
        # Other options syntax "server:parameters" management
        #
        # dev
        for A in AFTER BEFORE
        do
                B="${!A}"                                                                ;
                if [[ -n $(get_value_from $SERVER "${B}") ]]
                then
                        eval X${A}="$(get_value_from $SERVER "${B}")"
                else
                        eval X${A}="${!B}"
                fi
        done

        #
        # Elaspsed time
        #
        if [[ "${SHOW_ELAPSED}" = "yes" ]]
        then
                START_TIME="$(date -u +%s)"
        fi
        #
        # Header and Before
        #
        if [[ -n "${HEADER}" || -n "${XBEFORE}" ]]
        then
                ssh ${SSH_OPTIONS} ${LUSER}@${SERVER} << END_SSH
                        if [[ -n "${HEADER}" ]]
                        then
                                echo -ne "\e[${COLOR}"                                  ;
                                eval "${HEADER}"                                        ;
                                echo -ne "\e[0m"                                        ;
                        fi
                        if [[ -n "${XBEFORE}" ]]
                        then
                                if [[ -n "${XUSER}" ]]
                                then
                                        sudo su - ${XUSER} << END_SU
                                        eval "${XBEFORE}"                           ;
END_SU
                                else
                                        eval "${XBEFORE}"                            ;
                                fi
                        fi
END_SSH
        fi
        #
        # Script copy
        #
        if [[ -f "${FILE_TO_COPY}" ]]                   # A file to copy
        then
                scp ${SCP_OPTIONS} ${FILE_TO_COPY} ${LUSER}@${SERVER}:${TO}
                RET=$?
                if [[ "${QUIET}" == "NO" ]]
                then
                        if [ $RET -eq 0 ]
                        then
                                printf "%s\n" "Script "${FILE_TO_COPY}" successfully copied to "${TO}           ;
                        else
                                printf "%s\n" "Error "$?" when copying "${FILE_TO_COPY}" to "${TO}              ;
                        fi
                fi
        fi
        #
        # Script execution, After and Footer
        #
        if [[ -n "${SCRIPT}" || -n "${XAFTER}" || -n "${FOOTER}" ]]
        then
                ssh ${SSH_OPTIONS} ${LUSER}@${SERVER} << END_SSH
                        if [[ -n "${SCRIPT}" ]]
                        then
                                chmod 777 ${TO}
                                if [[ -n "${XUSER}" ]]
                                then
                                        sudo su - ${XUSER} << END_SU
                                        . ${TO} ${SCRIPT_OPTIONS}                       ;
END_SU
                                else
                                        . ${TO} ${SCRIPT_OPTIONS}                       ;
                                fi
                                if [[ -f "${TO}" ]]
                                then
                                        rm -f ${TO}                                     ;
                                        if [[ "${QUIET}" == "NO" ]]
                                        then
                                                if [ $? -eq 0 ]
                                                then
                                                        printf "%s\n" "Script "${TO}" removed successfully"     ;
                                                else
                                                        printf "%s\n" "Error "$?" when removing "${TO}          ;
                                                fi
                                        fi
                                fi
                        fi
                        if [[ -n "${XAFTER}" ]]
                        then
                                if [[ -n "${XUSER}" ]]
                                then
                                        sudo su - ${XUSER} << END_SU
                                        eval "${XAFTER}"                            ;
END_SU
                                else
                                        eval "${XAFTER}"                            ;
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
