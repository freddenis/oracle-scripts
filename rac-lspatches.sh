#!/bin/bash
# Fred Denis -- denis@pythian.com -- 18th 2017
#
# lspatches of every HOME
#

TMP=/tmp/fictemplspatches$$

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

#(for X in `crsctl stat res -p -w "TYPE = ora.database.type" |\
#        awk ' BEGIN {FS="="}
#             {
#                if ($1 ~ /^ACL/)
#                {
#                       sub("owner:", "", $2)   ;
#                       gsub(":.*", "", $2)             ;
#                        OWNER=$2                          ;
#                        while(getline)
#                        {
#                                if ($1 ~ /ORACLE_HOME/)
#                                {
#                                       OH=$2   ;
#                                       print OWNER"|"OH        ;
#                                        next    ;
#                                }
#                        }
#               print OWNER     ;
#                }
#           }' | sort | uniq`
#do
#     OWNER=`echo $X | awk -F "|" '{print $1}'`
#        OH=`echo $X | awk -F "|" '{print $2}'`
#
#       echo "Start OH:"$OH                                             # Easier to awk later on
#
#       for S in `olsnodes`
#       do
#               echo "Start opatch on:"${S}                             # Easier to awk later on
#
#               ssh -q -o batchmode=yes ${OWNER}@${S}  << END_SSH 2> /dev/null
#               $OH/OPatch/opatch lspatches | sort
#
#               echo "End opatch on:"${S}                               # Easier to awk later on
#END_SSH
#       done
#       echo "End OH:"$OH                                               # Easier to awk later on
#
#done) | tee -a ${TMP} |
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
                        for (k=1; k<=COL_PATCH*(n+1)+n+1; k++) {printf("%s", "-");}                ;       # n = number of nodes
                        printf("%s", COLOR_END"\n")                                                                     ;
                }
                {
                        if ($1 ~ /Start OH/)                                            # For each OH
                        {
                                server_nb=0             ;
                                OH=$2                   ;
                                oh_tab[oh_nb++]=OH      ;
                                printf("%s\n", center(OH, COL_PATCH, BLUE))     ;       # OH as a title
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
                                        if ($1 ~ /Start opatch on/)                     # For each node
                                        {
                                                sub(CLUSTER_NAME, "", $2)       ;
                                                SERVER=$2                       ;
                                                server_tab[server_nb++] = SERVER        ;

                                                while(getline)
                                                {       if ($1 ~ /^[0-9]/)      # Patch id
                                                        {       sub(";.*$", "", $0)             ;
                                                                patch_tab[SERVER, $0]=$0                ;
                                                                if ($0 in all_patches)
                                                                { cpt++; } else {
                                                                        all_patches[$0] = $0    ;
                                                                }
                                                        }
                                                        if ($1 ~ /End opatch/)          # End of node
                                                        {       break           ;
                                                        }
                                                }
                                        }
                                        if ($1 ~ /End OH/)                              # End OH
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
                                                {       printf("|\t%s\n", center("No patch installed ", COL_PATCH, TEAL))     ;
                                                }

                                                delete all_patches      ;
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

                } ' "/tmp/fictemplspatches378149"


#> ${TMP}

echo $TMP


