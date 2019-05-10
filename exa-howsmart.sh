#!/bin/bash
# Fred Denis - March 2019
#
#*** Script in DEV ***
#
# History:
# 20190510 - Fred Denis -- divide by zero when no HCC in 12.2
#

TMP=/tmp/exastats$$.tmp

#. oraenv <<< floltp1 > /dev/null 2>&1
#cat /dev/null >  ${TMP}
#sqlplus -S / as sysdba << END           | tee -a ${TMP}
sqlplus -S / as sysdba << END           >  ${TMP}
set lines 200                                                           ;
set head off                                                            ;
set feed off                                                            ;
col value for 99999999999999999999999999999999                          ;
select (select instance_name from gv\$instance where inst_id = b.inst_id) || '|' || b.name || '|' || b.value from gv\$sysstat b order by b.inst_id, value ;
END


awk     ' BEGIN {FS="|"}
          {
                # Some colors
             COLOR_BEGIN =       "\033[1;"                      ;
               COLOR_END =       "\033[m"                       ;
                     RED =       "31m"                          ;
                   GREEN =       "32m"                          ;
                  YELLOW =       "33m"                          ;
                    BLUE =       "34m"                          ;
                    TEAL =       "36m"                          ;
                   WHITE =       "37m"                          ;
                  NORMAL =        "0m"                          ;
          BACK_LIGHTBLUE =      "104m"                          ;

                # Size columns
                COL_EVENT=      35                              ;
                COL_NODE =      12                              ;
                # Misc
                   FIRST =      1                               ;

                # Save info in arrays
                if (NF == 3)
                {
                        instances[$1] = $1                      ;
                        gsub(/ *$/, "", $2)                     ;
                        sub("cell physical IO",    "CPIO", $2)  ;
                        sub("physical read total", "PRT",  $2)  ;
                        sub("cell physical write", "CPW",  $2)  ;
                        sub("physical write total", "PWT",  $2) ;
                        events[$2] = $2                         ;
                        tab[$1,$2] = $3                         ;
                }

                # Events
                 LRFC="logical read bytes from cache"                           ;   LRFC_descr="logical read from cache (bytes)"        ;
                 PRTB="PRT bytes"                                               ;   PRTB_descr="Physical read (bytes)"                  ;
                PRTBO="PRT bytes optimized"                                     ;  PRTBO_descr="Physical read optimized"                ;
                CPIOP="CPIO bytes eligible for predicate offload"               ;  CPIOP_descr="Eligible for Smart Scans (bytes)"       ;
               CPIOSI="CPIO bytes saved by storage index"                       ; CPIOSI_descr="% saved by Storage Index"               ;
              CPIOSCC="CPIO bytes saved by columnar cache"                      ;CPIOSCC_descr="% saved by Columnar Cache"              ;
               CPIOSC="CPIO interconnect bytes returned by smart scan"          ; CPIOSC_descr="% returned by Smart Scans"              ;
                CPIOI="CPIO interconnect bytes"                                 ;                                                               # IN + OUT Traffic + count ASM mirrorring
               CPIOFC="CPIO bytes saved during optimized file creation"         ; CPIOFC_descr="% saved during file creation"           ;
             CPIOBCPU="CPIO bytes sent directly to DB node to balance CPU"      ;CPIOBCPU_descr="When cells are overloaded"             ;
                  UNC="cell IO uncompressed bytes"                              ;    UNC_descr="cell IO uncompressed (bytes)"           ;
                  PWT="PWT bytes"                                               ;    PWT_descr="Physical writes"                        ;
                 PWTO="PWT bytes optimized"                                     ;   PWTO_descr="Physical writes optimized"              ;
                 CWFC="cell writes to flash cache"                              ;   CWFC_descr="Writes to Flash Cache"                  ;
              HCCCUNC="HCC scan cell bytes decompressed"                        ;HCCCUNC_descr="HCC decompressed on cell (bytes)"       ;
              HCCBUNC="HCC scan rdbms bytes decompressed"                       ;HCCBUNC_descr="% decompressed on rdbms"                ;
                   PW="physical writes"                                         ;     PW_descr="Nb of physical writes"                  ;       # Includes ASM mirorring so unusable

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
         # Calculate and print a ratio as a line of the output table
         #
         function print_ratio(event, event_descr, eventtodivideby, threshold)
         {
                if (! threshold)                { threshold  = "80|95"  ;}
                if (event_descr)        # If there is a description, we print it as it is usually more friendly
                {       	to_print=event_descr    				;
                } else {	to_print=event          				;
                }
                if (! eventtodivideby)
                {       if (! FIRST)
			{	printf ("%s\n", center("", line_size, WHITE, "|"))			;
			}
                        printf (COLOR_BEGIN BACK_LIGHTBLUE"%-" COL_EVENT"s"COLOR_END"|", to_print)	;
                        FIRST=0										;
                } else {
                        printf ("  %-"COL_EVENT-2"s|", to_print)       					;	# -2 as I put 2 spaces before to "indent"
                }

                for(i=1; i<=nb_inst; i++)
                {
                        value_event = tab[instances[i],events[event]]                  			 	# Value of the event for this instance
                         sum_event += value_event                                      				# For the overall value
                        if (eventtodivideby)                                            			# If an event to divide, we calculate a %
                        {	    divider  = tab[instances[i],events[eventtodivideby]]     			# Value of the event to divide by to get a %
                                sum_divider += divider                          			;       # For the overall value
				if (divider != 0)
				{     value  = (value_event/divider*100)             			;
				}
                                printf ("%s", center(sprintf("%.2f%%", value), COL_NODE, NORMAL, "|"))	;
                        } else {                                                        			# Nothing to divide with, we just print the event value
                                printf ("%s", center(sprintf("%.2e", value_event), COL_NODE, NORMAL, "|"));
                        }
                }
                # Print the overall value
                if (eventtodivideby)
                {       if (sum_divider != 0)
			{		printf ("%s", center(sprintf("%.2f%%", sum_event/sum_divider*100), COL_NODE, WHITE, "|"))   ;
			} else {	printf ("%s", center(sprintf("%s", "n/a"), COL_NODE, WHITE, "|"))   ;
			} 
                } else  {
                        printf ("%s", center(sprintf("%.2e", sum_event), COL_NODE, WHITE, "|"))	;
                }
#               # Print the description outside on the right of the table
#               printf ("%s", event_descr)      ;
                eventtodivideby = ""    							;
                      sum_event = 0     							;
                    sum_divider = 0     							;
                printf ("\n")									;
         }
          END   {       nb_inst = asorti(instances)     					;
                        line_size=COL_EVENT+COL_NODE*(nb_inst+1)+nb_inst+1			;

                        # Header
                        printf("\n");
                        print_a_line(line_size)                                                 ;
                        printf ("%s", center("Event" , COL_EVENT, BLUE, "|"))                   ;
                        for(i=1; i<=nb_inst; i++)
                        {
                                printf ("%s", center(instances[i], COL_NODE, BLUE, "|"))        ;
                        }
                        printf ("%s", center("Overall", COL_NODE, BLUE, "|"))                   ;
                        printf ("\n");
                        print_a_line(line_size)                                                 ;

                        # Print the events we want
                        print_ratio(events[LRFC], LRFC_descr)                                   ;
                        print_ratio(events[PRTB], "% Physical read", events[LRFC])              ;
                        print_ratio(events[PWT], "% Physical write", events[LRFC])              ;

                        print_ratio(events[PRTB], PRTB_descr)                                   ;
                        print_ratio(events[PRTBO], PRTBO_descr, events[PRTB])                   ;
                        print_ratio(events[CPIOP], "% eligible for Smart Scans", events[PRTB])  ;

                        print_ratio(events[CPIOP], CPIOP_descr)                                 ;
                        print_ratio(events[CPIOSI], CPIOSI_descr, events[CPIOP])                ;
                        print_ratio(events[CPIOFC], CPIOFC_descr, events[CPIOP])                ;
                        print_ratio(events[CPIOSCC], CPIOSCC_descr, events[CPIOP])              ;
                        print_ratio(events[CPIOBCPU], CPIOBCPU_descr, events[CPIOP])            ;

                        print_ratio(events[UNC], UNC_descr)                                     ;
                        print_ratio(events[CPIOSC], CPIOSC_descr, events[UNC])                  ;
                        # Physical writes includes ASM mirorring so useless here
                        #print_ratio(events[PW], PW_descr)                                      ;
                        #print_ratio(events[CWFC], CWFC_descr, events[PW])                      ;
                        # HCC events have all changed in 12.2
                        if (events[HCCBUNC])
                        {
                                print_ratio(events[HCCCUNC], HCCCUNC_descr)                     ;
                                print_ratio(events[HCCBUNC], "% decompressd on DB Server", events[HCCCUNC])          ;
                        }
                        print_a_line(line_size)                                                 ;
                        printf ("\n")                                                           ;
                }
        '  ${TMP} | sed s'/^/  /'

if [[ -f ${TMP} ]]
then
        rm -f ${TMP}
fi

#****************************************************************#
#*              E N D      O F      S O U R C E                 *#
#****************************************************************#
