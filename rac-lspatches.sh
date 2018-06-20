
#!/bin/bash
# Fred Denis -- denis@pythian.com -- June 18th 2018
#
# lspatches of every HOME
#

#
# Default values
#

ALL_NODES=" -all_nodes "                # We do lsinventory -all_nodes
     HOME="."                           # We do not grep any specific home
     FILE=""                            # No input file
      TMP=/tmp/fictemplspatches$$       # A tempfile

#
# Parameters management
#
while getopts "lo:f:" OPT; do
        case ${OPT} in
        l)          ALL_NODES=""                                        ;;
        o)               HOME=${OPTARG}                                 ;;
        f)               FILE=${OPTARG}                                 ;;
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

if [ -n ${FILE} ]       # If a file as parameter we do not do the opatch
then
        cat /dev/null > ${TMP}

        for OH in `cat /etc/oratab | grep "^[Aa-Zz|+]" | grep -v agent | awk 'BEGIN {FS=":"} { print $2}' | grep ${HOME} | sort | uniq`
        do
                echo "Proceeding with " ${OH} " . . ."
                if [ -f $OH/OPatch/opatch ] && [ -x $OH/OPatch/opatch ]
                then
                        export ORACLE_HOME=${OH}
                        $OH/OPatch/opatch lsinventory ${ALL_NODES}      >> ${TMP} 2>&1
                fi
        done
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
                                OH=$2                                                                                           ;
                                oh_tab[oh_nb++]=OH                                                                              ;

                                while (getline)
                                {
                                        if ($1 ~ /^Hostname/)
                                        {
                                                gsub(" ", "", $2)                                                               ;
                                                sub(/\..*$/, "", $2)                                                            ;
                                                  SERVER = $2                                                                   ;
                                                nodes[1] = $2                                                                   ;
                                                       n = 1                                                                    ;
                                        }
                                        if ($1 ~ /^Rac system comprising/ )
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
                                                                if (patch_tab[nodes[j], all_patches[i]] == all_patches[i])              # Patch is here
                                                                {       printf("%s", center("-", COL_NODE, GREEN, "|"))         ;
                                                                }
                                                                else                                                    # Patch is missing
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
                } ' ${TMP} ${FILE}

echo ${TMP}

#if [ -f ${TMP} ]
#then
#       rm -f ${TMP}
#fi

#************************************************************************#
#*                      E N D      O F      S O U R C E                 *#
#************************************************************************#
