#!/bin/bash
# Fred Denis -- Jun 2016 -- http://unknowndba.blogspot.com -- fred.denis3@gmail.com
#
# This scripts shows a clear and colored status of the ASM used and free space
# Please have a look at the usage function or $0 -h for the available options and their description
# More information and screenshots : https://unknowndba.blogspot.ca/2018/03/asmdush-far-better-du-for-asmcmd.html
#
# A note on the --nocp option
# Note that the --nocp asmcmd option (it disables the connection pooling) has been originaly implemented
# as a workaround of a bug that appeared with the April 2016 PSU
# It resolves error messages like this one :
# sh: -c: line 0: unexpected EOF while looking for matching `''
# sh: -c: line 1: syntax error: unexpected end of file
#
#
# The current version of the script is 20190906
#
# 20190906 - Fred Denis - A new -V option to show the version of the script
# 20190219 - Fred Denis - Some had issues with the instance list, I then moved from sed to cut to fix it -- Thanks Jakub !
# 20181218 - Fred Denis - A new -n option to print with no color -- DEFAULT_NOCOLOR can be used to modify the default behavior
#                         Fixed the regexp to list the instances running
# 20180827 - Fred Denis - A better regexp to list the instances running
# 20180503 - Fred Denis - GI 12c introduces a "Logical_Sector" column, took this into account (Thanks Leon !)
# 20180327 - Fred Denis - "Raw Used " label for the subdirectories "Mirror_used_MB" column, adjustments in the help
# 20180318 - Fred Denis - Shows only mirrored sizes by default and the total non mirrored size only shown with the -v option
# 20180211 - Fred Denis -  Many improvements :
#                       - -d options to list the subdirectories of a directory
#                       - -v option to show the Raw Free and Reserverd size
#                       - -m -g and -t to choose the Unit you want the report to be in
#                       - Default values and verbosity can be changed using the DEFAULT_UNIT and the DEFAULT_VERBOSE variables
#                       - A nice usage function
# 20170719 - Fred Denis - Remove the --nocp option as default
#

#
# Default values (when no option is specified in the command line)
# The last uncommented value wins
#
DEFAULT_UNIT="MB"       # asmcmd default
DEFAULT_UNIT="GB"
DEFAULT_UNIT="TB"

DEFAULT_VERBOSE="Yes"
DEFAULT_VERBOSE="No"

DEFAULT_NOCOLOR="Yes"   # Print with no color
DEFAULT_NOCOLOR="No"    # Print with colors

#
# Colored thresholds (Red, Yellow, Green)
#
            CRITICAL=90
             WARNING=75

#
# A color for a nice header
#
    WHITE="\033[1;37m"
END_COLOR="\033[m"

#
# Show the version of the script (-V)
#
show_version()
{
        VERSION=`awk '{if ($0 ~ /^# 20[0-9][0-9][0-1][0-9]/) {print $2; exit}}' $0`
        printf "\n\t\033[1;36m%s\033[m\n" "The current version of "`basename $0`" is "$VERSION"."          ;
}
#
# An usage function
#
usage()
{
printf "\n\033[1;37m%-8s\033[m\n" "NAME"                ;
cat << END
        asmdu.sh - Shows a nice summary of the ASM diskgroups sizes
END

printf "\n\033[1;37m%-8s\033[m\n" "SYNOPSIS"            ;
cat << END
        $0 [-d] [-m -g -t] [-n] [-v] [-V] [-h]
END

printf "\n\033[1;37m%-8s\033[m\n" "DESCRIPTION"         ;
cat << END
        $0 needs to be executed as the GI owner user to be able to use asmcmd
        With no option $0 will be showing what instances are running and a size summary for each DiskGroup
END

printf "\n\033[1;37m%-8s\033[m\n" "OPTIONS"             ;
cat << END
        -d        The directory you want the size details

        -v        Verbose -- show the "Total Raw", "Raw Free" and "Reserved" size
                  You can change the default behavior with the DEFAULT_VERBOSE variable

        -m        Shows the output in MB
        -g        Shows the output in GB
        -t        Shows the output in TB
        -m -g -t  The default Unit can be specified using the DEFAULT_UNIT variable
                  If more than one of these options is specified, the last one wins

        -n        Shows the output with no color (handy to send it by email)

        -V        Shows the version of the script
        -h        Shows this help

END
exit 123
}

#
# Parameters management
#

    PARAM_UNIT=""
 PARAM_VERBOSE=""

while getopts "d:mgtnvhV" OPT; do
        case ${OPT} in
        d)                  D=${OPTARG}                         ;;
        m)         PARAM_UNIT="MB"                              ;;
        g)         PARAM_UNIT="GB"                              ;;
        t)         PARAM_UNIT="TB"                              ;;
        n)      PARAM_NOCOLOR="Yes"                             ;;
        v)      PARAM_VERBOSE="Yes"                             ;;
        V)      show_version; exit 567                          ;;
        h)      usage                                           ;;
        \?) echo "Invalid option: -$OPTARG" >&2; usage          ;;
        esac
done

if [[ -z ${PARAM_UNIT} ]]
then    # No parameter specified, we use the default
        UNIT=${DEFAULT_UNIT}
else
        UNIT=${PARAM_UNIT}
fi
if [[ -z ${PARAM_VERBOSE} ]]
then    # No parameter specified, we use the default
        VERBOSE=${DEFAULT_VERBOSE}
else
        VERBOSE=${PARAM_VERBOSE}
fi
if [[ -z ${PARAM_NOCOLOR} ]]
then    # No parameter specified, we use the default
        NOCOLOR=${DEFAULT_NOCOLOR}
else
        NOCOLOR=${PARAM_NOCOLOR}
fi
if [[ ${NOCOLOR} == "Yes" ]]
then
            WHITE=""
        END_COLOR=""
fi

#
# Set the ASM env
#
OLD_SID=${ORACLE_SID}
ORACLE_SID=`ps -ef | grep pmon | grep asm | awk '{print $NF}' | sed s'/asm_pmon_//' | egrep "^[+]"`
export ORAENV_ASK=NO
. oraenv > /dev/null 2>&1


#
# A quick list of the instances that are running on the server
#
ps -ef | grep pmon | grep -v grep | awk '{print $NF}' | cut -d_ -f3,4 | sort | awk -v H="`hostname -s`" 'BEGIN {printf("\n%s", "Instances running on " H " : ")} { printf("%s, ", $0)} END{printf("\n")}' | sed s'/, $//'


#
# Manage parameters
#
if [[ -z $D ]]
then        # No directory provided, will check all the DG
            DG=`asmcmd lsdg | grep -v State | awk '{print $NF}' | sed s'/\///'`
        SUBDIR="No"                 # Do not show the subdirectories details if no directory is specified
else
            DG=`echo $D | sed s'/\/.*$//g'`
fi


#
# A header
#
printf "\n%25s%16s${WHITE}%16s${END_COLOR}"   "DiskGroup" "Redundancy" "Total ${UNIT}"  # "Raw Free ${UNIT}" "Reserved ${UNIT}"  "Usable ${UNIT}" "% Free"
if [[ ${VERBOSE} == "Yes" ]]
then
        printf "%16s%16s%16s" "Raw Total ${UNIT}" "Raw Free ${UNIT}" "Reserved ${UNIT}"
fi
printf "${WHITE}%16s%14s${END_COLOR}\n" "Usable ${UNIT}" "% Free"

printf "%25s%16s${WHITE}%16s${END_COLOR}"   "---------"     "-----------" "--------"
if [[ ${VERBOSE} == "Yes" ]]
then
        printf "%16s%16s%16s"           "------------"  "-----------" "-----------"
fi
printf "${WHITE}%16s${END_COLOR}%14s\n"     "---------"     "------"


#
# Show DG info
#
for X in ${DG}
do
            asmcmd lsdg ${X} | tail -1 |\
                awk -v DG="$X" -v W="$WARNING" -v C="$CRITICAL" -v UNIT="$UNIT" -v VERBOSE="$VERBOSE" -v NOCOLOR="$NOCOLOR" '\
                BEGIN \
                {
                if (NOCOLOR == "Yes")
                {
                 COLOR_BEGIN =           ""                                             ;
                   COLOR_END =           ""                                             ;
                         RED =           ""                                             ;
                       GREEN =           ""                                             ;
                      YELLOW =           ""                                             ;
                       WHITE =           ""                                             ;
                       COLOR =           ""                                             ;
                } else {
                 COLOR_BEGIN =           "\033[1;"                                      ;
                   COLOR_END =           "\033[m"                                       ;
                         RED =           COLOR_BEGIN"31m"                               ;
                       GREEN =           COLOR_BEGIN"32m"                               ;
                      YELLOW =           COLOR_BEGIN"33m"                               ;
                       WHITE =           COLOR_BEGIN"37m"                               ;
                       COLOR =           GREEN                                          ;
                }
                     DIVIDER =           1                                              ;       # Unit divider
                     RED_DIV =           1                                              ;       # Redundancy divider

                        if (UNIT == "GB")       { DIVIDER="1024"}                       ;
                        if (UNIT == "TB")       { DIVIDER="1048576"}                    ;       # 1024 * 1024
                }
                {       if ($2 == "HIGH")           {RED_DIV=3                          ;}      # Redundancy divider
                        if ($2 == "NORMAL")         {RED_DIV=2                          ;}      # Redundancy divider

                       TOTAL = sprintf("%16.2f", $(NF-6)/DIVIDER/RED_DIV)               ;       # Total mirrored in Unit
                      USABLE = sprintf("%16.2f", $(NF-3)/DIVIDER)                       ;       # Usable space in Unit
                        FREE = sprintf("%12d"  , USABLE/TOTAL*100)                      ;       # % Free calculated using the Usable size

                        if ((100-FREE) > W)     { COLOR=YELLOW                          ;}      # Colored %Free thresholds
                        if ((100-FREE) > C)     { COLOR=RED                             ;}      # Colored %Free thresholds

                    printf("%25s%16s%16s", DG, $2, WHITE TOTAL COLOR_END)               ;       # DG Redundancy and Total

                    if (VERBOSE == "Yes")
                    {
                            printf("%16.2f%16.2f%16.2f", $(NF-6)/DIVIDER, $(NF-5)/DIVIDER, $(NF-4)/DIVIDER);       # Total Raw, Raw Free and reserved if Verbose
                    }
                    printf("%16s%14s\n", WHITE USABLE COLOR_END, COLOR FREE COLOR_END)  ;       # Usable and Free %
                }'
done
printf "\n"

#
# Subdirs info
#
if [ -z ${SUBDIR} ]
then
(for DIR in `asmcmd ls ${D}`
do
            echo ${DIR} `asmcmd --nocp du ${D}/${DIR} | tail -1`      # Please look at the "About the --nocp option" notes in the header for more information
#            echo ${DIR} `asmcmd du ${D}/${DIR} | tail -1`
done) | awk -v D="$D" -v UNIT="$UNIT"\
         ' BEGIN {      printf("\n\t\t%40s\n\n", D " subdirectories size")                      ;
                        printf("%25s%16s%16s\n", "Subdir", "Used " UNIT, "Raw Used " UNIT)      ;
                        printf("%25s%16s%16s\n", "------", "-------", "-----------")            ;

                        DIVIDER=1                                                               ;
                        if (UNIT == "GB")       { DIVIDER="1024"        }                       ;
                        if (UNIT == "TB")       { DIVIDER="1048576"     }                       ;   # 1024 * 1024
                 }
                 {
                        use=sprintf("%16.2f", $2/DIVIDER)                                       ;
                        mir=sprintf("%16.2f", $3/DIVIDER)                                       ;

                        printf("%25s%16s%16s\n", $1, use, mir)                                  ;

                        total_use += $2                                                         ;
                        total_mir += $3                                                         ;
                 }
            END  {      total_use = sprintf("%16.2f", total_use/DIVIDER)                        ;
                        total_mir = sprintf("%16.2f", total_mir/DIVIDER)                        ;
                        printf("\n\n%25s%16s%16s\n", "------", "-------", "---------")          ;
                        printf("%25s%16s%16s\n\n", "Total", total_use, total_mir)               ;
                 } '
fi


#
# For information
#
if [[ ${VERBOSE} == "Yes" ]]
then
        printf "\t\t%40s\n\n" "Note : Usable = (Raw Free - Reserved)/Redundancy"                ;
fi

#****************************************************************************************#
#*                          E N D          O F          S O U R C E                     *#
#****************************************************************************************#
