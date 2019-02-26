#!/bin/bash



TMP=/tmp/exastats$$.tmp

. oraenv <<< floltp1 > /dev/null 2>&1

sqlplus -S / as sysdba << END           > ${TMP}
set lines 200                                           ;
set head off                                            ;
set feed off                                            ;
col value for 99999999999999999999999999999999          ;
select a.instance_name || '|' || b.name || '|' || b.value from gv\$instance a, gv\$sysstat b where a.inst_id = b.inst_id and b.name like '%physical read total bytes%' or b.name like 'cell physical%' order by a.instance_name, b.name;
END

awk     ' BEGIN {FS="|"}
                {
                        # Some colors
                     COLOR_BEGIN =       "\033[1;"              ;
                       COLOR_END =       "\033[m"               ;
                             RED =       "31m"                  ;
                           GREEN =       "32m"                  ;
                          YELLOW =       "33m"                  ;
                            BLUE =       "34m"                  ;
                            TEAL =       "36m"                  ;
                           WHITE =       "37m"                  ;

                        # Size columns
                        COL_EVENT=      25                      ;
                        COL_NODE=       20                      ;

                        # Save info in arrays
                        if (NF == 3)
                        {
                                instances[$1] = $1      ;
                                        sub("cell physical IO",    "CPIO", $2)  ;
                                        sub("physical read total", "PRT",  $2)  ;
                                        sub("cell physical write", "CPW",  $2)  ;
                                   events[$2] = $2      ;
                                   tab[$1,$2] = $3      ;
                        }
                }
          #
          # A function to center the outputs with colors
          #
          function center( str, n, color, sep)
          {       right = int((n - length(str)) / 2)                                                                    ;
                left  = n - length(str) - right                                                                         ;
                return sprintf(COLOR_BEGIN color "%" left "s%s%" right "s" COLOR_END sep, "", str, "" )                 ;
          }
         #
         # A function that just print a "---" white line
         #
         function print_a_line(size)
         {
                if ( ! size)
                {       size = COL_DB+COL_VER+(COL_NODE*n)+COL_TYPE+n+3                 ;
                }
                printf("%s", COLOR_BEGIN WHITE)                                         ;
                for (k=1; k<=size; k++) {printf("%s", "-");}                            ;
                printf("%s", COLOR_END"\n")                                             ;
         }
          END   {       nb_inst = asorti(instances)     ;

                        #for (x in events)
                        #{      print events[x] ;
                        #}
                        # Header
                        print_a_line(COL_EVENT+COL_NODE*nb_inst+nb_inst+1)      ;
                        printf ("%s", center("Event" , COL_EVENT, TEAL, "|"))        ;
                        for(i=1; i<=nb_inst; i++)
                        {
                                printf ("%s", center(instances[i], COL_NODE, TEAL, "|"))        ;
                        }
                        printf ("\n");
                        print_a_line(COL_EVENT+COL_NODE*nb_inst+nb_inst+1)      ;


                        P="PRT bytes"   ;
                        printf ("%-"COL_EVENT"s|", P)   ;
                        for(i=1; i<=nb_inst; i++)
                        {
                                printf ("%s", center(tab[instances[i],P], COL_NODE, WHITE, "|"))        ;
                        }
                        printf ("\n");
                        O="PRT bytes optimized" ;
                        printf ("%-25s|", O)    ;
                        for(i=1; i<=nb_inst; i++)
                        {
                                printf ("%s", center(sprintf("%.2f%%", (tab[instances[i],O]/tab[instances[i],P]*100)),20, WHITE, "|"))        ;
                        }
                        printf ("\n");
                        print_a_line(COL_EVENT+COL_NODE*nb_inst+nb_inst+1)      ;
                        printf ("\n");
                }
        '  ${TMP}


if [[ -f ${TMP} ]]
then
        rm -f ${TMP}
fi


echo "PRT  : physical read total"
echo "CPIO : cell physical IO"
echo "CPW  : cell physical write"
