#!/bin/bash
# Fred Denis -- fred.denis3@gmail.com -- June 22nd 2018
#
# Please have a look at https://unknowndba.blogspot.com/2018/07/lspatchessh-oracle-patch-reporting-tool.html for detailed explanations
#
# Provide information on the installed and missing patches on ORACLE_HOMEs
#       $0 -h for more information
#
# The version of the script is 20180704
#
# 20180704 - Fred Denis - GREP and UNGREP now works when a file is specified
#                                                 A new -o option to only get the opatch output on a file
#                                                 The -s option is now compatible with the -f one
#
# 20180626 - Fred Denis - Started the opatch version management by showing a warning when the special 12.2.0.1.13 and 11.2.0.3.18 versions are used
#                            see https://unknowndba.blogspot.com/2018/06/deprecation-of-opatch-command-option.html for more information
#                         Shows an error when opatch raises an error (when another user owns the ORACLE_HOME for example)
#
# 20180625 - Fred Denis - Different OS support : (the script is developed under Linux)
#                       --- Solaris :
#                         -  grep "^[Aa-Zz|+]" does not work on Solaris so I moved to grep -v "^#" | grep -v "^$" when reading oratab
#                         -  default Solaris awk is the original awk and nawk lacks features from gawk (the script definitely does not work with nawk due to array management features)
#                            gawk is installed by default with Solaris 11 and is available for Solaris < 11, the script then expects gawk to be here for Solaris and if not it cannot continue
#                       --- HP-UX and AIX :
#                         - The "case" to support other OS is also HP-UX and AIX ready but I have not tested it as I have no such OS handy
#
# 20180622 - Fred Denis - Initial release
#

#
# Default values
#

 ALL_NODES=" -all_nodes "                                # We do lsinventory -all_nodes
      GREP="."                                           # What we grep                  -- default is everything
    UNGREP="nothing_to_ungrep_unless_v_option_is_used$$" # What we don't grep (grep -v)  -- default is nothing
      FILE=""                                            # No input file
       OUT=""                                                                                    # No output file
       TMP=/tmp/fictemplspatches$$                       # A tempfile
      TMP2=/tmp/fictemplspatches2$$                      # Another tempfile
SHOW_HOMES="NO"                                          # YES or NO we want to show the Homes from /etc/oratab or the input file $FILE ONLY

#
# An usage function
#
usage()
{
printf "\n\033[1;37m%-8s\033[m\n" "NAME"                        ;
cat << END
        $0 -- Provide information on the installed and missing patches on ORACLE_HOMEs
END

printf "\n\033[1;37m%-8s\033[m\n" "SYNOPSIS"                    ;
cat << END
        $0 [-f] [-o] [-g] [-l] [-v] [-s] [-h]
END

printf "\n\033[1;37m%-8s\033[m\n" "DESCRIPTION"                 ;
cat << END
        $0 relies on the content of the /etc/oratab file to look at the installed patch on the ORACLE_HOMEs
        It uses the opatch installed on each Home to list the installed patches and find the missing ones in case of RAC system
        A file containing some opatch outputs can also be provided to $0; it will then not use opatch but rely on the input file
            oraenv has to work as it is used to check if it is a RAC installation with olsnodes
            If olsnodes from the ASM Home returns no rows then we go with local opatch
END

printf "\n\033[1;37m%-8s\033[m\n" "OPTIONS"                     ;
cat << END
        -f      A file containing one or more opatch outputs (no opatch command is performed in this mode
                                        - not compatible with the -o option
                                        - compatible with the -g and -v options

                -o              An output file if you just want to generate the opatch output (no patch analysis shown)
                                        - not compatible with the -f option
                                        - compatible with the -g and -v options

        -l      Run opatch as Local only (default is opatch is run using the -all_nodes option)

        -g      Act as a grep command to grep the Homes you want to have the patches information
                Examples :
                  $0 -g 12                                              # Will only consider the Homes that contain "12" in their name
                  $0 -g /u01/app/oracle/product/12.1.0.2/dbhome_dr2     # Will only consider this home
                  $0 -g dbhome_1                                        # Will only consider the Homes containing "dbhome_1"
                                  $0 -g dbhome_1 -f /tmp/opatchoutput                                   # Will only consider the Homes containing "dbhome_1"in the /tmp/opatchoutput file

        -v      Act as a grep -v comnmand when selecting the Homes you want the patches information from; it can be combined with the -g option
                Examples :
                  $0 -v 12                                              # Will NOT consider the Homes which have"12" in their name
                  $0 -g dbhome_1 -v 12                          # Will consider the "dbhome_1" Homes BUT those containing "12" in their name
                  $0 -v grid                                    # All the Homes but the "grid" ones

        -s      Show the ORACLE_HOMEs that would be considered by the script, it can be used in conjunction with the -g and -v options
                You can then test your -g and -v combination here
                Examples :
                  $0 -s                                         # Show all Homes from /etc/oratab
                  $0 -g 12 -v oa -s                             # Show all "12" Homes BUT the "oa" ones
                                  $0 -f /tmp/opatchoutput -g 12 -s                              # Show the Homes from an opatch output file for the "12" Homes only

        -h      Show this help

END
exit 123
}

#
# Parameters management
#
while getopts "lg:v:f:o:hs" OPT; do
        case ${OPT} in
                f)               FILE=${OPTARG}                                 ;;
                o)                            OUT=${OPTARG}                                                                     ;;
                g)               GREP=${OPTARG}                                 ;;
                l)          ALL_NODES=""                                        ;;
                v)             UNGREP=${OPTARG}                                 ;;
                s)         SHOW_HOMES="YES"                                     ;;
                h)              usage                                           ;;
                \?) echo "Invalid option: -$OPTARG" >&2; usage                  ;;
        esac
done


#
# Different OS support
#

OS=`uname`
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
                       AWK=`which awk`                          ;;
        *)          echo "Unsupported OS, cannot continue."
                    exit 666                                    ;;
esac

if [ ! -f ${ORATAB} ]
then
cat << !
        Unable to find oratab file in ${ORATAB}, cannot continue.
!
        exit 667
fi
if [ ! -f ${AWK} ]
then
cat << !
        Cannot find a modern version of awk in ${AWK}, cannot continue.
!
        exit 668
fi

if [[ -n ${FILE} && -n ${OUT} ]]
then
        cat << END
        The -f and -o options cannot be used together; cannot continue.
        $0 -h for help
END
        exit 669
fi

#
# Show Homes only if -s option specified
#
if [ ${SHOW_HOMES} = "YES" ]
then
                if [[ -f ${FILE} ]]
                then
                        printf "\n\033[1;37m%-8s\033[m\n\n" "ORACLE_HOMEs that would be considered (${FILE}) :"                    ;
                        cat ${FILE} | grep "^Oracle Home" | awk 'BEGIN {FS=":"} { printf("\t%s\n", $NF)}' | grep ${GREP} | grep -v ${UNGREP} | sort | uniq
                else
                        printf "\n\033[1;37m%-8s\033[m\n\n" "ORACLE_HOMEs that would be considered (${ORATAB}) :"                    ;
                        cat ${ORATAB} | grep -v "^#" | grep -v "^$" | grep -v agent | awk 'BEGIN {FS=":"} { printf("\t%s\n", $2)}' | grep ${GREP} | grep -v ${UNGREP} | sort | uniq
                fi
                printf "\n"
        exit 0
fi

#
# Check that the file in parameter exists
#
if [ ! -f ${FILE} ]
then
cat << !
        File ${FILE} does not exist, cannot proceed.
!
exit 123
fi

#
# Check if we could write in the out file
#
if [[ -n ${OUT} ]]
then
        if [ -d ${OUT} ]; then  echo "${OUT} is a directory, please specify a regular file; cannot continue."; exit 670; fi
        if [ ! -w `dirname ${OUT}` ] ; then echo "`dirname ${OUT}` is not writable; cannot continue."; exit 671; fi
fi

#
# Set the ASM env to be able to use crsctl commands as well as olsnodes
#
ORACLE_SID=`ps -ef | grep pmon | grep asm | awk '{print $NF}' | sed s'/asm_pmon_//' | egrep "^[+]"`

#
# No ASM then we go local (I would need a RAC config with FS to test)
#
if [ -z ${ORACLE_SID} ]
then
            ALL_NODES=""
else
        export ORAENV_ASK=NO
        . oraenv > /dev/null 2>&1

        #
        # Check if it is a RAC installtion, if not we go Local with opatch
        #
        if [[ $(olsnodes | wc -l) -eq "0" ]]    # No RAC installed so we go local only
        then
                ALL_NODES=""
        fi
fi

if [ -z ${FILE} ]       # If a file as parameter we do not do the opatch
then
        cat /dev/null > ${TMP}

        for OH in `cat ${ORATAB} | grep -v "^#" | grep -v "^$" | grep -v agent | awk 'BEGIN {FS=":"} { print $2}' | grep ${GREP} | grep -v ${UNGREP} | sort | uniq`
        do
                printf "%-80s" "Proceeding with ${OH} . . ."
                if [ -f $OH/OPatch/opatch ] && [ -x $OH/OPatch/opatch ]
                then
                                $OH/OPatch/opatch lsinventory ${ALL_NODES} -oh ${OH}  >> ${TMP} 2>${TMP2}
                                ERR=$?
                                if [ ${ERR} -eq 0 ]
                                then
                                                printf "\t\033[1;32m%-8s\033[m\n" "OK"          ;
                                else
                                                printf "\t\033[1;31m%-8s" "Error "              ;
                                                cat ${TMP2}                                     ;
                                                printf "\033[m\n" ""                            ;
                                fi
                fi
        done
else
        cp ${FILE} ${TMP}
fi

#
# An output file is specified, we just want the opatch output so we exit before analyzing the opatch output
#
if [[ -n ${OUT} ]]
then
        if [ -f ${TMP} ]
        then
                cp ${TMP} ${OUT}
                if [ $? -ne 0 ]
                then
                        cat << END
                        Could not copy the tempfile into ${OUT}; the opatch output should be in ${TMP};
END
                fi
        rm -f ${TMP}
        exit $?
        fi
fi


printf "\n"                                                     ;

${AWK}  -v GREP="$GREP" -v UNGREP="$UNGREP"\
        'BEGIN {              FS =       ":"                    ;
                        # some colors
                     COLOR_BEGIN =       "\033[1;"              ;
                       COLOR_END =       "\033[m"               ;
                             RED =       "31m"                  ;
                           GREEN =       "32m"                  ;
                          YELLOW =       "33m"                  ;
                            BLUE =       "34m"                  ;
                            TEAL =       "36m"                  ;
                           WHITE =       "37m"                  ;

                         UNKNOWN =       "-"                    ;       # Something to print when the status is unknown

                        # Default columns size
                        COL_NODE =       16                     ;
                       COL_PATCH =       12                     ;
                         COL_VER =       14                     ;
}

#
# A function to center the outputs with colors
#
function center( str, n, color, sep)
{       right = int((n - length(str)) / 2)                                                                      ;
        left  = n - length(str) - right                                                                         ;
        return sprintf(COLOR_BEGIN color "%" left "s%s%" right "s" COLOR_END sep, "", str, "" )                 ;
}

#
# A function that just print a "---" white line
#
function print_a_line()
{
        printf("%s", COLOR_BEGIN WHITE)                                                                         ;
        for (k=1; k<=WIDTH; k++) {printf("%s", "-");}                                                           ;       # n = number of nodes
        printf("%s", COLOR_END"\n")                                                                             ;
}
{       if ($0 ~ /^Oracle Interim Patch Installer version/)
        {       gsub(/([aA-zZ])| /, "", $0)                                                                     ;
                OPATCH_VERSION=$0                                                                               ;
                gsub(/\./, "", $0)                                                                              ;
                OPATCH_VERSION_NUMERIC=$0                                                                       ;
                #
                # See https://unknowndba.blogspot.com/2018/06/deprecation-of-opatch-command-option.html
                # about versions 11.2.0.3.18 and 12.2.0.1.13 not having the -all_nodes option
                #
                if ((OPATCH_VERSION_NUMERIC == 1220113) || (OPATCH_VERSION_NUMERIC == 1120318))
                {       WARNING_NO_ALL_NODES = "YES"                                                            ;
                }
                if (((substr(OPATCH_VERSION_NUMERIC,1,2) == 12) && (OPATCH_VERSION_NUMERIC > 1220112)) ||
                    ((substr(OPATCH_VERSION_NUMERIC,1,2) == 11) && (OPATCH_VERSION_NUMERIC > 1120318)))
                {       NON_SUPPORTED_OPATCH="YES"                                                              ;
                }
        }
        if ($1 ~ /^Oracle Home/)
        {
                gsub(" ", "", $2)                                                                               ;
                OH=$2                                                                                           ;
                oh_tab[oh_nb++]=OH                                                                              ;
                                if ((OH !~ GREP) || (OH ~ UNGREP))
                            {
                                        next                                                                                                                                                                            ;
                                }

                while (getline)
                {
                        if ($1 ~ /^Hostname/)                                                                           # The hostname in case it is a local opatch
                        {
                                gsub(" ", "", $2)                                                               ;
                                sub(/\..*$/, "", $2)                                                            ;
                                  SERVER = $2                                                                   ;
                                nodes[1] = $2                                                                   ;
                                       n = 1                                                                    ;
                        }
                        if (($1 ~ /^Rac system comprising/) && (! NB_PATCHES_INSTALLED))                                # RAC Home
                        {
                                cpt=1                                                                           ;
                                while(getline)
                                {       if ($0 ~ /^$/)
                                        {       break                                                           ;
                                        }
                                        gsub(" ", "", $0)                                                       ;
                                        gsub(/^.*=/, "", $0)                                                    ;
                                        nodes[cpt] = $0                                                         ;
                                        cpt++                                                                   ;
                                }
                                n=asort(nodes)                                                                  ;       # sort array nodes

                        }
                        if (($1 ~ /^Patch level status of Cluster node/) && (! NB_PATCHES_INSTALLED))                   # Grid Homes
                        {       getline; getline; getline;
                                nodes_list = ""                                                                 ;
                                while(getline)
                                {
                                        if ($0 ~ /^$/)
                                        {
                                                split(nodes_list, nodes, ",")                                   ;
                                                n=asort(nodes)                                                  ;       # sort array nodes
                                                break                                                           ;
                                        }
                                        if ($1 ~ /^ *[0-9]* /)
                                        {
                                                sub(/^ *[0-9]* /, "", $1);
                                                gsub(" ", "", $1)                                               ;
                                                gsub("\t", "", $1)                                              ;
                                                if (nodes_list == "")
                                                {       nodes_list = $1                                         ;
                                                } else {
                                                        nodes_list=nodes_list","$1                              ;
                                                }
                                        }
                                }
                        }
                        if ($1 ~ /^Node Name/)
                        {
                                gsub(" ", "", $2)                                                               ;
                                SERVER=$2                                                                       ;
                        }
                        if ($1 ~ /^Interim patches/)
                        {
                                gsub(/^.*\(/, "", $1)                                                           ;
                                gsub(/\).*$/, "", $1)                                                           ;
                                NB_PATCHES_INSTALLED = $1                                                       ;
                                    NB_PATCHES_FOUND = 0                                                        ;

                                while(getline)
                                {
                                        if (($1 ~ /^Patch/) && ($0 ~ /applied on/))     # Patch id
                                        {       NB_PATCHES_FOUND++                                              ;
                                                sub("Patch", "", $1)                                            ;
                                                gsub(" ", "", $1)                                               ;
                                                patch_tab[SERVER, $1]=$1                                        ;       # Patches per server
                                                if ($1 in all_patches)
                                                { cpt++; } else {
                                                        all_patches[$1] = $1                                    ;       # All patches accross all nodes
                                                }
                                        }
                                        if (NB_PATCHES_FOUND == NB_PATCHES_INSTALLED)
                                        {       break                                                           ;
                                        }
                                }
                        }
                        if (($1 ~ /^OPatch succeeded/) || ($1 ~ /^OPatch completed with warnings/))
                        {

                                WIDTH = COL_PATCH+COL_NODE*n+n+1                                                ;
                                printf(COLOR_BEGIN BLUE"  %s"COLOR_END, OH)                                     ;       # OH as a title
                                printf("  %s\n", "(opatch version " OPATCH_VERSION")")                          ;       # Opatch version
                                # A header
                                print_a_line()                                                                  ;
                                printf("%s", center("Patch ID", COL_PATCH, WHITE, "|"))                         ;
                                for (i = 1; i <= n; i++)
                                {
                                       printf("%s", center(nodes[i], COL_NODE, WHITE, "|"))                     ;       # Hostname / nodes
                                }
                                printf("\n")                                                                    ;
                                print_a_line()                                                                  ;

                                some_patches=0                                                                  ;
                                           p=asort(all_patches)                                                 ;
                                for (i = 1; i <= p; i++)
                                {
                                        some_patches=1                                                          ;
                                        printf("%s", center(all_patches[i], COL_PATCH, WHITE, "|"))             ;

                                        for (j = 1; j <= n; j++)                # for each node
                                        {
                                                if (patch_tab[nodes[j], all_patches[i]] == all_patches[i])      # Patch is here
                                                {       printf("%s", center("-", COL_NODE, GREEN, "|"))         ;
                                                }
                                                else                                                            # Patch is missing
                                                {
                                                        printf("%s", center("Missing", COL_NODE, RED, "|"))     ;
                                                }
                                        }
                                        printf "\n"                                                             ;
                                }
                                if (some_patches == 0)
                                {       printf("%s\n", center("No patch installed ", WIDTH-1, TEAL, "|"))       ;
                                }

                                delete all_patches                                                              ;
                                delete patch_tab                                                                ;
                                delete nodes                                                                    ;
                                                                NB_PATCHES_INSTALLED=0                                                                                                                  ;
                                print_a_line()                                                                  ;
                                printf "\n"                                                                     ;
                                break                                                                           ;
                        }
                }

        }                       # End if ($1 ~ /^Oracle Home/)
} END {         if (WARNING_NO_ALL_NODES == "YES")
                {
                        printf("%s\n",   "Warning : Versions 12.2.0.1.13 and 11.2.0.3.1[89] have no -all_nodes options then cannot get any remote patch information")                      ;
                        printf("%s\n\n", "          Please have a look at https://unknowndba.blogspot.com/2018/06/deprecation-of-opatch-command-option.html for more information")      ;
                }
}' ${TMP}


for F in ${TMP} ${TMP2}
do
        if [ -f ${F} ]
        then
                rm -f ${F}
        fi
done

#************************************************************************#
#*                      E N D      O F      S O U R C E                 *#
#************************************************************************#
