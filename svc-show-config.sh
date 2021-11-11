#!/bin/bash
# Fred Denis -- Feb 2021 -- fred.denis3@gmail.com -- http://unknowndba.blogspot.com
# svc-show-config.sh - show nice tables with the databases services configuration, can also relocate services to preferred instances (https://bit.ly/307P7F8)
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
# More info and git repo: https://bit.ly/307P7F8 -- https://github.com/freddenis/oracle-scripts
#
# The current script version is 20211111
#
# History :
#
# 20211111 - Fred Denis - GPLv3 licence, speed crsctl up using -attr
# 20211019 - Fred Denis - Use OLR instead of oraenv
# 20210901 - Fred Denis - Well placed services now appear in GREEN
#                         We do not generate the commands for offline services as we assume there is a good reason
#                           for the services to be offline (like the instance is down or the service is disabled)
#                         Option --badonly to only show the badly configured services
#                         Option --relocate to relocate services (shortcut for --badonly --toprefonly --force --do)
#                         Option --ungrep to grep -v some databases we want to ignore
# 20210216 - Fred Denis - Initial release
#
        TS="date "+%Y-%m-%d_%H%M%S""   # A timestamp for a nice outut in a logfile
        DB=".*"                        # Default we do not choose a specific DB (--db)
      GREP=".*"                        # We grep something specific (--grep)
    UNGREP="sgsjhfgsjfghjfgfjgsdf$$"   # We ungrep (grep -v) something specific (--ungrep)
    TOPREF="False"                     # If we show the commands to relocate the services to preferred nodes or not (--pref and --prefonly)
HIDE_TABLE="False"                     # Hide the services tables (only used by --prefonly)
     FORCE="False"                     # Wether we stop the services with -f or not (--force)
        DO="False"                     # Restart the service son preferred instances or not (--do)
   BADONLY="False"                     # Only show badly configured services (--badonly)
      TEMP=$(mktemp)                   # A tempfile
       OLR="/etc/oracle/olr.loc"       # olr.loc file to get crs home if oratab does not have ASM entry
#
# Usage function
#
usage() {
    printf "\n\033[1;37m%-8s\033[m\n" "NAME"                ;
    cat << END
    svc-show-config.sh - show nice tables with the databases services configuration, can also relocate services to preferred instances (https://bit.ly/307P7F8)
END

    printf "\n\033[1;37m%-8s\033[m\n" "SYNOPSIS"            ;
    cat << END
    $0 [-d]   [-g]     [-G]       [-p]         [-P]             [-f]      [-r]   [-b]        [-R]         [-h]
    $0 [--db] [--grep] [--ungrep] [--showcode] [--showcodeonly] [--force] [--do] [--badonly] [--relocate] [--help]
END

    printf "\n\033[1;37m%-8s\033[m\n" "DESCRIPTION"            ;
    cat << END
    $(basename $0):
    Shows nice tables with the databases services configuration:
    Service name, Preferred instances, Available instances, Failback (Yes or No), Role (Primary, Standby)
    - Based on the databases registered in CRS
    - Works as root or oracle user
    - May not work with databases under different owners
    - Can also reolocate to the preferred instances (be aware that this is a force relocate by default, if you want a non force service relocation, you should check the failback yes feature: https://bit.ly/3bg9z8D)
END

    printf "\n\033[1;37m%-8s\033[m\n" "OPTIONS"            ;
    cat << END
    -g | --grep                        ) a (no key sensitive) string to grep in the DB name and ORACLE_HOME                (optional)
    -G | --ungrep                      ) a (no key sensitive) string to ungrep (grep -v) in the DB name and ORACLE_HOME    (optional)
    -d | --db                          ) a (no key sensitive) database name taken from CRS                                 (optional)
    -p | --showcode     | --topref     ) also shows the commands to run to restart the services on the preferred instances (optional)
    -P | --showcodeonly | --toprefonly ) only shows the commands to run to restart the services on the preferred instances (optional)
    -f | --force                       ) use -f option to stop service (kill the currently connected sessions)             (optional)
    -b | --badonly                     ) Show only the badly configured services, default is ${BADONLY}                    (optional)
    -r | --do                          ) do the stop on available / start on preferred instances, default is ${DO}         (optional)
    -R | --relocate                    ) Relocate the services (shortcut for --badonly --toprefonly --force --do)

    -h | --help                        ) shows this help
END

    printf "\n\033[1;37m%-8s\033[m\n" "EXAMPLES"            ;
    cat << END
    $0                  # Services config of all the databases from /etc/oratab
    $0 --db ABCD        # Show services config of the ABCD database
    $0 --grep 19        # Show services config of what contains 19 in /etc/oratab
    $0 -g dbhome_1      # Show services config of what contains dbhome_1 in /etc/oratab

END
exit 999
}
#
# Options
#
SHORT="g:,G:,d:,p,P,f,r,b,R,h"
 LONG="grep:,ungrep:,db:,topref,toprefonly,force,do,badonly,relocate,showcode,showcodeonly,help"
#
options=$(getopt -a --longoptions "${LONG}" --options "${SHORT}" -n "$0" -- "$@")
#
if [[ $? -ne 0 ]]; then
    printf "\033[1;31m%s\033[m\n" "$($TS) [ERROR] Invalid options provided: $*; use -h for help; cannot continue." >&2
    exit 864
fi
#
eval set -- "${options}"
#
while true; do
    case "$1" in
        -g | --grep       )    GREP="$2"                                                              ; shift 2 ;;
        -G | --ungrep     )  UNGREP="$2"                                                              ; shift 2 ;;
        -d | --db         )      DB="$2"                                                              ; shift 2 ;;
        -p | --showcode     | --topref     )  TOPREF="True"                                           ; shift   ;;
        -P | --showcodeonly | --toprefonly )  TOPREF="True"; HIDE_TABLE="True"                        ; shift   ;;
        -f | --force      )   FORCE="True"                                                            ; shift   ;;
        -r | --do         )  TOPREF="True"; HIDE_TABLE="True"; DO="True"                              ; shift   ;;
        -b | --badonly    ) BADONLY="True"                                                            ; shift   ;;
        -R | --relocate   ) BADONLY="True"; TOPREF="True"; HIDE_TABLE="True"; DO="True"; FORCE="True" ; shift   ;;
        -h | --help       ) usage                                                                     ; shift   ;;
        --                ) shift                                                                     ; break   ;;
    esac
done
#
# Do the job
#
if [[ "${HIDE_TABLE}" == "False" ]]; then
    printf "\033[1;33m%s\033[m" "$($TS) [WARNING] It may be slow if you have many services as srvctl is slow when a database has many services."
fi
if [[ -f "${OLR}" ]]; then
    export ORACLE_HOME=$(cat "${OLR}" | grep "^crs_home" | awk -F "=" '{print $2}')
    export ORACLE_BASE=$(${ORACLE_HOME}/bin/orabase)
    export        PATH="${PATH}:${ORACLE_HOME}/bin"
else
    . oraenv <<< $(ps -ef | grep pmon | grep asm | awk '{print $NF}' | sed s'/^.*_//') > /dev/null 2>&1
fi
if ! type crsctl > /dev/null 2>&1; then
    printf "\033[1;31m%s\033[m" "$($TS) [ERROR] crsctl not found;  please check that ASM is correct in /etc/oratab; cannot continue."
    exit 456
fi
for X in $(crsctl stat res -p -w "TYPE = ora.database.type" -attr "NAME,ORACLE_HOME" | awk -F "=" '{split($2,db,"."); getline; print db[2]":"$2}' | sort | uniq | grep -i "${GREP}" | grep -iv "${UNGREP}" | grep -i "${DB}:"); do
    DB=$(echo ${X} | awk -F ":" '{print $1}')
    OH=$(echo ${X} | awk -F ":" '{print $2}')
    SRVCTL="${OH}/bin/srvctl"
    if [[ "${HIDE_TABLE}" == "False" ]]; then
        printf "\n\033[1;36m%s\033[m\n" "$($TS) [INFO] Database: ${DB} -- ${OH}"
    fi
    (echo "srvctl:${DB}:${SRVCTL}"; export ORACLE_HOME=${OH}; ${SRVCTL} config service -d "${DB}"; ${SRVCTL} status service -d "${DB}" | sed s'/ /:/g') \
        | awk -F ":" -v topref="${TOPREF}" -v hide="${HIDE_TABLE}" -v badonly="${BADONLY}"\
                     -v  force="${FORCE}" 'BEGIN {  # some colors
                                 COLOR_BEGIN =       "\033[1;"              ;
                                   COLOR_END =       "\033[m"               ;
                                         RED =       "31m"                  ;
                                       GREEN =       "32m"                  ;
                                      YELLOW =       "33m"                  ;
                                        BLUE =       "34m"                  ;
                                        TEAL =       "36m"                  ;
                                       WHITE =       "37m"                  ;
                                         COL =       20                     ; # Column size
                                       COL_S =       12                     ; # Service name
                                       COL_P =       12                     ; # preferred
                                       COL_A =       12                     ; # Available
                                       COL_F =       10                     ; # Failback
                                       COL_R =       12                     ; # Role
                                     COL_RUN =       10                     ; # Where service is running
                                      COL_ED =        8                     ; # Service is enabled / disabled
                      }
                      #
                      # A function that just print a "---" white line
                      #
                      function print_a_line(size) {
                          printf("%s", COLOR_BEGIN WHITE)                   ;
                          for (k=1; k<=size; k++) {printf("%s", "-");}      ;
                          printf("%s", COLOR_END"\n")                       ;
                      }
                      #
                      # A function to center the outputs with colors
                      #
                      function center(str, n, color, sep) {
                          right = int((n - length(str)) / 2)                                                              ;
                          left  = n - length(str) - right                                                                 ;
                          return sprintf(COLOR_BEGIN color "%" left "s%s%" right "s" COLOR_END sep, "", str, "" )         ;
                      }
                      #
                      # Get a string and return it with a nice case: first character in upper case ad the others in lower case (ABCD => Abcd)
                      #
                      function nice_case(str) {
                          return sprintf("%s", toupper(substr(str,1,1)) tolower(substr(str,2,length(str))))               ;
                      }
                      #
                      # Get a table and generate srvctl stop / start service
                      #
                      function gen_srvctl(in_tab, in_command, in_force) {
                          txt="" ;
                          split(in_tab, temp_pref, ",") ;
                          oh=srvctl ;
                          sub("/bin.*$", "", oh) ;

                          for (k=1; k<=length(temp_pref); k++) {
                              txt=txt"export ORACLE_HOME="oh";"
                              txt=txt""sprintf("%s,", srvctl " " in_command " service -d " db " -s " S " -i " temp_pref[k] " "in_force) ;
                          }
                          delete temp_pref ;
                          return txt ;
                      }
                      {  gsub(" ", "", $2);
                         if ($1 == "srvctl") {db=$2; srvctl=$3 }   # Srvctl commands with correct OH per DB
                         # srvctl config srevice
                         if ($1 == "Service name")        {SVC=tolower($2); tab_svc[SVC]=SVC; tab_fail[SVC]="False";
                                                           if (length($2) > COL_S) {COL_S = length($2)}
                                                          }
                         if ($1 == "Preferred instances") {       tab_pref[SVC]=$2; if(length($2) > COL_P) {COL_P = length($2)}}
                         if ($1 == "Available instances") {      tab_avail[SVC]=$2; if(length($2) > COL_A) {COL_A = length($2)}}
                         if ($1 ~ /Failback/)             {       tab_fail[SVC]=$2;}
                         if ($1 == "Service role")        {       tab_role[SVC]=$2; if(length($2) > COL_R) {COL_R = length($2)}}
                         if ($1 ~ /^Service is/)          {       ED=$0; sub("Service is ", "", ED);  tab_ed[SVC]=ED; if(length(ED) > COL_ED) {COL_ED = length(ED)}}

                         # srvctl status service
                         if ($0 ~ "is:running") {
                             tab_run[tolower($2)] = $NF ;
                             if(length($NF) > COL_RUN) {COL_RUN = length($NF)}
                         } else {
                             tab_run[tolower($2)] = "Offline" ;
                         }
                      }
                      END {
                        if (force == "True") { force_opt="-f" } else { force_opt="" }
                        if (hide == "False") {
                            if (length(tab_svc) == 0) {
                                printf("%s", COLOR_BEGIN YELLOW) ;
                                printf("%s", "No service found, skipping . . .")     ;
                                printf("%s", COLOR_END"\n")                          ;
                                exit ;
                            }
                            TAB_SIZE=COL_S+COL_P+COL_A+COL_F+COL_R+COL_RUN+7         ;
                            print_a_line(TAB_SIZE)                                   ;
                            # Table header
                            printf("|%s", center("Service"        , COL_S,   TEAL))  ;
                            printf("|%s", center("Pref inst"      , COL_P,   TEAL))  ;
                            printf("|%s", center("Avail inst"     , COL_A,   TEAL))  ;
                            printf("|%s", center("Run on"         , COL_RUN, TEAL))  ;
                            printf("|%s", center("Failback"       , COL_F,   TEAL))  ;
                            #printf("|%s", center("Status"         , COL_ED,  TEAL))  ;
                            printf("|%s", center("Role"           , COL_R,   TEAL))  ;
                            printf("|%s\n" , "")                                     ;
                            print_a_line(TAB_SIZE)                                   ;

                        } # end of if hide == False
                            asort(tab_svc, tab_svc_sorted)                # Sort array to have service sorted
                            for (i=1; i<=length(tab_svc_sorted); i++){
                                S=tab_svc_sorted[i]                                  ;
                                if (badonly == "True") {
                                    if (tab_run[S]  == "Offline")  {continue;}
                                    if (tab_pref[S] == tab_run[S]) {continue;}
                                }
                                if (hide == "False") {
                                    printf("|%-"COL_S"s", tab_svc[S])                          ;
                                    printf("|%s", center(tab_pref[S]  , COL_P, WHITE))         ;
                                    printf("|%s", center(tab_avail[S] , COL_A, WHITE))         ;
                                }
                                if (tab_run[S] != "") {
                                    if (tab_pref[S] == tab_run[S]) {
                                        RUN_COLOR=GREEN  }
                                    else {
                                        RUN_COLOR=RED
                                        if (tab_run[S] != "Offline") {
                                            srvctl_commands=srvctl_commands""gen_srvctl(tab_avail[S], "stop" , force_opt) ;
                                            srvctl_commands=srvctl_commands""gen_srvctl(tab_pref[S] , "start", ""       ) ;
                                        }
                                    }
                                }
                                if (hide == "False") {
                                    printf("|%s", center(tab_run[S], COL_RUN, RUN_COLOR))

                                    if (tab_fail[S] != "true") {FAILBACK_COLOR=RED} else {FAILBACK_COLOR=GREEN} ;
                                    printf("|%s", center(tab_fail[S], COL_F, FAILBACK_COLOR));

                                    if (tab_ed[S] != "enabled") {ED_COLOR=RED} else {ED_COLOR=GREEN} ;
                                    #printf("|%s", center(tab_ed[S], COL_ED, ED_COLOR));
                                    #printf("|%s", center("", COL_ED, ED_COLOR));

                                    printf("|%s", center(nice_case(tab_role[S]), COL_R , WHITE))   ;
                                    printf("|%s\n" , "")                                       ;
                                }
                            }
                            if (hide == "False") {
                                print_a_line(TAB_SIZE)                                           ;
                            }
                            if (srvctl_commands != "" && topref == "True") {
                                if (hide == "False") {
                                    printf("%s\n", "Commands to restart the services on the preferred instance(s):");
                                }
                                sub(/,$/, "", srvctl_commands) ;
                                split(srvctl_commands, temp, ",") ;
                                for (x=1; x<=length(temp); x++) {
                                    printf("%s\n", temp[x]) ;
                                }
                                #printf("\n") ;
                            }
                        }' | tee -a "${TEMP}"

if [[ "${DO}" == "True" ]]; then
    printf "\033[1;36m%s\033[m\n" "$($TS) [INFO] Restarting the services onto the preferred instances, this can take some time . . ."
    chmod u+x "${TEMP}"
    bash "${TEMP}"
    if [ $? -eq 0 ]; then
        printf "\033[1;36m%s\033[m\n" "$($TS) [INFO] Services have been successfully restarted on the preferred instances."
    else
        printf "\033[1;33m%s\033[m\n" "$($TS) [WARNING] Some issues happened when restarting the services on the preferred instances; please check the logs."
    fi
fi
rm -f "{TEMP}"
done

