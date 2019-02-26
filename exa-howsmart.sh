#!/bin/bash

#floltp1|1|cell physical IO bytes saved during optimized RMAN file restore|0
#floltp1|1|cell physical write IO host network bytes written during offloa|8388608
#floltp1|1|cell physical write IO bytes eligible for offload|21798912
#floltp1|1|cell physical IO bytes saved by columnar cache|53041889280
#floltp1|1|cell physical IO bytes sent directly to DB node to balance CPU |171941121824
#floltp1|1|cell physical write bytes saved by smart file initialization|3398103465984
#floltp1|1|cell physical IO bytes saved during optimized file creation|3459314910720
#floltp1|1|cell physical IO interconnect bytes returned by smart scan|94147266301496
#floltp1|1|cell physical IO interconnect bytes|1367331218435448
#floltp1|1|cell physical IO bytes saved by storage index|155235177959096320
#floltp1|1|cell physical IO bytes eligible for smart IOs|157785476981368320
#floltp1|1|cell physical IO bytes eligible for predicate offload|157785481194030592
#floltp1|1|physical read total bytes optimized|158126852436754432
#floltp1|1|physical read total bytes|158576363169814016
#physical write total bytes                                       3.2697E+14
#cell physical IO interconnect bytes                              1.3717E+15
#cell IO uncompressed bytes                                       2.3510E+15
#logical read bytes from cache                                    2.5733E+16
#


TMP=/tmp/exastats$$.tmp

. oraenv <<< floltp1 > /dev/null 2>&1
>  ${TMP}
sqlplus -S / as sysdba << END           | tee -a ${TMP}
set lines 200                                           ;
set head off                                            ;
set feed off                                            ;
col value for 99999999999999999999999999999999          ;
-- select (select instance_name from gv\$instance where inst_id = b.inst_id) || '|' || b.name || '|' || b.value from gv\$sysstat b where b.name like '%physical read total bytes%' or b.name like '%physical%' order by b.inst_id, value ;
select (select instance_name from gv\$instance where inst_id = b.inst_id) || '|' || b.name || '|' || b.value from gv\$sysstat b order by b.inst_id, value ;
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
                  BACK_LIGHTBLUE =      "104m"                  ;

                        # Size columns
                        COL_EVENT=      48                      ;
                        COL_NODE=       12                      ;

                        # Save info in arrays
                        if (NF == 3)
                        {
                                instances[$1] = $1      ;
                                        sub("cell physical IO",    "CPIO", $2)  ;
                                        sub("physical read total", "PRT",  $2)  ;
                                        sub("cell physical write", "CPW",  $2)  ;
                                        sub("physical write total", "PWT",  $2) ;
                                   events[$2] = $2      ;
                                   tab[$1,$2] = $3      ;
                        }

                        # Events
                        PRTB="PRT bytes"   ;
                        PRTBO="PRT bytes optimized"     ;
                        CPIOP="CPIO bytes eligible for predicate offload"       ;
                       CPIOSI="CPIO bytes saved by storage index"
                       CPIOSC="CPIO interconnect bytes returned by smart scan"
                        CPIOI="CPIO interconnect bytes"
                          UNC="cell IO uncompressed bytes"
                          PWT="PWT bytes"
                         PWTO="PWT bytes optimized"
                         CWFC="cell writes to flash cache"
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
         #
         # Calculate and print a ratio as a ine of the output table
         #
         function print_ratio(event, eventtodivideby, threshold)
         {
                if (! threshold)                { threshold  = "80|95"  ;}
                if (! eventtodivideby)
                {       printf (COLOR_BEGIN BACK_LIGHTBLUE"%-" COL_EVENT"s"COLOR_END"|", event) ;
                } else {
                        printf ("%-"COL_EVENT"s|", event)       ;
                }

                for(i=1; i<=nb_inst; i++)
                {
                        value_event = tab[instances[i],events[event]]                   # Value of the event for this instance
                        sum_event += value_event                                        # For the overall value
                        if (eventtodivideby)                                            # If an event to divide, we calculate a %
                        {
                                divider = tab[instances[i],events[eventtodivideby]]     # value of the event to dovide by to get a %
                                sum_divider += divider                          ;       # For the overall value
                                  value = (value_event/divider*100)             ;
                                printf ("%s", center(sprintf("%.2f%%", value), COL_NODE, WHITE, "|"))   ;
                        } else {                                                        # Nothing to divide with, we just print the event value
                                printf ("%s", center(sprintf("%.2e", value_event), COL_NODE, WHITE, "|"))        ;
                        }
                }
                # Perint the overall value
                if (eventtodivideby)
                {       printf ("%s", center(sprintf("%.2f%%", sum_event/sum_divider*100), COL_NODE, WHITE, "|"))   ;
                } else {
                        printf ("%s", center(sprintf("%.2e", sum_event), COL_NODE, WHITE, "|"))   ;
                }
                eventtodivideby = ""    ;
                      sum_event = 0     ;
                    sum_divider = 0     ;
                printf ("\n");
         }
          END   {       nb_inst = asorti(instances)     ;
                        line_size=COL_EVENT+COL_NODE*(nb_inst+1)+nb_inst+1

                        #for (x in events)
                        #{      print events[x] ;
                        #}
                        # Header
                        print_a_line(line_size)                                         ;
                        printf ("%s", center("Event" , COL_EVENT, BLUE, "|"))        ;
                        for(i=1; i<=nb_inst; i++)
                        {
                                printf ("%s", center(instances[i], COL_NODE, BLUE, "|"))        ;
                        }
                        printf ("%s", center("Overall", COL_NODE, BLUE, "|"))        ;
                        printf ("\n");
                        print_a_line(line_size)                                         ;

                        # Print the events we want
                        print_ratio(events[PRTB])                       ;
                        print_ratio(events[PRTBO], events[PRTB])        ;
                        print_ratio(events[CPIOP], events[PRTB])        ;
                        print_ratio(events[CPIOP])                      ;
                        print_ratio(events[CPIOSI], events[CPIOP])      ;
                        print_ratio(events[UNC])                        ;
                        print_ratio(events[CPIOSC], events[UNC])        ;
                        print_ratio(events[CPIOI], events[UNC])         ;
                        print_ratio(events[PWT])                        ;
                        print_ratio(events[PWTO], events[PWT])          ;
                        print_ratio(events[CWFC], events[PWT])          ;

                        print_a_line(line_size)                         ;
                        printf ("\n");
                }
        '  ${TMP}


if [[ -f ${TMP} ]]
then
        rm -f ${TMP}
fi


echo "PRT  : physical read total"
echo "PWT  : physical write total"
echo "CPIO : cell physical IO"
echo "CPW  : cell physical write"
