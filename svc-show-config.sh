#!/bin/bash
# Fred Denis -- Feb 16th 2021
# Show nice tables with the databases services configuration
#  - Service name
#  - Preferred instances
#  - Available instances
#  - Failback (Yes or No)
#  - Role (Primary, Standby)
#
# History:
# 20210216 - Fred Denis - Initial release
#
  TS="date "+%Y-%m-%d_%H%M%S""   # A timestamp for a nice outut in a logfile
  DB=".*"                        # Default we do not choose a specific DB
GREP=".*"                        # We dont grep something specific
GREP="19"                        # This is a 19c feature
#
# Usage function
#
usage() {
    printf "\n\033[1;37m%-8s\033[m\n" "NAME"                ;
    cat << END
        $(basename $0) - Show nice tables with the databases services configuration:
            Service name, Preferred instances, Available instances, Failback (Yes or No), Role (Primary, Standby)
END

    printf "\n\033[1;37m%-8s\033[m\n" "SYNOPSIS"            ;
    cat << END
        $0 [-d] [-g] [-h]
END

    printf "\n\033[1;37m%-8s\033[m\n" "DESCRIPTION"            ;
    cat << END
        $(basename $0):
        -  Shows nice tables with the databases services configuration:
               Service name, Preferred instances, Available instances, Failback (Yes or No), Role (Primary, Standby)
        - Is based on /etc/oratab and oraenv which has to work; if you use a custom way of setting your environment, $(basename $0) cannot guess and may not work
        - Ignores any ASM, MGMTDB or agent entries from /etc/oratab
        - Works as root or oracle user
        - May not work with databases under different owners
END

    printf "\n\033[1;37m%-8s\033[m\n" "OPTIONS"            ;
    cat << END
        -d:    a (no key sensitive) database name taken from /etc/oratab  (optional, default is all databases from /etc/oratab)
        -g:    a (no key sensitive) string to grep from /etc/oratab       (optional, default is everything from /etc/oratab)

        -h:    Shows this help
END

    printf "\n\033[1;37m%-8s\033[m\n" "EXAMPLES"            ;
    cat << END
        $0                 # Services config of all the databases from /etc/oratab
        $0 -d ABCD          # Show services config of the ABCD database
        $0 -g 19            # Show services config of what contains 19 in /etc/oratab
        $0 -g dbhome_1      # Show services config of what contains dbhome_1 in /etc/oratab

END
exit 999
}
#
# Options
#
while getopts "g:d::h" OPT; do
        case ${OPT} in
        g)     GREP="${OPTARG}"                                  ;;
        d)       DB="${OPTARG}"                                  ;;
        h)    usage                                              ;;
        \?)   echo "Invalid option: -$OPTARG" >&2; usage         ;;
        esac
done
#
# Do the job
#
printf "\033[1;33m%s\033[m" "$($TS) [INFO] It may be slow if you have many services as srvctl is slow when a database has many services."
for X in $(cat /etc/oratab | awk -F ":" '{print $1":"$2}' | grep -E "^[Aa-Zz]" | grep -i "${GREP}" | grep -iv agent | grep -iv asm | grep -i "${DB}:" ); do
    DB=$(echo ${X} | awk -F ":" '{print $1}')
    . oraenv <<< "${DB}" > /dev/null 2>&1
    printf "\n\033[1;36m%s\033[m\n" "$($TS) [INFO] Database: ${DB}"
    srvctl config service -d "${DB}" \
        | awk -F ":" 'BEGIN {  # some colors
                                 COLOR_BEGIN =       "\033[1;"              ;
                                   COLOR_END =       "\033[m"               ;
                                         RED =       "31m"                  ;
                                       GREEN =       "32m"                  ;
                                      YELLOW =       "33m"                  ;
                                        BLUE =       "34m"                  ;
                                        TEAL =       "36m"                  ;
                                       WHITE =       "37m"                  ;
                                         COL =       20                     ; # Column size
                                       COL_S =       14                     ; # Service name
                                       COL_P =       18                     ; # Prefered
                                       COL_A =       18                     ; # Available
                                       COL_F =       10                     ; # Failback
                                       COL_R =       12                     ; # Role
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
                      {  gsub(" ", "", $2);
                         if ($1 == "Service name")        {SVC=$2; tab_svc[SVC]=$2; tab_fail[SVC]="False";
                                                           if (length($2) > COL_S) {COL_S = length($2)}
                                                          }
                         if ($1 == "Preferred instances") {       tab_pref[SVC]=$2; if(length($2) > COL_P) {COL_P = length($2)}}
                         if ($1 == "Available instances") {      tab_avail[SVC]=$2; if(length($2) > COL_A) {COL_A = length($2)}}
                         if ($1 ~ /Failback/)             {       tab_fail[SVC]=$2;}
                         if ($1 == "Service role")        {       tab_role[SVC]=$2;}
                      }
                      END {
                            if (length(tab_svc) == 0) {
                                printf("%s", COLOR_BEGIN YELLOW) ;
                                printf("%s", "No service found, skipping . . .")  ;
                                printf("%s", COLOR_END"\n")                       ;
                                exit ;
                            }
                            TAB_SIZE=COL_S+COL_P+COL_A+COL_F+COL_R+6 ;
                            print_a_line(TAB_SIZE)                    ;
                            # Table header
                            printf("|%s", center("Service name"   , COL_S, TEAL))  ;
                            printf("|%s", center("Pref instances" , COL_P, TEAL))  ;
                            printf("|%s", center("Avail instances", COL_A, TEAL))  ;
                            printf("|%s", center("Failback"       , COL_F, TEAL))  ;
                            printf("|%s", center("Role"           , COL_R, TEAL))  ;
                            printf("|%s\n" , "")                      ;
                            print_a_line(TAB_SIZE)                    ;

                            asort(tab_svc, tab_svc_sorted)                # Sort array to have service sorted
                            for (i=1; i<=length(tab_svc_sorted); i++){
                                S=tab_svc_sorted[i];
                                printf("|%-"COL_S"s", tab_svc[S])                         ;
                                printf("|%s", center(tab_pref[S]  , COL_P, WHITE))           ;
                                printf("|%s", center(tab_avail[S] , COL_A, WHITE))           ;
                                if (tab_fail[S] != "true") {FAILBACK_COLOR=RED} else {FAILBACK_COLOR=GREEN} ;
                                printf("|%s", center(tab_fail[S]  , COL_F, FAILBACK_COLOR));
                                printf("|%s", center(nice_case(tab_role[S]), COL_R , WHITE))   ;
                                printf("|%s\n" , "")                                       ;
                          }
                          print_a_line(TAB_SIZE)                                           ;
                      }'
done
