#!/bin/bash
# Fred Denis -- Feb 16th 2021
# Set database services with the failback = yes option to enable automatic rebalance
# to the preferred instance(s) -- feature available from 19c
#
# History:
# 20210216 - Fred Denis - Initial release
#
  TS="date "+%Y-%m-%d_%H%M%S""   # A timestamp for a nice outut in a logfile
  DB=".*"                        # Default we do not choose a specific DB
GREP=".*"                        # We dont grep something specific
GREP="19"                        # this is a 19c feature
 YES="no"                        # To automatically answer yes to the system modifiation warning (silent execution)
#
# Usage function
#
usage() {
    printf "\n\033[1;37m%-8s\033[m\n" "NAME"                ;
    cat << END
        $(basename $0) - Set database services with the failback = yes option to enable automatic rebalance
            to the preferred instance(s) -- feature available from 19c
END

    printf "\n\033[1;37m%-8s\033[m\n" "SYNOPSIS"            ;
    cat << END
        $0 [-d] [-g] [-h]
END

    printf "\n\033[1;37m%-8s\033[m\n" "DESCRIPTION"            ;
    cat << END
        $(basename $0):
        - Set database services with the failback = yes option to enable automatic rebalance to the preferred instance(s) -- feature available from 19c
        - Is based on /etc/oratab and oraenv which has to work; if you use a custom way of setting your environment, $(basename $0) cannot guess and may not work
        - Ignores any ASM, MGMTDB or agent entries from /etc/oratab
        - Works as root or oracle user
        - May not work with databases under different owners
END

    printf "\n\033[1;37m%-8s\033[m\n" "OPTIONS"            ;
    cat << END
        -d:    a (no key sensitive) database name taken from /etc/oratab  (optional, default is all databases from /etc/oratab)
        -g:    a (no key sensitive) string to grep from /etc/oratab       (optional, default is we grep ${GREP} from /etc/oratab)
        -y:    Automatically answer yes to the system modification warning at start of the execution (does a silent execution)

        -h:    Shows this help
END

    printf "\n\033[1;37m%-8s\033[m\n" "EXAMPLES"            ;
    cat << END
        $0                  # Set failback to yes to all the database defined in /etc/oratab
        $0 -d ABCD          # Ony for the  ABCD database
        $0 -g 19            # For what contains 19 in /etc/oratab
        $0 -g dbhome_1      # For what contains dbhome_1 in /etc/oratab

END
exit 999
}
#
# Options
#
while getopts "g:d:yh" OPT; do
        case ${OPT} in
        g)     GREP="${OPTARG}"                                  ;;
        d)       DB="${OPTARG}"                                  ;;
        y)      YES="yes"                                        ;;
        h)    usage                                              ;;
        \?)   echo "Invalid option: -$OPTARG" >&2; usage         ;;
        esac
done
#
# Do the job
#
if [[ "${YES}" != "yes" ]]; then
    printf "\033[1;33m%s\033[m\n" "$($TS) [QUESTION] You are about to modify your system (failback = yes to your databases services), are you sure you want to proceed ? [y/n] (yes/exit)"
    read answer
    if [[ "${answer}" != "y" ]]; then
        printf "\033[1;31m%s\033[m\n" "$($TS) [ERROR] not a y answer; exiting."
        exit 238
    fi
fi
printf "\033[1;33m%s\033[m" "$($TS) [INFO] It may be slow if you have many services as srvctl is slow when a database has many services."
for X in $(cat /etc/oratab | awk -F ":" '{print $1":"$2}' | grep -E "^[Aa-Zz]" | grep -i "${GREP}" | grep -iv agent | grep -iv asm | grep -i "${DB}:" ); do
    DB=$(echo ${X} | awk -F ":" '{print $1}')
    . oraenv <<< "${DB}" > /dev/null 2>&1
    printf "\n\033[1;36m%s\033[m\n" "$($TS) [INFO] Database: ${DB}"
    for X in $(srvctl config service -d "${DB}"  | grep -E 'Service name|Failback' | sed s'/^Service/\nService/' |\
           awk -F ":" '{    if ($1 == "Service name")
           {    gsub(" ", "", $2);
                S=$2;
                getline;
                if ($0 !~ /Failback/) {
                    printf("%s|%s\n", S, "false")  ;
                } else {
                    gsub(" ", "", $2)              ;
                    printf("%s|%s\n", S, $2)       ;
                }
              }
           }'); do
         SVC=$(echo $X | awk -F "|" '{print $1}')
    FAILBACK=$(echo $X | awk -F "|" '{print tolower($2)}')
    if [[ "${FAILBACK}" = "true" ]]; then
        printf "\033[1;36m%s\033[m\n" "$($TS) [INFO] Service ${SVC} is already in failback mode."
    else
        printf "\033[1;36m%s\033[m\n" "$($TS) [INFO] Setting service ${SVC} in failback mode."
        srvctl modify service -d ${DB} -s ${SVC} -failback yes
        if [ $? -eq 0 ]; then
            printf "\033[1;36m%s\033[m\n" "$($TS) [INFO] Succesfully set the service ${SVC} in failback mode."
        else
            printf "\033[1;31m%s\033[m\n" "$($TS) [ERROR] Error when setting the service ${SVC} in failback mode better stopping now."
            exit 555
        fi
    fi
    done
done
