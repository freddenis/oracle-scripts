#!/bin/bash
# Fred Denis -- May 2021 -- fred.denis3@gmail.com -- http://unknowndba.blogspot.com
# list-ohpatches.sh - show nice tables of the installed and/or missing patches for some GI/DB Oracle Homes (https://bit.ly/3oID4Gs)
# Copyright (C) 2021 Fred Denis
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <https://www.gnu.org/licenses/>.
#
#
# More info and git repo: https://bit.ly/3oID4Gs -- https://github.com/freddenis/oracle-scripts
#
# The current script version is 20211115
#
# History :
#
# 20211115 - Fred Denis - A nice checkmark (or an "ok" if your terminal is not utf8) when a patch is installed to replace the green x
#                         Short options only for AIX as AIX getopt does not support long options (. . .)
#                         Short options can also be forced with export SHORT_OPTIONS="True"
# 20211111 - Fred Denis - GPLv3 licence
# 20210524 - Fred Denis - Initial Release
#
set -o pipefail
#
# Variables
#
     TS="date "+%Y-%m-%d_%H%M%S""                           # A timestamp for a nice outut in a logfile
   GREP="."                                                 # What we grep                  -- default is everything
 UNGREP="nothing_to_ungrep_unless_v_option_is_used$$"       # What we don't grep (grep -v)  -- default is nothing
   COLS=$(tput cols)                                        # Size of the screen
 ORACLE="oracle"                                            # User to run opatch lspatches if script ran as root
# If UTF8, we show a nice checkmark when a patch is here, if not, a simple "ok"
if [[ $(locale charmap) == "UTF-8" ]]; then
    CHECKMARK="True"
else
    CHECKMARK="False"
fi
#
# Cleanup on exit -- this will be executed on normal exit as well as if the script is killed
# The place to cleanup things / send emails whatever happens to the script
#
cleanup() {
    err=$?
    if [[ -s "${TEMP2}" ]]; then
        if [[ "${err}" == "0" ]]; then  # If already an error, no need to check for nb missing patches
            # Check for errors
            NB_ERR=$(cat "${TEMP2}" | awk '{cpt+=$1} END {print cpt}')
            exit "${NB_ERR}"
        fi
    fi
    # Delete tempfiles
    rm -f "${TEMP}" "${TEMP2}"
    exit ${err}
}
sig_cleanup() {
    printf "\033[1;31m%s\033[m\n" "$($TS) [ERROR] I have been killed !" >&2
    exit 666
}
trap     cleanup EXIT
trap sig_cleanup INT TERM QUIT
#
# Usage function
#
usage() {
    printf "\n\033[1;37m%-8s\033[m\n" "NAME"                ;
    cat << END
    $(basename $0) - show nice tables of the installed and/or missing patches for some GI/DB Oracle Homes (https://bit.ly/3oID4Gs)
END

    printf "\n\033[1;37m%-8s\033[m\n" "SYNOPSIS"            ;
    cat << END
    $0 [-g] [-c] [-G] [-v] [-s] [-u] [-h]
END

    printf "\n\033[1;37m%-8s\033[m\n" "DESCRIPTION"         ;
    cat << END
    $(basename $0) Based on oratab, show nice tables of the installed and/or missing patches for some GI/DB Oracle Homes
                   You can then quickly find a missing patch across a RAC system
    $(basename $0) will by default check all the nodes of a cluster (based on olsnodes) which requires ASM to be running
                   and oraenv to be working with the ASM aslias defined in oratab; If you have no ASM alias in oratab,
                   you may suffer from https://unknowndba.blogspot.com/2019/01/lost-entries-in-oratab-after-gi-122.html
                   You can specify a comma separated list of host or a file containing one host per line 
    $(basename $0) by default checks all the homes defined in oratab, you can use --grep/--home and --ungrep/--ignore to limit your home selection (see examples below)
    $(basename $0) relies on opatch lspatches which must run as oracle user (and not root); if the script is started as root,
                   the opatch lspatches commands will be run after su - ${ORACLE} (see -u | --oracleuser for more on this)
    If your system does not support long options, you can force short options using export SHORT_OPTIONS="True"
         
END

    printf "\n\033[1;37m%-8s\033[m\n" "OPTIONS"             ;
    cat << END
    -g | --groupfile            ) A group file containing a list of hosts
    -c | --commalist  | --hosts ) A comma separated list of hosts
    -G | --grep | --oh | --home ) Pattern to grep from /etc/oratab 
    -v | --ungrep | --ignore    ) Pattern to grep -v (ignore) from /etc/oratab 
    -s | --showhomes | --show   ) Just show the homes from oratab resolving the grep/ungrep combinations
    -u | --oracleuser           ) User to use to run opatch lspatches if the script is started as root, default is ${ORACLE}
    -h | --help                 ) Shows this help

END

    printf "\n\033[1;37m%-8s\033[m\n" "EXAMPLES"            ;
    cat << END
    $0                                                       # Analyze and show all the homes of nodes of a cluster
    $0 --show                                                # Show the homes from oratab (only show, dont do anything else)
    $0 --grep grid                                           # Analyze the grid home
    $0 --grep db --ungrep 12                                 # Only the DB homes but not the 12 ones
    $0 --grep db --ungrep 12 --groupfile ~/dbs_group         # Same as above on the hosts contained in the ~/dbs_group file
    $0 --home db --ignore 12 --hosts exa01,exa06             # Same as above but only on hosts exa02 and exa06
    $0 --home db --ignore 12 --hosts exa01,exa06 -u oracle2  # Same as above but started as root; will then su - oracle2 automatically
 
END
exit 999
}
#
# Different OS support
#
OS=$(uname)
case ${OS} in
        SunOS)
                    ORATAB=/var/opt/oracle/oratab
                       AWK=/usr/bin/gawk                        ;;
        Linux)
                    ORATAB=/etc/oratab
                       AWK=`which awk`                          ;;
        HP-UX)
                    ORATAB=/etc/oratab
                       AWK=`which awk`                          ;;
        AIX)
                    ORATAB=/etc/oratab
                       AWK=`which awk`                          
             SHORT_OPTIONS="True"                               ;;
        *)          echo "Unsupported OS, cannot continue."
                    exit 666                                    ;;
esac
#
# Options -- long and short, short only for AIX as AIX getopt does not support long options (. . .)
#
if [[ "${SHORT_OPTIONS}" != "True" ]]; then
    SHORT="g:,c:,g:,v:,u:,sh"
     LONG="groupfile:,commalist:,hosts:,grep:,oh:,home:,ungrep:,ignore:,oracleuser:,showhomes,help"
    # Check if the specified options are good
    options=$(getopt -a --longoptions "${LONG}" --options "${SHORT}" -n "$0" -- "$@")
    # If not, show the usage and exit
    if [[ $? -ne 0 ]]; then
        printf "\033[1;31m%s\033[m\n" "$($TS) [ERROR] Invalid options provided: $*; use -h for help; cannot continue." >&2
        exit 864
    fi
    eval set -- "${options}"
    while true; do
        case "$1" in
            -g | --groupfile           )      GROUP="$2"        ; shift 2 ;;
            -c | --commalist | --hosts )      HOSTS="$2"        ; shift 2 ;;
            -G | --grep | --oh | --home)       GREP="$2"        ; shift 2 ;;
            -v | --ungrep | --ignore   )     UNGREP="$2"        ; shift 2 ;;
            -u | --oracleuser          )     ORACLE="$2"        ; shift 2 ;;
            -s | --showhomes           ) SHOW_HOMES="True"      ; shift   ;;
            -h | --help                ) usage                  ; shift   ;;
            --                         ) shift                  ; break   ;;
        esac
    done
else                 # Short options for AIX as AIX getopt does not support long options (. . .)
    while getopts "g:,c:,G:,v:,u:,sh" OPT; do
        case ${OPT} in
            g)                                GROUP="${OPTARG}"           ;;
            c)                                HOSTS="${OPTARG}"           ;;
            G)                                 GREP="${OPTARG}"           ;;
            v)                               UNGREP="${OPTARG}"           ;;
            u)                               ORACLE="${OPTARG}"           ;;
            s)                           SHOW_HOMES="True"                ;;
            h)                           usage                            ;;
            \?)        echo "Invalid option: -${OPTARG}" >&2; usage       ;;
        esac
    done
fi
#
# Options verifications
#
if [[ $(id -u) -eq 0 ]]; then                    # We are root
    su - "${ORACLE}" -c id > /dev/null 2>&1      # Check if we can su as ${ORACLE}
    if [ $? -ne 0 ]; then
        printf "\033[1;31m%s\033[m\n" "$($TS) [ERROR] Script has been executed as root and the user to use to run opatch lspatches is ${ORACLE}; unfortunately we were unable to connect to this user; cannot continue." >&2
        exit 122
    fi
fi
if [[ ! -f "${ORATAB}" ]]; then
    printf "\033[1;31m%s\033[m\n" "$($TS) [ERROR] Cannot find ${ORATAB}; cannot continue." >&2
    exit 123
fi
if [[ ! -f "${AWK}" ]]; then
    printf "\033[1;31m%s\033[m\n" "$($TS) [ERROR] Cannot find a modern versin of awk; cannot continue." >&2
    exit 124
fi
#
# Show Homes only if -s option specified
#
if [[ "${SHOW_HOMES}" == "True" ]]; then
    printf "\n\033[1;37m%-8s\033[m\n\n" "ORACLE_HOMEs in ${ORATAB}:"                    ;
    cat ${ORATAB} | grep -v "^#" | grep -v "^$" | grep -v agent | ${AWK} 'BEGIN {FS=":"} { printf("\t%s\n", $2)}' | grep ${GREP} | grep -v ${UNGREP} | sort | uniq
    printf "\n"
    exit 0
fi
if [[ -z "${HOSTS}" ]]; then           # HOSTS is empty, -c option not provided
    if [[ -f "${GROUP}" ]]; then       # Group file exists, we make it a comma separated list
        HOSTS=$(cat "${GROUP}" | grep -v "^$" | grep -v "^#" | ${AWK} '{printf("%s,", $1)}' | sed s'/,$//')
    else                               # No group file nor hosts lists, lets get the node list from olsnodes
        . oraenv <<< $(ps -ef | grep pmon | grep asm | awk '{print $NF}' | sed s'/.*+/+/') > /dev/null 2>&1
        if [ $? -ne 0 ]; then
            printf "\033[1;31m%s\033[m\n" "$($TS) [ERROR] ASM does not seem to be running and/or oraenv not working so we cannot guess the node list; please use -g or -c to specify a node list then and restart." >&2
            exit 125
        else                           # ASM env all set, lets get the nodes list automatically
            HOSTS=$($(which olsnodes) | ${AWK} '{printf ("%s,",$1)}' | sed s'/,$//')
        fi
    fi
fi
#
#
#
TEMP2=$(mktemp)
printf "\033[1;36m%s\033[m\n" "$($TS) [INFO] Starting collecting GI/OH patch information"
printf "\033[1;33m%s\033[m\n" "$($TS) [WARNING] It may be a bit slow if you have many nodes and patches as opatch lspatches is slow"
for OH in $(cat ${ORATAB} | grep -v "^#" | grep -v "^$" | grep -v agent | grep ${GREP} | grep -v ${UNGREP} | awk 'BEGIN {FS=":"} {print $2}'| sort | uniq); do
    if [[ -f "${OH}/OPatch/opatch" ]] && [[ -x "${OH}/OPatch/opatch" ]]; then
        TEMP=$(mktemp)
        [[ $(id -u) -eq 0 ]] && chmod 777 "${TEMP}"
        printf "\033[1;36m%s\033[m\n" "$($TS) [INFO] Proceeding with ${OH} . . ."
        for HOST in $(echo ${HOSTS} | sed 's/,/ /g'); do
            if [[ $(id -u) -eq 0 ]]; then                   # Script started as root, need to sudo as oracle for opatch lspatches
                su - "${ORACLE}" << END
                    ssh -q "${HOST}" "${OH}/OPatch/opatch lspatches" | grep "^[1-9]" | sort | awk -v H="${HOST}" -F ";" '{print H";"\$1";"\$2}' | sed 's/(.*)//g' >> "${TEMP}"
END
            else 
                ssh -q "${HOST}" "${OH}/OPatch/opatch lspatches" | grep "^[1-9]" | sort | awk -v H="${HOST}" -F ";" '{print H";"$1";"$2}' | sed 's/(.*)//g' >> "${TEMP}"
            fi
        done
        "${AWK}" -v hosts="${HOSTS}" -v cols="${COLS}" -v tempfile="${TEMP2}" -v CHECKMARK="${CHECKMARK}" \
        'BEGIN {          FS =       ";"                    ;
                    # some colors
                 COLOR_BEGIN =       "\033[1;"              ;
                   COLOR_END =       "\033[m"               ;
                         RED =       "31m"                  ;
                       GREEN =       "32m"                  ;
                      YELLOW =       "33m"                  ;
                        BLUE =       "34m"                  ;
                        TEAL =       "36m"                  ;
                       WHITE =       "37m"                  ;
                     MISSING =       "Missing"              ; # Patch is missing
                    if (CHECKMARK == "True") {                # Patch is installed
                        HERE = "\xE2\x9C\x94"               ;
                    } else {
                        HERE = "ok"                         ;
                    }

                    # Default columns size
                    COL_NODE =        8                     ;
                   COL_PATCH =        6                     ;
                   COL_DESCR =       10                     ;
                        cols =       cols -5                ; # Screen size, dont want to be too short

                  nb_missing = 0                            ; # Number of missing patches
                   split(hosts, tab_hosts, ",")             ; # An array with the hosts; n is number of hosts
                   n = asort(tab_hosts)                     ; # Sort by hostname
                   for (x in tab_hosts){
                       if (length(tab_hosts[x]) > COL_NODE) {COL_NODE = length(tab_hosts[x]) + 2}
                   }
        }
        #
        # A function to center the outputs with colors
        #
        function center( str, col_size, color, sep) {       right = int((col_size - length(str)) / 2)                                                                      ;
            left  = col_size - length(str) - right                                                                         ;
            return sprintf(COLOR_BEGIN color "%" left "s%s%" right "s" COLOR_END sep, "", str, "" )                 ;
        }
        #
        # A function that just print a "---" white line
        #
        function print_a_line(size){
            printf("%s", COLOR_BEGIN WHITE)                          ;
            for (k=1; k<=size; k++) {printf("%s", "-");}             ;       # n = number of nodes
            printf("%s", COLOR_END"\n")                              ;
        }
        {   # Save all the patches list
            if ($2 in all_patches){ cpt++ ;
            } else {
                all_patches[$2] = $3 ;
                if (length($2) > COL_PATCH) {COL_PATCH = length($2) + 2}
                if (length($3) > COL_DESCR) {COL_DESCR = length($3) + 1}
            }
            # Save all the patches per node
            tab_patches[$1][$2] = $2  ;
        }
        END {
            # To make it fit and nice depending on the screen size
            out_size=(COL_PATCH+n*COL_NODE+COL_DESCR+n+2)                   ;
            if (out_size > cols) {
                COL_DESCR = COL_DESCR - (out_size - cols)                   ;
                out_size = cols                                             ;
            }              
            # Header
            print_a_line(out_size)                                          ;
            printf("%-"COL_PATCH"s|", " Patch id")                          ;
            for (i=1; i<=n; i++){                                             # Each node
                printf("%s", center(tab_hosts[i], COL_NODE, WHITE, "|"))    ;
            }
            printf(" %-"COL_DESCR"s", "Patch description")                  ;
            printf("\n")                                                    ;
            print_a_line(out_size)                                          ;
            y = asorti(all_patches, all_patches_sorted)
            for (j=1; j<=y; j++){
                patch_id = all_patches_sorted[j] ;
                printf("%s", center(patch_id, COL_PATCH, WHITE, "|"))       ;
                for (i=1; i<=n; i++){                                         # Each node
                    if (length(tab_patches[tab_hosts[i]][patch_id]) > 0){
                        printf("%s", center(HERE   , COL_NODE, GREEN, "|")) ;
                    } else {
                        printf("%s", center(MISSING, COL_NODE, RED  , "|")) ;
                        nb_missing++                                        ;
                    }
                }
                printf(" %-"COL_DESCR"s", substr(all_patches[patch_id], 1, COL_DESCR)) ;
                printf("\n")                                                ;
            }
            # Footer
            print_a_line(out_size)                                          ;
            print nb_missing >> tempfile                                    ;
        }' "${TEMP}"
        rm -f "${TEMP}"
    else
        printf "\033[1;31m%s\033[m\n" "$($TS) [ERROR] Cannot find ${OH}/OPatch/opatch; will skip ${OH}" >&2
    fi
done
