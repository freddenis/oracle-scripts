#!/bin/bash
# Fred Denis -- denis@pythian.com -- 18th 2017
#
# lspatches of every HOME
#

TMP=/tmp/fictemplspatches$$
FILE=a

#
# Set the ASM env to be able to use crsctl commands as well as olsnodes
#
ORACLE_SID=`ps -ef | grep pmon | grep asm | awk '{print $NF}' | sed s'/asm_pmon_//' | egrep "^[+]"`

export ORAENV_ASK=NO
. oraenv > /dev/null 2>&1


#
# Get the cluster name -- we could get it from  olsnodes -c but sometimes the cluster name is not quite like the host names
# Assuming people usually name their hostnames <cluster_name>db<XX>
# See later if I can make it better or it suits the most -- and it is just to make the output more visible
#
CLUSTER_NAME=`hostname -s | sed s'/db.*//'`

#
# List of the nodes of the cluster
#
NODES=`olsnodes | awk '{if (NR<2){txt=$0} else{txt=txt","$0}} END {print txt}'`

cat /dev/null > ${TMP}

#for OH in `cat /etc/oratab | grep "^[Aa-Zz|+]" | grep -v agent | awk 'BEGIN {FS=":"} { print $2}' | sort | uniq`
#do
#       echo "oh:" $OH
#       if [ -f $OH/OPatch/opatch ] && [ -x $OH/OPatch/opatch ]
#       then
#               echo "Start OH : " $OH  | tee -a  ${TMP}
#               export ORACLE_HOME=${OH}
#               $OH/OPatch/opatch lsinventory -all_nodes  | tee -a  ${TMP}
##              $OH/OPatch/opatch lsinventory -all_nodes | grep -e "^Node Name" -e "^Patch" | grep -v "description:" | sed s'/^Patch *//' | sed s'/: applied.*$//g'  | tee -a  ${TMP}
#               echo "End OH : " $OH   | tee -a  ${TMP}
#       fi
#done
#
#echo $TMP
#
#exit


#| tee -a ${TMP} |
 awk -v CLUSTER_NAME="$CLUSTER_NAME" -v NODES="$NODES"\
        'BEGIN {        FS=":"  ;
                        gsub(CLUSTER_NAME, "", NODES)           ;
                      split(NODES, nodes, ",")                  ;       # Make a table with the nodes of the cluster
                        n=asort(nodes)                                                                          ;       # sort array nodes

                        # some colors
                     COLOR_BEGIN =       "\033[1;"              ;
                       COLOR_END =       "\033[m"               ;
                             RED =       "31m"                  ;
                           GREEN =       "32m"                  ;
                          YELLOW =       "33m"                  ;
                            BLUE =       "34m"                  ;
                            TEAL =       "36m"                  ;
                           WHITE =       "37m"                  ;

                         UNKNOWN = "-"                          ;       # Something to print when the status is unknown

                        # Default columns size
                        COL_NODE = 8                           ;
                          COL_PATCH = 12                           ;
                         COL_VER = 14                           ;
                        COL_TYPE = 12                           ;
                           WIDTH = COL_PATCH*(n+1)+n+1          ;
                        printf("\t"COLOR_BEGIN WHITE "%s" COLOR_END "\n\n", "Patchs on the OH installed on the cluster " CLUSTER_NAME)  ;
                }

                #
                # A function to center the outputs with colors
                #
                function center( str, n, color)
                {       right = int((n - length(str)) / 2)                                                              ;
                        left  = n - length(str) - right                                                                 ;
                        return sprintf(COLOR_BEGIN color "%" left "s%s%" right "s" COLOR_END "|", "", str, "" )         ;
                }

                #
                # A function that just print a "---" white line
                #
                function print_a_line()
                {
                        printf("%s", COLOR_BEGIN WHITE)                                                                 ;
                        for (k=1; k<=WIDTH; k++) {printf("%s", "-");}                ;       # n = number of nodes
                        printf("%s", COLOR_END"\n")                                                                     ;
                }
                {
                        if ($1 ~ /^Oracle Home/)                                                # For each OH
                        {
                                echo "hey"              ;
                                server_nb=0             ;
                                OH=$2                   ;
                                oh_tab[oh_nb++]=OH      ;
                                printf("%s\n", center(OH, WIDTH-1, BLUE))       ;       # OH as a title
                                # A header
                                print_a_line()  ;
                                printf("%s", center("Patch ID", COL_PATCH, WHITE))      ;
                                for (i = 1; i <= n; i++)
                                {
                                       printf("%s", center(nodes[i], COL_PATCH, WHITE))                                 ;       # Hostnamea / nodes
                                }
                                printf("\n")    ;
                                print_a_line()  ;

                                while (getline)
                                {
                                        if ($1 ~ /^Node Name/)                  # For each node
                                        {
                                                sub(CLUSTER_NAME, "", $2)       ;
                                                SERVER=$2                       ;
                                                server_tab[server_nb++] = SERVER        ;
                                                print SERVER ;

                                                while(getline)
                                                {       if (($1 ~ /^Patch/) && ($1 !~ /description/))   # Patch id
                                                        {       sub("Patch", "", $1)            ;
                                                                gsub(" ", "", $1)               ;
                                                                patch_tab[SERVER, $1]=$1                ;
                                                                if ($1 in all_patches)
                                                                { cpt++; } else {
                                                                        all_patches[$1] = $1    ;
                                                                }
                                                        }
                                                        if ($1 ~ /^Node Name/)          # End of node
                                                        {       break           ;
                                                        }
                                                }
                                        }
                                        if ($1 ~ /^Binary/)                             # End OH
                                        {       some_patches=0  ;
                                                p=asort(all_patches);
                                                for (i = 1; i <= p; i++)
                                                {
                                                        some_patches=1  ;
                                                        printf("%s", center(all_patches[i], COL_PATCH, WHITE))                                       ;

                                                        for (j = 1; j <= n; j++)                # for each node
                                                        {
                                                                if (patch_tab[nodes[j], all_patches[i]])                # Patch is here
                                                                {       printf("%s", center("-", COL_PATCH, GREEN))     ;
                                                                }
                                                                else                                                    # Patch is missing
                                                                {
                                                                        printf("%s", center("Missing", COL_PATCH, RED))     ;
                                                                }
                                                        }
                                                        printf "\n" ;
                                                }
                                                if (some_patches == 0)
                                                {       printf("%s\n", center("No patch installed ", WIDTH-1, TEAL))     ;
                                                }

                                                delete all_patches      ;
                                                delete patch_tab        ;
                                                print_a_line()  ;
                                                printf "\n" ;
                                                break   ;
                                        }
                                }

                        }
                }
                END\
                {
#                       for (x in oh_tab)
#                       {
#                               print "=>" oh_tab[x]    ;                                                       # OH Name
#                               #printf("%s", center("Patch", COL_DB, WHITE))           ;
#                               for (i = 1; i <= n; i++)
#                               {
#                                       printf("%s", center(nodes[i], COL_NODE, WHITE))                                 ;       # Hostnamea / nodes
#                               }
#                               printf("\n")    ;
#
#                               for (y in server_tab)
#                               {
#                                       print server_tab[y]     ;
#                                       #split(patch_tab[oh_tab[x],server_tab[y]], patch_list, "|")     ;
#                                       #asort(patch_list);
#                                       print patch_tab[oh_tab[x],server_tab[y]]        ;
#                               }
#                       }

                } '  /tmp/fictemplspatches51178


#> ${TMP}

echo $TMP
