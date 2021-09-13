#!/bin/bash
# Fred Denis -- Jan 2016 -- http://unknowndba.blogspot.com -- fred.denis3@gmail.com
#
# Quickly shows a status of all running instances accross a 11g, 12c, 18c+ cluster
# The script just needs to have a working oraenv, if rac-status.sh hangs, you may suffer from http://bit.ly/2IODPJo (alternatively ,see the -e option)
# Ultimately, feel free to contact me
#
# Please have a look at http://bit.ly/2MFkzDw  for some details and screenshots
# The latest version of the script can be downloaded here : http://bit.ly/2XEXa6j
#
# The current script version is 20210912
#
# History :
#
# 20210912 - Fred Denis - Implement new GI 21c PDB status; also -p option to show/hide PDBs, default is we show the PDBs
#                         STATE_DETAILS does not seem to be implemented (yet ?) for PDBs so the only info we have
#                           is Online/Offline, we do not know if PDBs are READ WRITE or READ ONLY -- SEED not here either
#                         Fixed a bug with the recently restarted resource, also use LAST_RESTART and LAST_STATE_CHANGE
#                           as they sometimes dont seem to be correctly updated but the mix I made seems OK
# 20210908 - Fred Denis - Fixed a bad character next to cluster status with -u (no color) option
# 20210825 - Fred Denis - Cluster upgrade status was causing an issue for HAS -- now fixed
#                         There was some leftover color codes with -u option -- now fixed
#                         Added the PDB associated to the services (the PDB status is not shown as only GI 21c should have this information)
# 20210824 - Fred Denis - New -D option to specify a list of DB to show (and not the others)
#                         New -S option to specify a list of services to show (and not the others)
#                         The VIP IPs are not also shown on the right of the table
# 20210714 - Fred Denis - Upgrade state is now shown (you want it to be NORMAL)
#                       - Use of olr.loc to set up the crs environment before using oratab
#                       - OH are sorted to avoid random order from CRS (useful when using rac-mon.sh)
#                       - All standby resources (instances, instances type, services) are now shown in BLUE, primary resources in WHITE
#                       - Offline standby type services on a primary instance now appear with a GREEN Offline as it is
#                          expected to have these services to be offline, they will be online only if the DB becomes a standby
#                          Same applies for primary services on standby databases
#                       - advm devices are now shown on the right of the table
#                       - Option -k shows the advm devices next to the acfs FS (handy if you need to remount some)
#                       - Option -K hides the acfs fs and the advm devices
# 20200415 - Fred Denis - mktemp to create tempfiles
# 20200413 - Fred Denis - Fixed a bug with offline resources in green for the tech resources
#                       - Fixed a bug with disabled instances
#                       - Indentation
# 20200317 - Fred Denis - A new -t option (included in -a) which shows the tech resources (DGs, vips, etc ...)
#                         Also provide insights to the user if we cannot find an ASM entry in oratab as oraenv wont work
# 20200305 - Fred Denis - Fixed a bug when the hostname contains twice the cluster name
# 20190906 - Fred Denis - A new -V option to show the version of the script
# 20190830 - Fred Denis - Show a red "x" also when instances and listeners are disabled
# 20190829 - Fred Denis - Show a red "x" if a service is disabled as well as a legend below the services table
# 20190828 - Fred Denis - Option -L to always show full hostnames; also fixed a bug with the name of the cluster shown
# 20190725 - Fred Denis - When STATUS and TARGET are different, shows with a WITH_BACK2 background color and a legend
#                         Fixed a bug where the recently restarted legend was shown when it should not
# 20190701 - Fred Denis - Minor fixes, alignements issues with the sorting
# 20190626 - Fred Denis - Better sorting, better recently restarted legend
# 20190621 - Fred Denis - Fixed a bug on the sorting when version was different as other (12.1 instead of 12.1.0.0)
#                       - Option -w now also supports d for day, w for week, m for month and y for year to specify the delay
# 20190620 - Fred Denis - Fixed an issue with the sorting when there was recently restarted instances
# 20190617 - Fred Denis - New -c option to sort the databases output
# 20190606 - Fred Denis - Show a yellow background when a resource has been restarted less than DIFF_HOURS hours
#                         A new -w option can be use to specify a number of hours through the command line
#                         Owners and groups which contained numbers were ignored, this is fixed
# 20190524 - Fred Denis - Fixed a bug when hostnames had more than 1 "db" pattern in their names
# 20190508 - Fred Denis - Show the whole service name and not only part of it when it contains "."
# 20190426 - Fred Denis - which gawk for AIX
# 20190104 - Fred Denis - A new -r option to Reverse the colors (useful for clear terminal backgrounds)
#                         A new -u option to show an Uncolored output
# 20190325 - Fred Denis - Solaris sed does not support sed -i, use gsed instead
#                         New -e option to NOT use oraenv to set the ASM environment but to use the current manually set environment
#                               (USE_ORAENV="NO" on top of the script to have this permanently)
# 20190318 - Fred Denis - Dont show the owner:group legend about '' menaing same as above if only 1 Home
# 20190307 - Fred Denis - Added owner:group behind the ORACLE_HOME (useful when owner are different) -- thanks Andrey for the feature idea !
#                         Also removed the P for Primary and S for Stanby legend; it looks self explanatory enough already
# 20190204 - Fred Denis - Oracle Restart support
# 20190130 - Fred Denis - 11g support (BREAK_HERE); 11g and 12c crsctl outputs are quite different
#                                               - A new -o option to specify a file to save the crsctl commands output
#                                               - A new -f option to specify an input file (a file generated by the -o option for example)
# 20190122 - Fred Denis - Multi OS support for AWK (especially for Solaris)
# 20190115 - Fred Denis - Fixed minor alignement issues
#                         Add grep (-g) and ungrep (-v) feature
# 20181110 - Fred Denis - Show short names in the tables instead of the whole hostnames if possible for better visibility
#                       - Col 1 and col 2 now align dynamically depending on the largest element to keep all the tables well aligned
#                       - Dynamic calculation of an offser for the status column size depending on the number of nodes
#                       - This can also be fixed by setting a non 0 value to COL_NODE_OFFSET on top of the script
#                       - Better alignements, centered databases and service were not nice, they are now left aligned which is more clear
# 20181010 - Fred Denis - Added the services
#                         Added default value and options to show and hide some resources (./rac-status.sh -h for more information)
# 20181009 - Fred Denis - Show the usual blue "-" when a target is offline on purpose instead of a red "Offline" which was confusing
# 20180921 - Fred Denis - Added the listeners
# 20180227 - Fred Denis - Make the the size of the DB column dynamic to handle very long database names (Thanks Michael)
#                       - Added a (P) for Primary databases and a (S) for Stanby for color blind people who
#                         may not see the difference between white and red (Thanks Michael)
# 20180225 - Fred Denis - Make the multi status like "Mounted (Closed),Readonly,Open Initiated" clear in the table by showing only the first one
# 20180205 - Fred Denis - There was a version alignement issue with more than 10 different ORACLE_HOMEs
#                       - Better colors for the label "White for PRIMARY, Red for STANBY"
# 20171218 - Fred Denis - Modify the regexp to better accomodate how the version can be in the path (cannot get it from crsctl)
# 20170620 - Fred Denis - Parameters for the size of the columns and some formatting
# 20170619 - Fred Denis - Add a column type (RAC / RacOneNode / Single Instance) and color it depending on the role of the database
#                         (WHITE for a PRIMARY database and RED for a STANDBY database)
# 20170616 - Fred Denis - Shows an ORACLE_HOME reference in the Version column and an ORACLE_HOME list below the table
# 20170606 - Fred Denis - A new 12cR2 GI feature now shows the ORACLE_HOME in the STATE_DETAILS column from "crsctl -v"
#                       - Example :     STATE_DETAILS=Open,HOME=/u01/app/oracle/product/11.2.0.3/dbdev_1 instead of STATE_DETAILS=Open in 12cR1
# 20170518 - Fred Denis - Add  a readable check on the ${DBMACHINE} file - it happens that it exists but is only root readable
# 20170501 - Fred Denis - First release
#
#
# Variables
#
        TMP=$(mktemp)                                                     # A tempfile
       TMP2=$(mktemp)                                                     # Another tempfile
  DBMACHINE=/opt/oracle.SupportTools/onecommand/databasemachine.xml       # File where we should find the Exadata model as oracle user
       GREP="."                                                           # What we grep                  -- default is everything
     UNGREP="nothing_to_ungrep_unless_v_option_is_used$$"                 # What we don't grep (grep -v)  -- default is nothing
 USE_ORAENV="YES"                                                         # Use oraenv to set the ASM env (-e changes this to NO)
    REVERSE="NO"                                                          # Revert the colors to make them visible, useful for clear terminal backgrounds
WITH_COLORS="YES"                                                         # Output with colors, (-b changes this to NO); set to NO for permanent no colored output
      WHITE="37m"                                                         # White color code
       TEAL="36m"                                                         # Teal color code
      GREEN="32m"                                                         # Green color code
    REDBACK="41m"                                                         # Nothing related to the spider, just a red background :)
 DIFF_HOURS="24"                                                          # Nb of hours the instance has been restarted
    SORT_BY=""                                                            # Column to sort by (see the help for possible values)
 LONG_NAMES="NO"                                                          # If we try to shorten the host names in the tables or not
        OLR="/etc/oracle/olr.loc"                                         # olr.loc file to get crs home if oratab does not have ASM entry
   ADVM_DEV="False"                                                       # Show ADVM devices next to ACFS FS
   HIDE_DEV="False"                                                       # Hide ACFS FS and ADVM devices
#
# Choose the information what you want to see -- the last uncommented value wins
# ./rac-status.sh -h for more information
  SHOW_DB="YES"                 # Databases
 #SHOW_DB="NO"
 SHOW_PDB="YES"                 # PDBs
#SHOW_PDB="NO"
SHOW_LSNR="YES"                 # Listeners
#SHOW_LSNR="NO"
 SHOW_SVC="YES"                 # Services
 SHOW_SVC="NO"
SHOW_TECH="YES"                 # Tech (DGs, ONS, etc ...)
SHOW_TECH="NO"
#
# Number of spaces between the status and the "|" of the column - this applies before and after the status
# A value of 2 would print 2 spaces before and after the status and like |  Open  |
# A value of 8 would print |        Open         |
# A value of 99 means that this parameter is dynamically calculated depending on the number of nodes
# A non 99 value is applied regardless of the number of nodes
COL_NODE_OFFSET=99
#
# Different OS support
#
OS=`uname`
case ${OS} in
    SunOS)
        ORATAB="/var/opt/oracle/oratab"                 ;
           AWK=`which gawk`                             ;
           SED=`which gsed`                             ;;
    Linux)
        ORATAB="/etc/oratab"                            ;
           AWK=`which awk`                              ;
           SED=`which sed`                              ;;
     HP-UX)
        ORATAB="/etc/oratab"                            ;
           AWK=`which awk`                              ;
           SED=`which sed`                              ;;
     AIX)
        ORATAB="/etc/oratab"                            ;
           AWK=`which gawk`                             ;
           SED=`which sed`                              ;;
       *)  printf "\n\t\033[1;31m%s\033[m\n\n" "Unsupported OS, cannot continue."           ;
           exit 666                                     ;;
esac
#
# Check if we have an AWK and a SED to continue
#
if [[ ! -f "${AWK}" ]]; then
    printf "\n\t\033[1;31m%s" "No awk found on your system, cannot continue, if you run Solaris, please ensure that gawk is in your path"
    printf "\t%s\033[m\n\n" "${AWK}"
    exit 678
fi
if [[ ! -f "${SED}" ]]; then
    printf "\n\t\033[1;31m%s" "No sed found on your system, cannot continue, if you run Solaris, please ensure that gsed is in your path"
    printf "\t%s\033[m\n\n" "${SED}"
    exit 679
fi
#
# Show the version of the script (-V)
#
show_version() {
    VERSION=`${AWK} '{if ($0 ~ /^# 20[0-9][0-9][0-1][0-9]/) {print $2; exit}}' $0`
    printf "\n\t\033[1;36m%s\033[m\n" "The current version of "`basename $0`" is "$VERSION"."          ;
}
#
# An usage function
#
usage() {
    printf "\n\033[1;37m%-8s\033[m\n" "NAME"                ;
    cat << END
        `basename $0` - A nice overview of databases, listeners, services and tech resources running across a GI 12c+
END

    printf "\n\033[1;37m%-8s\033[m\n" "SYNOPSIS"            ;
    cat << END
        $0 [-a] [-n] [-d] [-p] [-l] [-s] [-t] [-g] [-v] [-D] [-S] [-c] [-o] [-f] [-e] [-L] [-r] [-u] [-k] [-K] [-w] [-h]
END

    printf "\n\033[1;37m%-8s\033[m\n" "DESCRIPTION"         ;
    cat << END
        `basename $0` needs to be executed with a user allowed to query GI using crsctl; oraenv also has to be working
        `basename $0` will show what is running or not running accross all the nodes of a GI 12c :
                - The databases instances (and the ORACLE_HOME they are running against)
                - The type of database : Primary, Standby, RAC One node, Single
                - The listeners (SCAN Listener and regular listeners)
                - The services
        With no option, `basename $0` will show what is defined by the variables :
                - SHOW_DB       # To show the databases instances
                - SHOW_PDB      # To show the PDBs (only if your GI is >= 21c)
                - SHOW_LSNR     # To show the listeners
                - SHOW_SVC      # To show the services
                - SHOW_TECH     # To show the tech stuff (DGs, ONS, etc ...)
                These variables can be modified in the script itself or you can use command line option to revert their value (see below)

END

    printf "\n\033[1;37m%-8s\033[m\n" "OPTIONS"             ;
    cat << END
        -a        Show everything regardless of the default behavior defined with SHOW_DB, SHOW_LSNR, SHOW_SVC and SHOW_TECH
        -n        Show nothing  regardless of the default behavior defined with SHOW_DB, SHOW_LSNR, SHOW_SVC and SHOW_TECH
        -a and -n are handy to erase the defaults values:
                        $ ./rac-status.sh -n -d                         # Show the databases output only
                        $ ./rac-status.sh -a -s                         # Show everything but the services (then the listeners and the databases)

        -d        Revert the behavior defined by SHOW_DB  ; if SHOW_DB   is set to YES to show the databases by default, then the -d option will hide the databases
        -p        Revert the behavior defined by SHOW_PDB ; if SHOW_PDB  is set to YES to show the databases by default, then the -p option will hide the PDBs
        -l        Revert the behavior defined by SHOW_LSNR; if SHOW_LSNR is set to YES to show the listeners by default, then the -l option will hide the listeners
        -s        Revert the behavior defined by SHOW_SVC ; if SHOW_SVC  is set to YES to show the services  by default, then the -s option will hide the services
        -t        Revert the behavior defined by SHOW_TECH; if SHOW_TECH is set to YES to show the tech resources  by default, then the -t option will hide the tech resources

        -g        Act as a grep command to grep a pattern from the output (key sensitive)
        -v        Act as "grep -v" to ungrep from the output
        -g and -v examples :
                        $ ./rac-status.sh -g Open                       # Show only the lines with "Open" on it
                        $ ./rac-status.sh -g Open                       # Show only the lines with "Open" on it
                        $ ./rac-status.sh -g "Open|Online"              # Show only the lines with "Open" or "Online" on it
                        $ ./rac-status.sh -g "Open|Online" -v 12        # Show only the lines with "Open" or "Online" on it but no those containing 12

        -D        Comma separated list of databases (key sensitive) to show -- only the services related to these DBs will be shown:
                        $ ./rac-status.sh -D prod                       # Show only the "prod" database
                        $ ./rac-status.sh -D prod1,prod2,prod3          # Show only the prod1, prod2 and prod3 databases

        -S        Comma separated list of services (key sensitive) to show -- default is we show all the services:
                        $ ./rac-status.sh -D prod -S svc1,svc4          # Show only the svc1 and svc4 services

        -c        Column to sort by, please have a look at "Sort the database output" in http://bit.ly/2MFkzDw for more details on this -c option

        -o        Specify a file to save the crsctl commands output
                       $ ./rac-status.sh -o /tmp/rac-status_output.log
        -f        A file to use as input file (one generated by the -o option for example)
                       $ ./rac-status.sh -f /tmp/rac-status_output.log

        -e        Do not use oraenv to set the ASM environment but relies on the current environment
                  Set USE_ORAENV="NO" on top of the script to have a permanent -e option

        -L        Do not try to shorten the host names, show the entire host names

        -r        Reverse the colors (useful for clear terminal backgrounds)

        -u        Shows the Uncolored output (no colors); set WITH_COLORS="NO" on top of the script to have it permanently

        -k        Shows the ADVM devices on the same line as the ACFS FS (handy to remount some FS), default is ${ADVM_DEV}
        -K        Do not show the ACFS FS nor the ADVM devices, default is ${HIDE_DEV}

        -w        Shows a yellow background when a resource has been restarted less than the number of hours in parameter (default is ${DIFF_HOURS})
                    h for hours (default) d for day, w for week, m for month and y for year can be used to specify the delay:
                        $ ./rac-status.sh -w 24         # 24 hours
                        $ ./rac-status.sh -w 24h        # 24 hours
                        $ ./rac-status.sh -w 2d         # 2 days
                        $ ./rac-status.sh -w 3m         # 3 months
        -V        Shows the version of the script
        -h        Shows this help

        Note : the options are cumulative and can be combined with a "the last one wins" behavior :
                $ $0 -a -l              # Show everything but the listeners (-a will force show everything then -l will hide the listeners)
                $ $0 -n -d              # Show only the databases           (-n will force hide everything then -d with show the databases)

                Experiment and enjoy  !

END
exit 123
}
#
# Options
#
while getopts "andpslLhg:v:o:f:eruw:c:tkKVD:S:" OPT; do
    case ${OPT} in
    a)         SHOW_DB="YES"; SHOW_LSNR="YES"; SHOW_SVC="YES"; SHOW_TECH="YES"; SHOW_PDB="YES"      ;;
    n)         SHOW_DB="NO" ; SHOW_LSNR="NO" ; SHOW_SVC="NO" ; SHOW_TECH="NO" ; SHOW_PDB="NO"       ;;
    d)         if [[ "${SHOW_DB}"   == "YES" ]]; then   SHOW_DB="NO"; else   SHOW_DB="YES"; fi      ;;
    p)         if [[ "${SHOW_PDB}"  == "YES" ]]; then  SHOW_PDB="NO"; else  SHOW_PDB="YES"; fi      ;;
    s)         if [[ "${SHOW_SVC}"  == "YES" ]]; then  SHOW_SVC="NO"; else  SHOW_SVC="YES"; fi      ;;
    l)         if [[ "${SHOW_LSNR}" == "YES" ]]; then SHOW_LSNR="NO"; else SHOW_LSNR="YES"; fi      ;;
    t)         if [[ "${SHOW_TECH}" == "YES" ]]; then SHOW_TECH="NO"; else SHOW_TECH="YES"; fi      ;;
    D)         LISTDB="${OPTARG}"                                                                   ;;
    S)        LISTSVC="${OPTARG}"                                                                   ;;
    L)     LONG_NAMES="YES"                                                                         ;;
    g)           GREP="${OPTARG}"                                                                   ;;
    c)        SORT_BY="${OPTARG}"                                                                   ;;
    v)         UNGREP="${OPTARG}"                                                                   ;;
    f)           FILE="${OPTARG}"                                                                   ;;
    o)            OUT="${OPTARG}"                                                                   ;;
    e)     USE_ORAENV="NO"                                                                          ;;
    r)        REVERSE="YES"                                                                         ;;
    w)     DIFF_HOURS="${OPTARG}"                                                                   ;;
    u)    WITH_COLORS="NO"                                                                          ;;
    k)       ADVM_DEV="True"                                                                        ;;
    K)       HIDE_DEV="True"                                                                        ;;
    V)      show_version; exit 567                                                                  ;;
    h)         usage                                                                                ;;
    \?)        echo "Invalid option: -${OPTARG}" >&2; usage                                         ;;
    esac
done
#
# Manage the diff hours depending on the unit in the -w option
#
DIFF_HOURS_UNIT=${DIFF_HOURS: -1}
#
if [[ ! "${DIFF_HOURS_UNIT}" =~ [0-9] ]]; then
    HOURS=`echo ${DIFF_HOURS} | sed s'/.$//'`

    case ${DIFF_HOURS_UNIT} in
    h)  NB_HOURS=1                                                                      ;;
    d)  NB_HOURS=24                                                                     ;;
    w)  NB_HOURS=$((24*7))                                                              ;;
    m)  NB_HOURS=$((24*7*31))                                                           ;;
    y)  NB_HOURS=$((24*7*31*365))                                                       ;;
    esac

    DIFF_HOURS=$(($HOURS * $NB_HOURS))
else
    DIFF_HOURS_UNIT="h"
              HOURS="${DIFF_HOURS}"
fi
#
# If we dont show the DB we dont need to sort
#
if [[ "${SHOW_DB}" == "NO" ]]; then
    SORT_BY=""
fi
#
# Check that the input file is here if specified
#
if [[ "${REVERSE}" == "YES" ]]; then
    WHITE="30m"     ;           # Black
fi
if [ -n "$FILE" ]; then       # Input file specified, we wont run any crsctl command and rely on the file as input
    if [ ! -f ${FILE} ]; then
        printf "\n\t\033[1;31m%s\033[m\n\n" "Cannot find the ${FILE} input file; cannot continue"
        exit 222
    else    # we use $FILE as input
        printf "\n\t\033[1;34m%s\033[m\n\n" "Proceeding with the ${FILE} file as input file"
    fi
fi
if [[ -z "$FILE" ]]; then               # This is not needed when using an input file
    if [[ "${USE_ORAENV}" == "YES" ]]; then
        #
        # Set the ASM env to be able to use crsctl commands
        #
        if [[ -f "${OLR}" ]]; then
            export ORACLE_HOME=$(cat "${OLR}" | grep "^crs_home" | awk -F "=" '{print $2}')
            export ORACLE_BASE=$(${ORACLE_HOME}/bin/orabase)
            export        PATH="${PATH}:${ORACLE_HOME}/bin"
        else
            ORACLE_SID=$(ps -ef | grep pmon | grep asm | ${AWK} '{print $NF}' | sed s'/asm_pmon_//' | egrep "^[+]")
            if [[ -f "${ORATAB}" ]]; then
                grep ^${ORACLE_SID} ${ORATAB} > /dev/null 2>&1
                if [ $? -ne 0 ]; then
                    printf "\n\t\033[1;31m%s\033[m\n\n" "Cannot find an entry for ${ORACLE_SID} in ${ORATAB}. You can consider using the -e option or you may suffer from https://unknowndba.blogspot.com/2019/01/lost-entries-in-oratab-after-gi-122.html; cannot continue at this point."
                    exit 888
                fi
            fi
            export ORAENV_ASK=NO
            . oraenv > /dev/null 2>&1
        fi
    fi
    if ! type crsctl > /dev/null 2>&1; then
        printf "\n\t\033[1;31m%s\033[m\n\n" "Cannot find crsctl, cannot continue, please check if oraenv works or set your environment manually and use the -e option."          ;
        exit 777
    fi
    #
    # List of the nodes of the cluster
    # Try to find if there is "db" in the hostname, if yes we can delete the common "<clustername>" pattern from the hosts for visibility
    #
    SHORT_NAMES="NO"
    if [[ $(olsnodes | head -1 | sed s'/,.*$//g' | tr '[:upper:]' '[:lower:]') == *"db"* && "${LONG_NAMES}" == "NO" ]]; then
               NODES=$(olsnodes | sed s'/^.*db/db/g' | ${AWK} '{if (NR<2){txt=$0} else{txt=txt","$0}} END {print txt}')
        CLUSTER_NAME=$(olsnodes | head -1 | sed s'/db.*$//g')
         SHORT_NAMES="YES"
    else
               NODES=$(olsnodes | ${AWK} '{if (NR<2){txt=$0} else{txt=txt","$0}} END {print txt}')
        CLUSTER_NAME=$(olsnodes -c)
    fi
    NAME_OF_THE_CLUSTER=$(olsnodes -c)
    # if oracle restart, olsnodes is here but returns nothing, we then set the NODES with the current hostname
    if [[ -z "${NODES}" ]]; then
        NODES=$(hostname -s)
    fi
    if [[ "${WITH_COLORS}" == "YES" ]]; then
            COLOR_FOR_CLUSTER="\e[1;"${TEAL}
        END_COLOR_FOR_CLUSTER="\e[m"
    else
            COLOR_FOR_CLUSTER=""
        END_COLOR_FOR_CLUSTER=""
    fi
    printf "\n\t%s"${COLOR_FOR_CLUSTER}"%s${END_COLOR_FOR_CLUSTER}" "Cluster " "${NAME_OF_THE_CLUSTER}"
    #
    # Show the Exadata model if possible (if this cluster is an Exadata)
    #
    if [[ -f "${DBMACHINE}" ]] && [[ -r "${DBMACHINE}" ]]; then
        MODEL=$(grep -i MACHINETYPES ${DBMACHINE} | sed -e s':</*MACHINETYPES>::g' -e s'/^ *//' -e s'/ *$//')
        printf "%s"${COLOR_FOR_CLUSTER}"%s${END_COLOR_FOR_CLUSTER}" " is a " "$MODEL"
    fi
    #
    # Check the status of the cluster to show an alert if it is not NORMAL
    #
    CLUSTER_STATUS=$(crsctl query crs activeversion -f > /dev/null && (crsctl query crs activeversion -f | sed  s'/^.*The cluster upgrade state is \[//' | sed s'/\].*$//') || echo "")
    if [[ "${WITH_COLORS}" == "YES" ]]; then
        if [[ "${CLUSTER_STATUS}" == "NORMAL" ]]; then
            COLOR_FOR_CLUSTER="\e[1;"${GREEN}
        else
            COLOR_FOR_CLUSTER="\e[1;${REDBACK}"
        fi
    else
        COLOR_FOR_CLUSTER=""
    fi
    if [[ -n "${CLUSTER_STATUS}" ]]; then
        printf "%s"${COLOR_FOR_CLUSTER}"%s${END_COLOR_FOR_CLUSTER}%s" " (upgrade state is " "${CLUSTER_STATUS}" ")"
    fi
    printf "\n\n"
    #
    # Get the info we want
    #
    cat /dev/null                                               > "${TMP}"
    if [[ -n "${LISTDB}" ]]; then                               # A list of DB is specified with the -D option
        for X in $(echo "${LISTDB}" | sed s'/,/ /g'); do
            [[ -n "${DBCRSFILTER}" ]] && DBCRSFILTER="${DBCRSFILTER} or"
             DBCRSFILTER="${DBCRSFILTER} (NAME = ora.${X}.db)"
            PDBCRSFILTER="${DBCRSFILTER} (NAME = ora.${X}.db)"
        done 
         DBCRSFILTER="(TYPE = ora.database.type) AND ${DBCRSFILTER}"
        PDBCRSFILTER="(TYPE = ora.pdb.type) AND ${DBCRSFILTER}"
    else                                                        # No specific Db list specified
         DBCRSFILTER="TYPE = ora.database.type"
        PDBCRSFILTER="TYPE = ora.pdb.type"
    fi
    if [[ "${SHOW_DB}" == "YES" ]]; then
        crsctl stat res -p -w "${DBCRSFILTER}"                  >> "${TMP}"
        crsctl stat res -v -w "${DBCRSFILTER}"                  >> "${TMP}"
    fi
    if [[ "${SHOW_PDB}" == "YES" ]]; then
        crsctl stat res -p -w "${PDBCRSFILTER}"                 >> "${TMP}"
        crsctl stat res -v -w "${PDBCRSFILTER}"                 >> "${TMP}"
    fi
    if [[ "${SHOW_LSNR}" == "YES" ]]; then
        crsctl stat res -v -w "TYPE = ora.listener.type"        >> "${TMP}"
        crsctl stat res -p -w "TYPE = ora.listener.type"        >> "${TMP}"
        crsctl stat res -v -w "TYPE = ora.scan_listener.type"   >> "${TMP}"
        crsctl stat res -p -w "TYPE = ora.scan_listener.type"   >> "${TMP}"
        crsctl stat res -v -w "TYPE = ora.leaf_listener.type"   >> "${TMP}"
        crsctl stat res -p -w "TYPE = ora.leaf_listener.type"   >> "${TMP}"
        crsctl stat res -v -w "TYPE = ora.asm_listener.type"    >> "${TMP}"
        crsctl stat res -p -w "TYPE = ora.asm_listener.type"    >> "${TMP}"
    fi
    if [[ "${SHOW_SVC}" == "YES" ]]; then
        crsctl stat res -v -w "TYPE = ora.service.type"         >> "${TMP}"
        crsctl stat res -p -w "TYPE = ora.service.type"         >> "${TMP}"
    fi
    if [[ "${SHOW_TECH}" == "YES" ]]; then
        crsctl stat res -v -w "((TYPE != ora.database.type) AND (TYPE != ora.listener.type) AND (TYPE != ora.scan_listener.type) AND (TYPE != ora.service.type) AND (TYPE != ora.leaf_listener.type) AND (TYPE != ora.asm_listener.type))" >> "${TMP}"
        crsctl stat res -p -w "((TYPE != ora.database.type) AND (TYPE != ora.listener.type) AND (TYPE != ora.scan_listener.type) AND (TYPE != ora.service.type) AND (TYPE != ora.leaf_listener.type) AND (TYPE != ora.asm_listener.type))" >> "${TMP}"
    fi

    # Easiest way to manage the different versions of crsctl outputs
    awk '{if ($1 ~ /^NAME=/) {print "BREAK_HERE"; print  $0} else {print $0}}' "${TMP}" > "${TMP2}"
    cp "${TMP2}" "${TMP}"

    if [[ "${SHORT_NAMES}" == "YES" ]]; then
        "${SED}" -i "s/$CLUSTER_NAME//" "${TMP}"
    fi
    NB_NODES=$(olsnodes | wc -l)
else            # If we use an input file
    cp "${FILE}" "${TMP}"
       NODES=$(grep LAST_SERVER $TMP | awk -F"=" '{print $2}' | sort | uniq | grep -v "^$" | awk '{if (NR<2){txt=$0} else{txt=txt","$0}} END {print txt}')
    NB_NODES=$(grep LAST_SERVER $TMP | awk -F"=" '{print $2}' | sort | uniq | wc -l)
fi      # End if [ -z "$FILE" ]
#
# Define the offset to apply to the status column depending on the number of nodes to make the tables visible for big implementations
#
if [[ "${COL_NODE_OFFSET}" == "99" ]]; then
    COL_NODE_OFFSET=3       ;
    if [ "$NB_NODES" -eq "2" ]; then COL_NODE_OFFSET=6      ;       fi      ;
    if [ "$NB_NODES" -eq "4" ]; then COL_NODE_OFFSET=5      ;       fi      ;
    if [ "$NB_NODES" -gt "4" ]; then COL_NODE_OFFSET=3      ;       fi      ;
fi

"${AWK}" -v           NODES="${NODES}"           \
         -v col_node_offset="${COL_NODE_OFFSET}" \
         -v         REVERSE="${REVERSE}"         \
         -v      DIFF_HOURS="${DIFF_HOURS}"      \
         -v           HOURS="${HOURS}"           \
         -v DIFF_HOURS_UNIT="${DIFF_HOURS_UNIT}" \
         -v    ADVM_DEVICES="${ADVM_DEV}"        \
         -v    HIDE_DEVICES="${HIDE_DEV}"        \
         -v         LISTSVC="${LISTSVC}"         \
         -v        SHOW_PDB="${SHOW_PDB}"        \
         -v         SHOW_DB="${SHOW_DB}"         \
         -v        SHOW_SVC="${SHOW_SVC}"        \
         -v       SHOW_LSNR="${SHOW_LSNR}"       \
         -v       SHOW_TECH="${SHOW_TECH}"       \
'BEGIN\
{ FS = "="                                   ;
   n = split(NODES, nodes, ",")              ;       # Make a table with the nodes of the cluster
  # some colors
  COLOR_BEGIN =       "\033[1;"              ;
    COLOR_END =       "\033[0m"              ;
          RED =       "31m"                  ;
        GREEN =       "32m"                  ;
       YELLOW =       "33m"                  ;
         BLUE =       "34m"                  ;
       PURPLE =       "35m"                  ;
         TEAL =       "36m"                  ;
        WHITE =       "37m"                  ;
    WITH_BACK =       "43m"                  ;       # Yellow background
   WITH_BACK2 =       "44m"                  ;       # Blue background
   WITH_BACK2 =       "41m"                  ;       # Red background
COLOR_PRIMARY =       WHITE                  ;
COLOR_STANDBY =       BLUE                   ;
  if (REVERSE == "YES"){
        WHITE =     "30m"                    ;       # Black
         TEAL =     "34m"                    ;       # Blue
  COLOR_BEGIN =     "\033[2;"                ;       # Bold
  }

   UNKNOWN = "-"                             ;       # Something to print when the status is unknown
  DISABLED = "x"                             ;       # Something disabled

  # Default columns size
         COL_NODE = 0                        ;
  COL_NODE_OFFSET = col_node_offset * 2      ;       # Defined on top the script, have a look for explanations on this
           COL_DB = 12                       ;
          COL_VER = 15                       ;
         COL_TYPE = 14                       ;
           COL_OH = 24                       ;       # to print the ORACLE_HOMEs
          COL_PDB = COL_TYPE-1               ;       # PDB right of the services
        COL_OWNER = 6                        ;       # to print owner:group
        COL_GROUP = 3                        ;       # to print owner:group
      COL_DEFAULT = BLUE                     ;       # for the "-"
 RECENT_RESTARTED = 0                        ;       # To show a legend if we found a recent restarted
     STATUS_ISSUE = 0                        ;       # To show a legend if we found an issue with the status
 SERVICE_DISABLED = 0                        ;       # To show a legend of a service is disabled
          COL_SEP = "|"                      ;       # Column separator

  nbsvcshow = split(LISTSVC, temp, ",")      ;       # Array of services to show, if none, we show everything
  for (i=0;i<=nbsvcshow; i++){ svcshow[temp[i]]=temp[i]; }  # An associative array for easy search with for in
}  # End BEGIN
#
# A function to center the outputs with colors
#
function center(str, n, color, sep) {
    right = int((n - length(str)) / 2)                                                              ;
    left  = n - length(str) - right                                                                 ;
    return sprintf(COLOR_BEGIN color "%" left "s%s%" right "s" COLOR_END sep, "", str, "" )         ;
}
#
# Colorize a string
#
function in_color(str, color) {
    return sprintf(COLOR_BEGIN color "%s" COLOR_END, str)                                           ;
}
#
# Get a date in format MM/DD/YYYY HH24:MI:SS and return the rounded number hours difference between this date and the current date
#
function diff_hours(a_date) {
    if ((a_date == "NEVER ") || (a_date == " ")) {
        return 999999999999                                                                         ; 
    } else {
        split(a_date, temp, /[\/ :]/)                                                               ;
        return sprintf("%d", (systime()-mktime(temp[3]" "temp[1]" "temp[2]" "temp[4]" "temp[5]" "temp[6]))/(60*60)) ;
        delete temp                                                                                 ;
    }
}
#
# Get a string and return it with a nice case: first character in upper case ad the others in lower case (ABCD => Abcd)
#
function nice_case(str) {
    return sprintf("%s", toupper(substr(str,1,1)) tolower(substr(str,2,length(str))))               ;
}
#
# Print a legend for the recent restarted instances, listeners and services
#
function print_legend_recent_restarted() {
    if (RECENT_RESTARTED == 1) {
        printf("%s", " ")                                                                           ;
        printf(COLOR_BEGIN WITH_BACK "%-3s" COLOR_END, " ")                                         ;
        if (DIFF_HOURS_UNIT == "h")     { UNIT="hour"           }
        if (DIFF_HOURS_UNIT == "d")     { UNIT="day"            }
        if (DIFF_HOURS_UNIT == "w")     { UNIT="week"           }
        if (DIFF_HOURS_UNIT == "m")     { UNIT="month"          }
        if (DIFF_HOURS_UNIT == "y")     { UNIT="year"           }
        if (HOURS > 1)                  { UNIT=UNIT"s"          }
        printf(COLOR_BEGIN WHITE " %-s\n " COLOR_END, ": Has been restarted less than "HOURS" "UNIT" ago");
    }
}
#
# Print a legend if we found an issue in the status (STATUS != TARGET)
#
function print_legend_status_issue() {
    if (STATUS_ISSUE == 1) {
        printf(COLOR_BEGIN WITH_BACK2 "%-3s" COLOR_END, " ")                                        ;
        printf(COLOR_BEGIN WHITE " %-s\n " COLOR_END, ": STATUS and TARGET are different")          ;
    }
}
#
# Print a legend when something is disabled
#
function print_legend_disabled(a_variable, a_text) {
    if (a_variable == 1) {
        printf("%s", " ")                                                                           ;
        printf("%s", center(DISABLED, 3, RED))                                                      ;
        printf("%-s\n", in_color(" : "a_text" is disabled", WHITE))                                 ;
    }
}
#
# A function that just print a "---" white line
#
function print_a_line(size) {
    if ( ! size) {
        size = COL_DB+COL_VER+(COL_NODE*n)+COL_TYPE+n+3                                             ;
    }
    printf("%s", COLOR_BEGIN WHITE)                                                                 ;
    for (k=1; k<=size; k++) {printf("%s", "-");}                                                    ; # n = number of nodes
    printf("%s", COLOR_END"\n")                                                                     ;
}
#
# Set colors depending on the recently restarted date and dbstatus and dbtarget
#
function set_color_status(i_db, i_node, i_status, i_target) {
	if ((started[i_db,i_node]+0 < DIFF_HOURS+0) && (started[i_db,i_node])) {
		    COL_OPEN=WITH_BACK                                                              ;
		COL_READONLY=WITH_BACK                                                              ;
		    COL_SHUT=WITH_BACK                                                              ;
		   COL_OTHER=WITH_BACK                                                              ;
	    RECENT_RESTARTED=1                                                                      ;
	} else  {
		    COL_OPEN=GREEN                                                                  ;
		COL_READONLY=WHITE                                                                  ;
		    COL_SHUT=YELLOW                                                                 ;
		   COL_OTHER=RED                                                                    ;
	}
	if (i_status != i_target) {
		    COL_OPEN=WITH_BACK2                                                             ;
		COL_READONLY=WITH_BACK2                                                             ;
		    COL_SHUT=WITH_BACK2                                                             ;
		   COL_OTHER=WITH_BACK2                                                             ;
		STATUS_ISSUE=1                                                                      ;
	}
}
{ # Fill 2 tables with the OH and the version from "crsctl stat res -p -w "TYPE = ora.database.type""
    if ($1 == "NAME") {
        sub("^ora.", "", $2)                                                                        ;
        sub(/\(.*$/, "", $2)                                                                        ; # Remove the consumer group
        type            = "TECH"                                                                    ;
    if ($2 ~ /\.db$/) {                                                                               # Databases
        type            = "DB"                                                                      ;
        sub(".db$",  "", $2)                                                                        ;
    }
    if ($2 ~ /\.pdb$/) {                                                                              # PDBs
        type            = "PDB"                                                                     ;
        sub(".pdb$",  "", $2)                                                                       ;
        DBPDB           = $2                                                                        ;
    }
    if ($2 ~ /\.lsnr/) {                                                                              # Listeners
        sub(".lsnr$", "", $2)                                                                       ;
        tab_lsnr[$2]    = $2                                                                        ;
        type            = "LISTENER"                                                                ;
    }

    if ($2 ~ /\.svc/) {                                                                               # Services
        sub(".svc$", "", $2)                                                                        ;
       dbandservice=$2
            service=$2                                                                              ;
             svc_db=$2

        sub(/^[^.]*\./, "", service)                                                                ; # Remove the DB name
        sub(/\..*$/, "", svc_db)                                                                    ; # DB name only

        if (oh[svc_db]){                   # We ignore the services not related to an already found DB (see -D option)
            if (nbsvcshow > 0){
                if (service in svcshow){   # If we want specific services (see -S option)
                    tab_svc[dbandservice]=dbandservice                                              ;
                } 
            } else {
                tab_svc[dbandservice]=dbandservice                                                  ;
            }
            if (length(service) > COL_VER-1) {                                                        # To adapt the column size
                COL_VER = length(service) +1                                                        ;
            }
        } else {
            next                                                                                    ;
        }
        type            = "SERVICE"                                                                 ;
    }

    DB=$2                                                                                           ;
    split($2, temp, ".")                                                                            ;
    if (length(temp[1]) > COL_DB-1) {                                                                 # To adapt the 1st column size
        COL_DB = length(temp[1]) +1                                                                 ;
    }
    if (type == "TECH") {
        if ($2 ~ /\./) {
            sub(/\.[[:alnum:]]*$/, "", $2)                                                          ;
            # We put the type before the name to sort it by type easily later
               type_name = temp[length(temp)]"."$2                                                  ;
            tab_tech[$2] = type_name                                                                ;
            if (length($2) > COL_VER-1) {
                 COL_VER = length($2) + 1                                                           ;
            }
        } else {
            tab_tech[temp[1]] = temp[1]                                                             ;
        }
    }
    delete temp                                                                                     ;

    getline; getline                                                                                ;
    if ($1 == "ACL") {                        # crsctl stat res -p output
        if (type == "DB") {
            # Get the owner and the group
            match($2, /owner:([[:alnum:]]*):.*/, OWNER)                                             ;
            match($2, /^.*pgrp:([[:alnum:]]*):.*/, GROUP)                                           ;
            while (getline)
            {
                if ($1 == "ORACLE_HOME") {
                    OH = $2                                                                         ;
                    match($2, /[1-9][0-9]\.[0-9]\.?[0-9]?\.?[0-9]?/)                                ; # Grab the version from the OH path
                    VERSION = substr($2,RSTART,RLENGTH)                                             ;
                }
                if ($1 == "DATABASE_TYPE") {                                                          # RAC / RACOneNode / Single Instance are expected here
                    dbtype[DB] = $2                                                                 ;
                }
                if ($1 == "ROLE") {                                                                   # Primary / Standby expected here
                    role[DB] = $2                                                                   ;
                }
                if ($1 == "ENABLED") {                                                                # Instance is enabled (1) or disabled (0)
                    enabled = $2                                                                    ; # Save it for later
                }
                if ($1 == "GEN_USR_ORA_INST_NAME") {
                    instance = $2                                                                   ;
                    while (getline) {
                        if (($1 ~ /^GEN_USR_ORA_INST_NAME@SERVERNAME/) && ($2 == instance)) {
                            sub("GEN_USR_ORA_INST_NAME@SERVERNAME[(]", "", $1)                      ;
                            sub(")", "", $1)                                                        ;
                            is_enabled[DB,$1] = enabled                                             ;
                            break                                                                   ;
                        }
                        if ($0 ~ /^$/) {
                            break                                                                   ;
                        }

                    }
                }
                if ($0 ~ /^$/) {
                    version[DB] = VERSION                                                           ;
                         oh[DB] = OH                                                                ;

                    if (!(OH in oh_list)) {
                        oh_ref++                                                                    ;
                        oh_list[OH] = oh_ref                                                        ;
                        o_list[OH] = OWNER[1]                                                       ;
                        g_list[OH] = GROUP[1]                                                       ;
                        if (length(OH)       > COL_OH)    {        COL_OH = length(OH)              ; }
                        if (length(OWNER[1]) > COL_OWNER) {     COL_OWNER = length(OWNER[1])        ; }
                        if (length(GROUP[1]) > COL_GROUP) {     COL_GROUP = length(GROUP[1])        ; }
                    }
                    break                                                                           ;
                }
            }
        }       # End if (type == "DB")
        if (type == "PDB") {
            while(getline) {
                if ($1 == "PDB_NAME") {
                    PDB = $2                                                                        ;
                    split(DBPDB, temppdb, ".")                                                      ; # Here, DB = dbname.pdbname
                    pdb[temppdb[1]][temppdb[2]] = PDB                                               ;
                    delete temppdb                                                                  ;
                }
                if ($1 == "ENABLED") {                                                                # Service is enabled (1) or disabled (0)
                    for (i=1; i<=n; i++) {                                                            # n = number of nodes
                        is_enabled[DB,nodes[i]]= $2                                                 ;
                    }
                    while(getline) {
                        if ($1 ~ /ENABLED@SERVERNAME/ ) {
                            sub("ENABLED@SERVERNAME[(]", "", $1)                                    ;
                            sub(")", "", $1)                                                        ;
                            is_enabled[DB,$1] = $2                                                  ;
                        } else  {
                            break                                                                   ;
                        }
                    }
                }
                if ($0 ~ /^$/) {
                    break                                                                           ;
                }
            }
        }       # End if (type == "PDB")

        if (type == "SERVICE") {
            while(getline) {
                if ($1 == "ENABLED") {                                                                 # Service is enabled (1) or disabled (0)
                    for (i=1; i<=n; i++) {                                                             # n = number of nodes
                        is_enabled[DB,nodes[i]]= $2                                                  ;
                    }
                    while(getline) {
                        if ($1 ~ /ENABLED@SERVERNAME/ ) {
                            sub("ENABLED@SERVERNAME[(]", "", $1)                                     ;
                            sub(")", "", $1)                                                         ;
                            is_enabled[DB,$1] = $2                                                   ;
                        } else {
                            break                                                                    ;
                        }
                    }
                }
                if ($1 == "ROLE") {                                                                    # Service type (primary / standby)
                    tab_svc_type[service]=$2                                                         ;
                }
                if ($1 == "PLUGGABLE_DATABASE") {
                    tab_pdb[service] = $2                                                            ;
                    if (length($2) > COL_PDB) { COL_PDB = length($2)                                 ; }
                }
                if ($0 ~ /^$/) {
                    break                                                                            ;
                }
            }
        }       # End if (type == "SERVICE")
        #if (DB in tab_lsnr == 1)

        if (type == "LISTENER") {
            while(getline) {
                if ($1 == "ENABLED") {                                                                 # Listener is enabled (1) or disabled (0)
                    for (i=1; i<=n; i++) {                                                             # n = number of nodes
                        is_enabled[DB,nodes[i]]= $2                                                  ;
                    }
                    while(getline) {
                        if ($1 ~ /ENABLED@SERVERNAME/ ) {
                            sub("ENABLED@SERVERNAME[(]", "", $1)                                     ;
                            sub(")", "", $1)                                                         ;
                            is_enabled[DB,$1] = $2                                                   ;
                        } else {
                            break                                                                    ;
                        }
                    }
                }
                if ($1 == "ENDPOINTS") {
                    port[DB] = $2                                                                    ;
                    break                                                                            ;
                }
            }
        }    # End if (type == LISTENER)

        if (type == "TECH") {
            while (getline) {
                 if ($1 == "ENABLED") {
                     for (i=1; i<=n; i++) {                                                            # n = number of nodes
                         is_enabled[DB,nodes[i]]= $2                                                 ;
                     }
                     while(getline) {
                         if ($1 ~ /ENABLED@SERVERNAME/ ) {
                             sub("ENABLED@SERVERNAME[(]", "", $1)                                    ;
                             sub(")", "", $1)                                                        ;
                             is_enabled[DB,$1] = $2                                                  ;
                         } else {
                             break                                                                   ;
                         }
                     }
                 }
                 if ($1 == "VOLUME_DEVICE"){
                     tempdb=tolower(DB)                                                              ;
                     sub(/^[[:alnum:]_]*\./, "", tempdb)                                             ;
                     sub(/\.[[:alnum:]_]*$/, "", tempdb)                                             ;
                     advm_device[tempdb] = tolower($2)                                               ;
                 }
                 if ($1 == "USR_ORA_VIP"){
                     vip[DB]=$2                                                                      ;
                 }
                 if ($0 ~ /^$/) {
                     break                                                                           ;
                 }
            }
        }    # End if (type == TECH)
    }       # End if ($1 == "ACL")

    if ($1 == "LAST_SERVER") {        # crsctl stat res -v output
        NB = 0      ;       # Number of instances we went through
        SERVER = $2     ;
        if (length(SERVER) > COL_NODE) {
            COL_NODE = length(SERVER) + COL_NODE_OFFSET                                              ;
        }
        while (getline) {
            if ($1 == "LAST_SERVER")        {       SERVER = $2                             ;}
            if ($1 == "STATE")              {       gsub(" on .*$", "", $2)                 ;
                status[DB,SERVER] = $2                  ;
                if (length(status[DB,SERVER]) > COL_NODE) { COL_NODE = length(status[DB,SERVER]) + COL_NODE_OFFSET;}
            }
            if ($1 == "TARGET")             {       target[DB,SERVER]=$2                    ;}
            if (($1 == "LAST_RESTART") || ($1 == "LAST_STATE_CHANGE")) {
                if (type == "PDB") { l_index = DBPDB} else { l_index = DB }
                if (started[l_index,SERVER] > diff_hours($2" "$3) || started[l_index,SERVER] == "") {started[l_index,SERVER]=diff_hours($2" "$3);}
            }
            if ($1 == "STATE_DETAILS")      {       NB++                                    ;  # Number of instances we came through
                if (DB ~ /acfs/)            {       sub ("mounted on ", "", $2)             ;      
                                                    tempdb=tolower(DB)                      ;
                                                    sub(/^[[:alnum:]_]*\./, "", tempdb)     ;
                                                    sub(/\.[[:alnum:]_]*$/, "", tempdb)     ;
                                                    acfs_mount[tempdb] = $2                 ;
                                                    if (length($2) > COL_ACFS) {COL_ACFS = length($2)}
                                            }
                sub("STATE_DETAILS=", "", $0)           ;
                sub(",HOME=.*$", "", $0)                ;       # Manage the 12cR2 new feature, check 20170606 for more details
                sub("),.*$", ")", $0)                   ;       # To make clear multi status like "Mounted (Closed),Readonly,Open Initiated"
                if ($0 == "Instance Shutdown")    {  status_details[DB,SERVER] = "Shutdown"       ;       } else
                if ($0 ~  "Readonly")             {  status_details[DB,SERVER] = "Readonly"       ;       } else
                if ($0 ~  "Abnormal Termination") {  status_details[DB,SERVER] = "Abnorm Term"    ;       } else
                if ($0 ~  /Mount/)                {  status_details[DB,SERVER] = "Mounted"        ;       } else
                if ($0 ~  /running from old/)     {  status_details[DB,SERVER] = "Open from old OH";      } else
                                                  {  if ($0 != "") {status_details[DB,SERVER] = $0};      }
                if ((length(status_details[DB,SERVER]) > COL_NODE) && (type != "TECH")) {
                    COL_NODE = length(status_details[DB,SERVER]) + COL_NODE_OFFSET  ;
                }
            } # End of $1 == "STATE_DETAILS"
            if ($1 == "BREAK_HERE") { break;}
        }
    }     # End of if ($1 == LAST_SERVER)
        }       # End of if ($1 ~ /^NAME/)
}         # End of main awk section
END {       #
    # Tech stuff
    #
    if ((length(tab_tech) > 0) && (SHOW_TECH == "YES")) {            # We print only if we have something to show
        # A header for the listeners
        printf("%s", center("Type" ,  COL_DB, WHITE, COL_SEP))                          ;
        printf("%s", center("Name"     , COL_VER+1, WHITE, COL_SEP))                    ;
        n=asort(nodes)                                                                  ; # sort array nodes
        for (i = 1; i <= n; i++) {
            printf("%s", center(nodes[i], COL_NODE, WHITE, COL_SEP))                    ;
        }
        printf("\n")                                                                    ;

        # a "---" line under the header
        print_a_line(COL_DB+COL_NODE*n+COL_VER+n+2)                                     ;
        # Print the tech stuff
        # Sort by type
        y = asort(tab_tech, tech_sorted)                                                ;
        for (i = 1; i<=y; i++) {
            the_type = tech_sorted[i]                                                   ;
            the_name = tech_sorted[i]                                                   ;
            sub(/\..*$/, "", the_type)                                                  ;
            sub(/^[[:alnum:]]*\./, "", the_name)
            printf(COLOR_BEGIN WHITE " %-"COL_DB-1"s" COLOR_END"|", the_type, WHITE)    ;
            if (the_type == "advm") {  # advm more readable in lowercase
                printf(COLOR_BEGIN WHITE " %-"COL_VER"s" COLOR_END"|", tolower(the_name), WHITE)     ;
            } else {
                printf(COLOR_BEGIN WHITE " %-"COL_VER"s" COLOR_END"|", the_name, WHITE) ;
            }
            if (the_name == the_type) {
                a = the_type                                                            ;
            } else {
                a = the_name"."the_type                                                 ;
            }
            for (j = 1; j <= n; j++) {                       # For each node
                l_node = nodes[j]                            # Make it more clear later ;
                if (is_enabled[a, l_node] == "") {
                    tech_enabled = 1                                                    ;
                } else {
                    tech_enabled = is_enabled[a, l_node]                                ;
                }
                tech_status = status[a, l_node]                                         ;
                tech_target = target[a, l_node]                                         ;
                if (tech_status == "") {
                    tech_status = status[a, ""]                                         ;
                }
                set_color_status(a, l_node, tech_status, tech_target)                   ;
                if (tech_enabled == 1) {                                                  # Resource is enabled
                    if (tech_status == "") {
                        printf("%s", center(UNKNOWN, COL_NODE, COL_DEFAULT, COL_SEP ))  ;
                    } else {
                        if (toupper(tech_status) == "ONLINE") {
                            printf("%s", center(nice_case(tech_status), COL_NODE, COL_OPEN, COL_SEP))  ;
                        } else {
                            printf("%s", center(nice_case(tech_status), COL_NODE, COL_OTHER, COL_SEP)) ;
                        }
                   }
                } else {                                                                  # Resource is disabled
                    TECH_DISABLED = 1                                                   ;
                    right = int((COL_NODE - length(tech_status)) / 2)                   ;
                    left  = COL_NODE - length(tech_status) - right                      ;
                    if (length(tech_status) < COL_DB+4) {
                        left--                                                          ;
                    }
                    if (tech_status == "") {
                        printf("%s", center(DISABLED, COL_NODE, RED, COL_SEP ))         ;
                    } else {
                        if (toupper(tech_status) == "ONLINE") {
                            printf("%"left"s%s %s%"right"s", "", in_color(nice_case(tech_status), COL_OPEN), in_color(DISABLED, RED),COL_SEP);
                        } else {
                            printf("%"left"s%s %s%"right"s", "", in_color(nice_case(tech_status), COL_OTHER ), in_color(DISABLED, RED),COL_SEP);
                        }
                   }
               }
           }    # End for each node
           # ACFS / ADVM devices
           if (HIDE_DEVICES == "False") {
               name_only=tolower(the_name)                                              ;
               sub(/^[[:alnum:]_]*\./, "", name_only)                                   ;

               if (the_type == "acfs") {
                   printf("  %-"COL_ACFS"s", acfs_mount[name_only])                     ;
                   if (ADVM_DEVICES == "True") {
                       printf(" - %s", advm_device[name_only])                          ;
                   }
               }
               if (the_type == "advm") {
                   if (advm_device[name_only]) {
                       printf("  %s ", advm_device[name_only])                          ;
                   }
               }
           } # End of ACFS / ADVM devices
           # Show the VIP IPs
           if (vip[the_name"."the_type]){
               printf("  %s ", vip[the_name"."the_type])                                ;
           }
           printf("\n")                                                                 ;
        }
        # a "---" line under the header
        print_a_line(COL_DB+COL_NODE*n+COL_VER+n+2)                                     ;
        print_legend_disabled(TECH_DISABLED, "Resource")                                ;
        print_legend_recent_restarted()                                                 ;
        print_legend_status_issue()                                                     ;
          STATUS_ISSUE=0                                                                ;
        RECENT_RESTARTED=0                                                              ;
        printf("\n")                                                                    ;
    }
    #
    # Listeners
    #
    if ((length(tab_lsnr) > 0) && (SHOW_LSNR == "YES")) {             # We print only if we have something to show
        # A header for the listeners
        printf("%s", center("Listener" ,  COL_DB, WHITE, COL_SEP))                      ;
        printf("%s", center("Port"     , COL_VER+1, WHITE, COL_SEP))                    ;
        n=asort(nodes)                                                                  ; # sort array nodes
        for (i = 1; i <= n; i++) {
            printf("%s", center(nodes[i], COL_NODE, WHITE, COL_SEP))                    ;
        }
        printf("%s", center("Type"    , COL_TYPE, WHITE, COL_SEP))                      ;
        printf("\n")                                                                    ;

        # a "---" line under the header
        print_a_line()                                                                  ;

        # print the listeners
        x=asorti(tab_lsnr, lsnr_sorted)                                                 ;
        for (j = 1; j <= x; j++) {                                                        # For each listener
            l_lsnr = lsnr_sorted[j]                                                     ; 
            printf(COLOR_BEGIN WHITE " %-"COL_DB-1"s" COLOR_END"|", l_lsnr, WHITE)      ; # Listener name
            # It may happen that listeners listen on many ports then it wont fit this column
            # We then print it outside of the table after the last column
            if (length(port[l_lsnr]) > COL_VER) {
                printf(COLOR_BEGIN WHITE " %-"COL_VER"s" COLOR_END"|", "See -->", WHITE); # "See -->"
                print_port_later = 1                                                    ;
            } else {
                printf(COLOR_BEGIN WHITE " %-"COL_VER"s" COLOR_END"|", port[l_lsnr], WHITE);      # Port
            }
            for (i = 1; i <= n; i++) {                                                     # For each node
                l_node   = nodes[i]                                                     ;
                dbstatus =         status[l_lsnr,l_node]                                ;
                dbtarget =         target[l_lsnr,l_node]                                ;
                dbdetail = status_details[l_lsnr,l_node]                                ;
                set_color_status(l_lsnr, l_node, dbstatus, dbtarget)
                if (is_enabled[l_lsnr,l_node] == 0) {                            # Listener disabled
                    LISTENER_DISABLED = 1                                               ;
                                right = int((COL_NODE - length(dbstatus)) / 2)          ;
                                left  = COL_NODE - length(dbstatus) - right             ;
                    if (length(dbstatus) < COL_DB+4) {
                        left--                                                          ;
                    }
                    if (dbstatus == "")             {printf("%s", center(DISABLED,           COL_NODE, RED, COL_SEP ))      ;}    else
                    if (dbstatus == "ONLINE")       {printf("%"left"s%s %s%"right"s", "", in_color(nice_case(dbstatus), COL_OPEN)  , in_color(DISABLED, RED), COL_SEP);}
                    else                            {printf("%"left"s%s %s%"right"s", "", in_color(nice_case(dbstatus), COL_OTHER ), in_color(DISABLED, RED), COL_SEP);}
                } else {
                    if (dbstatus == "")             {printf("%s", center(UNKNOWN,             COL_NODE, COL_DEFAULT, COL_SEP   ))      ;}      else
                    if (dbstatus == "ONLINE")       {printf("%s", center(nice_case(dbstatus), COL_NODE, COL_OPEN   , COL_SEP   ))      ;}
                    else                            {printf("%s", center(nice_case(dbstatus), COL_NODE, COL_OTHER  ,  COL_SEP  ))      ;}
                }
            }
            # Type column
            if (toupper(l_lsnr) ~ /SCAN/) {
                LSNR_TYPE = "SCAN"                                                      ;
            } else {
                LSNR_TYPE = "Listener"                                                  ;
            }
            printf("%s", center(LSNR_TYPE, COL_TYPE, WHITE, COL_SEP))                   ;
            if (print_port_later) {
                print_port_later = 0                                                    ;
                printf(COLOR_BEGIN WHITE " %-"COL_VER-1"s" COLOR_END, port[l_lsnr], WHITE); # Port
            }
            printf("\n")                                                                ;
        }
        # a "---" line under the header
        print_a_line()                                                                  ;
        print_legend_disabled(LISTENER_DISABLED, "Listener")                            ;
        print_legend_recent_restarted()                                                 ;
        print_legend_status_issue()                                                     ;
           STATUS_ISSUE=0                                                               ;
       RECENT_RESTARTED=0                                                               ;
       printf("\n")                                                                     ;
    } # End of listeners
    #
    # Services
    #
    if ((length(tab_svc) > 0) && (SHOW_SVC == "YES")) {               # We print only if we have something to show
        # A header for the services
        printf("%s", center("DB"      ,  COL_DB   , WHITE, COL_SEP))                    ;
        printf("%s", center("Service" ,  COL_VER+1, WHITE, COL_SEP))                    ;
        n=asort(nodes)                                                                  ; # sort array nodes

        for (i = 1; i <= n; i++) {
            printf("%s", center(nodes[i], COL_NODE, WHITE, COL_SEP))                    ;
        }
        printf("%s", center("PDB"     ,  COL_PDB+1, WHITE, COL_SEP))                    ;
        printf("\n")

        # a "---" line under the header
        size_line_svc=COL_DB+COL_NODE*n+COL_VER+n+4+COL_PDB                             ;
        print_a_line(size_line_svc)                                                     ;

        # Print the Services
        x=asorti(tab_svc, svc_sorted)                                                   ;
        for (j = 1; j <= x; j++) {
            split(svc_sorted[j], to_print, ".")                                         ; # The service we have is <db_name>.<service_name>
            service = svc_sorted[j]                                                     ;
            sub(/^[^.]*\./, "", service)                                                ; # Remove the DB name only

            if (previous_db != to_print[1]) {                                             # Do not duplicate the DB names on the output
                if (role[to_print[1]] == "PRIMARY") { COLOR_SVC = COLOR_PRIMARY} else {COLOR_SVC = COLOR_STANDBY}

                printf(COLOR_BEGIN COLOR_SVC " %-"COL_DB-1"s" COLOR_END COL_SEP, to_print[1]); # Database
                previous_db = to_print[1]                                               ;
            } else {
                printf("%s", center("",  COL_DB, WHITE, COL_SEP))                       ;
            }
            if (tab_svc_type[service] == "PRIMARY") { COLOR_SVC = COLOR_PRIMARY} else {COLOR_SVC = COLOR_STANDBY}
            printf(COLOR_BEGIN COLOR_SVC " %-"COL_VER"s" COLOR_END"|", service, WHITE)  ; # Service

            for (i = 1; i <= n; i++) {                                                    # For each node
                dbstatus =           status[svc_sorted[j],nodes[i]]                     ;
                dbtarget =           target[svc_sorted[j],nodes[i]]                     ;
                dbdetail =   status_details[svc_sorted[j],nodes[i]]                     ;
                if ((started[svc_sorted[j],nodes[i]] < DIFF_HOURS) && (started[svc_sorted[j],nodes[i]])) {
                          COL_ONLINE=WITH_BACK                                          ;
                           COL_OTHER=WITH_BACK                                          ;
                    RECENT_RESTARTED=1                                                  ;
                } else {
                    if (role[to_print[1]] != tab_svc_type[service] && role[to_print[1]] != "") {
                        COL_OTHER=GREEN                                                 ;
                       COL_ONLINE=RED                                                   ;
                    } else {
                        COL_OTHER=RED                                                   ;
                       COL_ONLINE=GREEN                                                 ;
                    }
                }
                if (dbstatus != dbtarget) {
                      COL_ONLINE=WITH_BACK2                                             ;
                       COL_OTHER=WITH_BACK2                                             ;
                    STATUS_ISSUE=1                                                      ;
                }
                if (is_enabled[svc_sorted[j],nodes[i]] == 0) {                            # Service disabled
                    SERVICE_DISABLED = 1                                                ;
                    right = int((COL_NODE - length(dbstatus)) / 2)                      ;
                    left  = COL_NODE - length(dbstatus) - right                         ;
                    if (length(dbstatus) < COL_DB+4) {
                        left--                                                          ;
                    }
                    if (dbstatus == "")             {printf("%s", center(DISABLED, COL_NODE, RED, COL_SEP ))      ;} else
                    if (dbstatus == "ONLINE")       {printf("%"left"s%s %s%"right"s", "", in_color(nice_case(dbstatus), COL_ONLINE), in_color(DISABLED, RED), COL_SEP);}
                    else                            {printf("%"left"s%s %s%"right"s", "", in_color(nice_case(dbstatus), COL_OTHER ), in_color(DISABLED, RED), COL_SEP);}
                } else {
                    if (dbstatus == "")             {printf("%s", center(UNKNOWN,             COL_NODE, COL_DEFAULT, COL_SEP   ))      ;} else
                    if (dbstatus == "ONLINE")       {printf("%s", center(nice_case(dbstatus), COL_NODE, COL_ONLINE,  COL_SEP   ))      ;}
                    else                            {printf("%s", center(nice_case(dbstatus), COL_NODE, COL_OTHER,   COL_SEP   ))      ;}
                }
            }                                                                             # End of each node
            # PDB associated to a service
            if (tab_pdb[service]) {
                printf(" %-"COL_PDB"s"COL_SEP, tab_pdb[service])                        ;
            } else {
                printf("%s", center(UNKNOWN, COL_PDB+1, COL_DEFAULT, COL_SEP))          ;
            }
            printf("\n")                                                                ;
        }
        # a "---" line under the header
        print_a_line(size_line_svc)                                                     ;
        print_legend_disabled(SERVICE_DISABLED, "Service")                              ;
        print_legend_recent_restarted()                                                 ;
        print_legend_status_issue()                                                     ;
            STATUS_ISSUE=0                                                              ;
        RECENT_RESTARTED=0                                                              ;
        printf("\n")                                                                    ;
    }   # End services
    #
    # Databases
    #
    if ((length(version) > 0) && (SHOW_DB == "YES")) {   # We print only if we have something to show
        # sort the OH array by OH names
        k=asorti(oh_list, oh_list_sorted)
        for (j=1; j<=k; j++){
            oh_list[oh_list_sorted[j]]=j ;
        }
        # A header for the databases
        printf("%s", center("DB"        , COL_DB, WHITE, COL_SEP))                      ;
        printf("%s", center("Version"   , COL_VER+1, WHITE, COL_SEP))                   ;
        n=asort(nodes)                                                                  ; # sort array nodes
        for (i = 1; i <= n; i++) {
            printf("%s", center(nodes[i], COL_NODE, WHITE, COL_SEP))                    ;
        }
        printf("%s", center("DB Type"   , COL_TYPE, WHITE, COL_SEP))                    ;
        printf("\n")                                                                    ;

        # a "---" line under the header
        print_a_line()                                                                  ;

        # Print the databases
        m=asorti(version, version_sorted)                                               ;
        for (j = 1; j <= m; j++) {
            l_db = version_sorted[j]                                                    ; # more readable
            if (role[l_db] == "PRIMARY") { COLOR_DB = COLOR_PRIMARY} else {COLOR_DB = COLOR_STANDBY}
            printf(COLOR_BEGIN COLOR_DB "%-"COL_DB"s" COLOR_END"|", l_db)               ; # Database
            printf(COLOR_BEGIN WHITE " %-"COL_VER-6"s" COLOR_END, version[l_db], COL_VER);# Version
            printf(COLOR_BEGIN WHITE "%6s" COLOR_END"|"," ("oh_list[oh[l_db]] ") ")     ; # OH id

            for (i = 1; i <= n; i++) {                                                    # For each node
                l_node   = nodes[i]                                                     ; # More readable
                dbstatus =           status[l_db,l_node]                                ;
                dbtarget =           target[l_db,l_node]                                ;
                dbdetail =   status_details[l_db,l_node]                                ;
                set_color_status(l_db, l_node, dbstatus, dbtarget)                      ;
                if ((is_enabled[l_db,l_node] == 0) && (is_enabled[l_db,l_node] != "")) { # Instance disabled
                    INSTANCE_DISABLED = 1                                               ;
                    right = int((COL_NODE - length(dbdetail)) / 2)                      ;
                    left  = COL_NODE - length(dbdetail) - right                         ;
                    if (length(dbdetail) < COL_DB+4) {
                        left--                                                          ;
                    }
                    if (dbdetail == "") {
                        printf("%s", center(DISABLED, COL_NODE, RED, COL_SEP ))         ;
                    } else if (dbdetail == "Open") {
                        printf("%"left"s%s %s%"right"s", "", in_color(nice_case(dbdetail), COL_ONLINE),   in_color(DISABLED, RED), COL_SEP);
                    } else if (dbdetail ~  /Readonly/) {
                        printf("%"left"s%s %s%"right"s", "", in_color(nice_case(dbdetail), COL_READONLY), in_color(DISABLED, RED), COL_SEP);
                    } else if (dbdetail ~  /Shut/) {
                        printf("%"left"s%s %s%"right"s", "", in_color(nice_case(dbdetail), COL_SHUT),     in_color(DISABLED, RED), COL_SEP);
                    } else {
                        printf("%"left"s%s %s%"right"s", "", in_color(nice_case(dbdetail), COL_OTHER),    in_color(DISABLED, RED), COL_SEP);
                    }
                } else {
                    if (dbdetail == "")             {printf("%s", center(UNKNOWN,             COL_NODE, COL_DEFAULT, COL_SEP ))  ;}      else
                    if (dbdetail == "Open")         {printf("%s", center(nice_case(dbdetail), COL_NODE, COL_OPEN,    COL_SEP ))  ;}      else
                    if (dbdetail ~  /Readonly/)     {printf("%s", center(nice_case(dbdetail), COL_NODE, COL_READONLY,COL_SEP ))  ;}      else
                    if (dbdetail ~  /Shut/)         {printf("%s", center(nice_case(dbdetail), COL_NODE, COL_SHUT,    COL_SEP ))  ;}      else
                                                    {printf("%s", center(nice_case(dbdetail), COL_NODE, COL_OTHER,   COL_SEP ))  ;}
                }
            } # End for each node
            #
            # Color the DB Type column depending on the ROLE of the database (20170619)
            #
            if (role[l_db] == "PRIMARY") {
                ROLE_COLOR=COLOR_PRIMARY
                ROLE_SHORT=" (P)"                                                       ;
            } else {
                ROLE_COLOR=COLOR_STANDBY
                ROLE_SHORT=" (S)"                                                       ;
            }
            printf("%s", center(dbtype[l_db] ROLE_SHORT, COL_TYPE, ROLE_COLOR, COL_SEP));
            printf("\n")                                                                ;
            #
            # PDBs
            #
            if (length(pdb[l_db]) > 0 && SHOW_PDB == "YES") {                             # Only if there are PDBs
                for (x in pdb[l_db]) {tempopdb[x]=x;}                                   ;
                z=asort(tempopdb,pdb_sorted)                                            ;
                for (p=1; p<=z; p++) {                                                    # For each PDB
                    l_pdb = pdb_sorted[p]                                               ;
                    l_dbpdb = l_db"."l_pdb                                              ;
                    printf(COLOR_BEGIN COLOR_DB "  %-"COL_DB-2"s" COLOR_END"|", l_pdb ) ; # PDB
                    printf(COLOR_BEGIN WHITE " %-"COL_VER"s" COLOR_END"|", "", COL_VER) ; # Version
                    for (i = 1; i <= n; i++) {                                            # For each node
                        l_node    = nodes[i]                                            ;  # More readable
                        pdbstatus =           status[l_dbpdb,l_node]                    ;
                        pdbtarget =           target[l_dbpdb,l_node]                    ;
#                        pdbdetail =   status_details[l_dbdbp,l_node]                   ;
                        set_color_status(l_dbpdb, l_node, pdbstatus, pdbtarget)         ;
                        if ((is_enabled[l_dbpdb,l_node] == 0) && (is_enabled[l_dbpdb,l_node] != "")) { # Instance disabled
                            INSTANCE_DISABLED = 1                                       ;
                            right = int((COL_NODE - length(pdbstatus)) / 2)             ;
                            left  = COL_NODE - length(pdbstatus) - right                ;
                            if (length(pdbstatus) < COL_DB+4) {
                                left--                                                  ;
                            }
                            if (tolower(pdbstatus) == "online"){
                                printf("%"left"s%s %s%"right"s", "", in_color(nice_case(pdbstatus), COL_OPEN), in_color(DISABLED, RED), COL_SEP); } else {
                                printf("%"left"s%s %s%"right"s", "", in_color(nice_case(pdbstatus), COL_OTHER), in_color(DISABLED, RED), COL_SEP); }
                        } else {
                            if (tolower(pdbstatus) == "online"){
                                printf("%s", center(nice_case(pdbstatus), COL_NODE, COL_OPEN, COL_SEP)) ; } else {
                                printf("%s", center(nice_case(pdbstatus), COL_NODE, COL_OTHER, COL_SEP)) ; }
                        }
                    }
                    printf("%s", center("PDB", COL_TYPE, ROLE_COLOR, COL_SEP))          ;
                    printf("\n")                                                        ;
                } # End for each PDB
                delete tempopdb ;
             } # End of PDBs
        }

        # a "---" line as a footer
        print_a_line()                                                                  ;

        # Print the OH list and a legend for the DB Type colors underneath the table
        printf ("%s", "ORACLE_HOME references listed in the Version column ")           ;

        if (oh_ref > 1) {
            printf ("(%s)", "\"" sprintf(COLOR_BEGIN TEAL "%s" COLOR_END, "\47\47") "\" means \"same as above\"") ;
        }
        printf ("\n\n")                                                                 ;

        previous_group = ""                                                             ;
        previous_owner = ""                                                             ;
        if (COL_OWNER%2) { COL_OWNER++  }
        if (COL_GROUP%2) { COL_GROUP++  }                                               ;
        g_same_as_above=sprintf(COLOR_BEGIN TEAL "%"(COL_GROUP/2)-1"s%s" COLOR_END, "", "\47\47")                        ;
        o_same_as_above=sprintf(COLOR_BEGIN TEAL "%"(COL_OWNER/2)-1"s%s%"(COL_OWNER/2)-1"s" COLOR_END, "", "\47\47", "") ;

        # to ease the ORACLE_HOME sorting
        for (x in oh_list) {
            to_print[oh_list[x]] = x                                                    ;
        }
        for (i=1; i<=oh_ref; i++) {
            # to ease the naming
            the_oh=to_print[i]                                                          ;
             owner=o_list[to_print[i]]                                                  ;
             group=g_list[to_print[i]]                                                  ;
            if (group == previous_group) {
                group_to_print = g_same_as_above                                        ;
            } else {
                group_to_print = group                                                  ;
            }
            if (owner == previous_owner) {
                owner_to_print = o_same_as_above                                        ;
            } else {
                owner_to_print = owner                                                  ;
            }

            printf("\t%2d : %-"COL_OH"s\t%-"COL_OWNER"s %s\n", i, the_oh, owner_to_print, group_to_print) ;
            previous_group = group                                                      ;
            previous_owner = owner                                                      ;
        }
    }
    printf ("\n")                                                                       ;
    print_legend_disabled(INSTANCE_DISABLED, "Instance")                                ;
    print_legend_recent_restarted()                                                     ;
    print_legend_status_issue()                                                         ;
} ' "${TMP}" | "${AWK}" -v GREP="${GREP}" -v UNGREP="${UNGREP}" ' BEGIN {FS="|"}          # AWK used to grep and ungrep
           {    if ((NF >= 3) && ($(NF-1) !~ /Type/) && ($2 !~ /Service/)) {
                    if (($0 ~ GREP) && ($0 !~ UNGREP)) {
                        print $0                                                        ;
                    }
                } else {
                   print  $0                                                            ;
                }
           }' | sed s'/^/  /' > "${TMP2}"                                                  # We can reuse TMP2 here
#
# Special sort order (option -c)
#
if [[ -n "${SORT_BY}" ]]; then                                                             # Special sort order
      SORT_COL="${SORT_BY:0:1}"                                                            # First character
     SORT_NODE="${SORT_BY:1:1}"                                                            # Second character
    SORT_ORDER="${SORT_BY: -1}"                                                            # Last character
    if [[ "${SORT_COL}" =~ [1-9] ]]; then
        SORT_NODE=${SORT_COL}
         SORT_COL="c"
    fi
    if [[ "${SORT_ORDER}" != "r" ]]; then                     i                            # Sort order can only be "r" for reverse or "" for normal
         SORT_ORDER=""
    else SORT_ORDER="r"
    fi
    if [[ ! "${SORT_NODE}" =~ [1-9] ]]; then                                               # Column or node number
          SORT_NODE=1
    fi
    # Assign the column  number depending of what we want to sort by
     SORT_NUM=1
    SORT_NUM2=2                                                                            # Second column to sort by
    SORT_NUM3=2                                                                            # Third column to sort by
    case ${SORT_COL} in
    c)   if [[ "${SORT_NODE}" -gt "2" ]]; then
             SORT_NUM=$(((${SORT_NODE}*2)+2))
            SORT_NUM2=$((${SORT_NUM}-1))
         else    SORT_NUM=$(( ${SORT_NODE}*2   ))
         fi                                                                             ;; # Sort by column number
    d)   SORT_NUM=2                                                                     ;; # Sort by DB name
    v)   SORT_NUM=4                                                                     ;; # Sort by version
    s)    SORT_NUM=$(((${SORT_NODE}*2)+6))                                               ; # Sort by status (Shutdown, Open)
         SORT_NUM2=$((${SORT_NUM}-1))                                                   ;;
    t)    TYPE_COL=`cat ${TMP2} | awk 'BEGIN {FS="|"}{if ($2 ~ "Version"){print (NF-1); exit}}'`  ;
          SORT_NUM=$(((${TYPE_COL}*2)+1))                                               ;; # Sort by Type
    esac

    SORT_K_1=" -k"${SORT_NUM}${SORT_ORDER}" "
    SORT_K_2=" -k"${SORT_NUM2}" "
    SORT_K_3=" -k"${SORT_NUM3}" "

    cat "${TMP2}" | awk 'BEGIN {FS="|"} {print $0; if ($2 ~ "Version"){getline; print $0; exit;}}' > ${TMP}
    cat "${TMP2}" | awk 'BEGIN {FS="|"}{if ($2 ~ "Version"){getline; while(getline){if ($0 ~ /---------------/){break}; print $0; }}}' | sort -i ${SORT_K_1} ${SORT_K_2} ${SORT_K_3} >> ${TMP}
    tac "${TMP2}" | awk '{print $0; if ($0 ~ /---------------/){exit;}}' | tac >> ${TMP}

    cp "${TMP}" "${TMP2}"
fi
if [[ "$WITH_COLORS" == "YES" ]]; then
    cat "${TMP2}"
else
    cat "${TMP2}" | sed -r "s/\x1B\[([0-9]{1,2}(;[0-9]{1,2})?)?[m|K]//g"                   # Remove the colors
fi
printf "\n"
if [[ -f "${TMP}" ]]; then
    if [[ -n "$OUT" ]]; then
        cp "${TMP}" "${OUT}"
        printf "\n\t\033[1;34m%s\033[m\n\n" "Output file ${OUT} has been generated"
    fi
    rm -f "${TMP}"
fi
rm -f "${TMP2}"
#*********************************************************************************************************
#                               E N D     O F      S O U R C E
#*********************************************************************************************************
