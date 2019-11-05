#!/bin/bash
# Fred Denis -- Nov 5th 2019 -- ERS-143
#
# Part of the dagops suite, this script:
# - Checks in the dagops logs and list the errors
# - Generates a new makefile to re execute a previously failed exeuciton skipping the successful steps
#
# The current script version is 20191105
#
# History:
#
# 20191105 - Fred Denis - Initial release
#
# Variables
#
       HERE=`dirname $0`                                # Script directory
        LOG=${HERE}"/logs"                              # Logfiles directory
     TMPDIR=${HERE}"/tmp"                               # Tempfiles directory
  SHOW_ONLY="Yes"                                       # Do we show the errors only ? (-l)
   NEW_UNIQ=$(date +%s)                                 #
        TMP=${TMPDIR}"/"fictemp${RANDOM}
#
# Check log and temp directories
#
for X in ${LOG} ${TMPDIR}
do
        if [[ ! -d "${X}" ]]
        then
                printf "\n\t\033[1;36m%s\033[m\n\n" "Cannot find ${X}; cannot continue."
        fi
done
#
# Options
#
while getopts "lr:u:h" OPT; do
        case ${OPT} in
        l)      SHOW_ONLY="Yes"                                         ;;
        r)         RUN_ID="${OPTARG}"; SHOW_ONLY="No"                   ;;
        u)           UNIQ="${OPTARG}"; SHOW_ONLY="No"                   ;;
        h)         usage                                                ;;
        \?)        echo "Invalid option: -$OPTARG" >&2; usage           ;;
        esac
done
#
# Show the jobs in errors and exit
#
if [[ "${SHOW_ONLY}" = "Yes" ]]
then
        cat ${LOG}/* | grep ^2 |\
        awk -F "|" 'BEGIN\
                {       master = ""     ;
                          uniq = ""     ;
                         first = 1      ;
                        # Some colors
                     COLOR_BEGIN =       "\033[1;"                      ;
                       COLOR_END =       "\033[m"                       ;
                             RED =       "31m"                          ;
                           GREEN =       "32m"                          ;
                          YELLOW =       "33m"                          ;
                            BLUE =       "34m"                          ;
                            TEAL =       "36m"                          ;
                           WHITE =       "37m"                          ;
                }
                function print_a_line(size)
                {
                       printf("%s", COLOR_BEGIN WHITE)                  ;
                       for (k=1; k<=size; k++) {printf("%s", "-");}     ;
                       printf("%s", COLOR_END"\n")                      ;
                }
                function center( str, n, color, sep)
                {       right = int((n - length(str)) / 2)              ;
                      left  = n - length(str) - right                   ;
                      return sprintf(COLOR_BEGIN color "%" left "s%s%" right "s" COLOR_END sep, "", str, "" )   ;
                }
                {       if (($NF > 0) && ($10 == "Done"))
                        {       if ((master != $4) || (uniq != $3))
                                {
                                        master = $4                     ;
                                        run_id = $6                     ;
                                          uniq = $3                     ;
                                        if (first == 0)
                                        {
                                                print_a_line(140)       ;
                                                printf("\n")            ;
                                        }
                                        printf(COLOR_BEGIN TEAL"\n  %-12s%-30s%-14s%-20s=> %-40s"COLOR_END"\n", "Errors for:", "Master: "master, "RUN_ID: "run_id, "Uniq: "uniq, "./rerun.sh -r "run_id" -u "uniq) ;
                                        printf ("%s", center("Job"       , 30, WHITE, "|"))                     ;
                                        printf ("%s", center("Start Date", 22, WHITE, "|"))                     ;
                                        printf ("%s", center("Error"     ,  8, WHITE, "|"))                     ;
                                        printf ("%s", center("SQL"       , 60, WHITE, "" ))                     ;
                                        printf("\n")                                                            ;
                                        print_a_line(140);
                                        first = 0 ;
                                }
                                printf (COLOR_BEGIN WHITE"  %-28s|"COLOR_END, $5)                               ;
                                printf ("%s", center($1  , 22, WHITE, "|"))                                     ;
                                printf ("%s", center($12 ,  8, WHITE, "|"))                                     ;
                                printf (COLOR_BEGIN WHITE"  %-60s"COLOR_END, $11)                               ;
                                printf("\n")                                                                    ;
                        }
                } END\
                {       print_a_line(140)                               ;
                        printf("\n")                                    ;
                }
                '
        exit 789
fi
#
# At this point we need a run_id and an uniq
#
for X in RUN_ID UNIQ
do
        if [[ -z "${!X}" ]]
        then
                echo "A value for "${X}" is needed; run -l to get one."
                exit 567
        fi
done
#
# Check if we can find the old makefile
#
TMPMK="${TMPDIR}/makefile_${UNIQ}_${RUN_ID}"
if [[ ! -f ${TMPMK} ]]
then
        echo ${TMPMK}" not found; cannot continue at this point."
fi
#
# Make some filenames
#
LOGFILE=${LOG}/rerun_${NEW_UNIQ}_${RUN_ID}
   TMP2=${TMPDIR}/makefile_${NEW_UNIQ}_${RUN_ID}
#
# Filter the logfiles
#
cat ${LOG}/*${UNIQ}*${RUN_ID}* | grep ^2 > ${TMP}
#
# Add a " -i SKIPPING " option for run_on_bq.sh consider the previously siuccessful steps as INFO
# and then won't be re executed
#
        awk -F "|" -v TMPMK="${TMPMK}" -v UNIQ="${UNIQ}" -v NEW_UNIQ="${NEW_UNIQ}" '\
                {       if (FILENAME != TMPMK)
                        {       if (($NF == 0) && ($10 == "Done"))
                                {       success[$11] = $11                      ;

                                }
                        } else  # This is the temp makefile
                        {       if ($0 ~ UNIQ)                                  # A new uniq as we will use the same RUN_ID
                                {       gsub(UNIQ, NEW_UNIQ, $0)                ;
                                        found_it = 0                            ;
                                        for (x in success)
                                        {
                                                if ($0 ~ x)
                                                {       print $0 " -i SKIPPING" ;
                                                        found_it = 1            ;
                                                }
                                        }
                                        if (found_it == 0)
                                        {
                                                print $0                        ;
                                        }
                                } else {
                                        print $0                                ;
                                }
                        }
                }
                ' ${TMP} ${TMPMK} > ${TMP2}
#
# Mew makefile has been generatedm we prompt the command to execute it
#
cat << !
        ${TMP2} has been generated, run the below command the execute it:
!
        printf "\n\t\033[1;36m%s\033[m\n\n" "make -f ${TMP2} | tee -a ${LOGFILE}";
#
# Tempfiles deletion
#
for X in ${TMP}
do
        if [[ -f ${X} ]]
        then
                rm -f ${TMP}
        fi
done
#
#
#************************************************************************#
#                       E N D      O F      S O U R C E                 *#
#************************************************************************#
