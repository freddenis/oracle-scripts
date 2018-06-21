#!/bin/bash
# Fred Denis -- denis@pythian.com -- 18th 2017
#
# Provide information on the installed and missing patches on ORACLE_HOMEs
#       $0 -h for more information
#
# The version of the script is 20180621
#
# 20180621 - Fred Denis - Initial release
#

#
# Default values
#

ALL_NODES=" -all_nodes "                                # We do lsinventory -all_nodes
GREP="."                                           # What we grep                  -- default is everything
UNGREP="nothing_to_ungrep_unless_v_option_is_used$$" # What we don't grep (grep -v)  -- default is nothing
FILE=""                                            # No input file
TMP=/tmp/fictemplspatches$$                       # A tempfile

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
$0 [-f] [-g] [-l] [-v] [-h]
END

printf "\n\033[1;37m%-8s\033[m\n" "DESCRIPTION"                 ;
cat << END
$0 relies on the content of the /etc/oratab file to look at the installed patch on the ORACLE_HOMEs
It uses the opatch installed on each Home to list the installed patches and find the missing ones in case of RAC system
A file containing some opatch outputs can also be provided to $0; it will then not use opatch but rely on the input file
END

printf "\n\033[1;37m%-8s\033[m\n" "OPTIONS"                     ;
cat << END
-f      A file containing one or more opatch outputs (no opatch command is performed in this mode)
-l      Run opatch as Local only (default is opatch is run using the -all_nodes option)
-g      Act as a grep command to grep the Homes you want to have the patches information
   Examples :
        $0 -g 12                                                # Will only consider the Homes that contain "12" in their name
        $0 -g /u01/app/oracle/product/12.1.0.2/dbhome_dr2       # Will only consider this home
        $0 -g dbhome_1                                  # Will only consider the Homes containing "dbhome_1"
-v      Act as a grep -v comnmand when selecting the Homes you want the patches information from; it can be combined with the -g option
   Examples :
        $0 -v 12                                                # Will NOT consider the Homes which have"12" in their name
        $0 -g dbhome_1 -v 12                            # Will consider the "dbhome_1" Homes BUT those containing "12" in their name
        $0 -v grid                                              # All the Homes but the grid ones
-h      Show this help
END
exit 123
}

#
# Parameters management
#
while getopts "lg:v:f:h" OPT; do
case ${OPT} in
f)               FILE=${OPTARG}                                 ;;
g)               GREP=${OPTARG}                                 ;;
l)          ALL_NODES=""                                        ;;
v)             UNGREP=${OPTARG}                                 ;;
h)              usage                                           ;;
\?) echo "Invalid option: -$OPTARG" >&2; usage                  ;;
esac
done

if [ ! -f ${FILE} ]
then
cat << !
File ${FILE} does not exist, cannot proceed.
!
exit 123
fi


#
# Set the ASM env to be able to use crsctl commands as well as olsnodes
#
ORACLE_SID=`ps -ef | grep pmon | grep asm | awk '{print $NF}' | sed s'/asm_pmon_//' | egrep "^[+]"`

export ORAENV_ASK=NO
. oraenv > /dev/null 2>&1

if [ -z ${FILE} ]       # If a file as parameter we do not do the opatch
then
cat /dev/null > ${TMP}

for OH in `cat /etc/oratab | grep "^[Aa-Zz|+]" | grep -v agent | awk 'BEGIN {FS=":"} { print $2}' | grep ${GREP} | grep -v ${UNGREP} | sort | uniq`
do
echo "Proceeding with " ${OH} " . . ."
if [ -f $OH/OPatch/opatch ] && [ -x $OH/OPatch/opatch ]
then
        export ORACLE_HOME=${OH}
        $OH/OPatch/opatch lsinventory ${ALL_NODES}      >> ${TMP} 2>&1
fi
done
else
cp ${FILE} ${TMP}
fi

awk    'BEGIN {               FS =        ":"                   ;
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
        COL_TYPE =       12                     ;
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
        for (k=1; k<=WIDTH; k++) {printf("%s", "-");}                                                           ;  # n = number of nodes
        printf("%s", COLOR_END"\n")                                                                             ;
}
{
        if ($1 ~ /^Oracle Home/)
        {
                gsub(" ", "", $2)                                                                               ;
                OH=$2                                                                                           ;
                oh_tab[oh_nb++]=OH                                                                              ;

                while (getline)
                {
                        if ($1 ~ /^Hostname/)                                   # The hostname in case it is a local opatch
                        {
                                gsub(" ", "", $2)                                                               ;
                                sub(/\..*$/, "", $2)                                                            ;
                                  SERVER = $2                                                                   ;
                                nodes[1] = $2                                                                   ;
                                       n = 1                                                                    ;
                        }
                        if ($1 ~ /^Rac system comprising/ )                     # If this is a RAC Home
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
                        # Grid Homes have specific headers with the nodes ansd the patch level
                        # If we check teh patches locally, the header is still there as a footer
                        # I then have to check if some patches have already been found to not grab the hosts from the footer
                        if (($1 ~ /^Patch level status of Cluster node/) && (! NB_PATCHES_INSTALLED))           # Grid Homes
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
                                printf("%s\n", center(OH, WIDTH-1, BLUE, ""))                                   ;       # OH as a title
                                # A header
                                print_a_line()                                                                  ;
                                printf("%s", center("Patch ID", COL_PATCH, WHITE, "|"))                         ;
                                for (i = 1; i <= n; i++)
                                {
                                       printf("%s", center(nodes[i], COL_PATCH, WHITE, "|"))                    ;       # Hostname / nodes
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
                                print_a_line()                                                                  ;
                                printf "\n"                                                                     ;
                                break                                                                           ;
                        }
                }

        }
} ' ${TMP}

#echo ${TMP}

if [ -f ${TMP} ]
then
rm -f ${TMP}
fi

#************************************************************************#
#*                      E N D      O F      S O U R C E                 *#
#************************************************************************#
