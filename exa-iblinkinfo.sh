#!/bin/bash
# Fred Denis -- July 2019 -- http://unknowndba.blogspot.com -- fred.denis3@gmail.com
#
# Show a nice table of what is plugged from/to IB switches from the iblinkinfo command
# Need to be launched as root as iblinkinfo needs root privileges
#
# The current script version is still in DEV
#
# History :
#
# 201907?? - Fred Denis - Initial release
#
#

iblinkinfo --switches-only -l |\
         awk 'BEGIN\
                {             FS =      "\""                            			;
                # Some colors
                     COLOR_BEGIN =       "\033[1;"                      			;
                       COLOR_END =       "\033[m"                       			;
                             RED =       "31m"                          			;
                           GREEN =       "32m"                          			;
                          YELLOW =       "33m"                          			;
                            BLUE =       "34m"                          			;
                            TEAL =       "36m"                          			;
                           WHITE =       "37m"                          			;
                          NORMAL =        "0m"                          			;
                  BACK_LIGHTBLUE =      "104m"                          			;
                  RED_BACKGROUND =       "41m"                          			;

                # Columns size
                        COL_HOST =      8                               			;
                        COL_PORT =      8                               			;
                }
                #
                # A function to center the outputs with colors
                #
                function center( str, n, color, sep)
                {       right = int((n - length(str)) / 2)                                     	;
                      left  = n - length(str) - right                                           ;
                      return sprintf(COLOR_BEGIN color "%" left "s%s%" right "s" COLOR_END sep, "", str, "" )                 ;
                }
                #
                # A function that just print a "---" white line
                #
                function print_a_line(size)
                {
                       if ( ! size)
                       {       size = COL_DB+COL_VER+(COL_NODE*n)+COL_TYPE+n+3          	;
                       }
                       printf("%s", COLOR_BEGIN WHITE)                                  	;
                       for (k=1; k<=size; k++) {printf("%s", "-");}                     	;
                       printf("%s", COLOR_END"\n")                                      	;
                }
                {	# Cleaned the data from the output
                	split ($2, a, " ")                      				;
			ip      	=       a[length(a)]            			;       # IP switch
			name    	=       a[length(a)-1]          			;       # IB name
			if (length(name) > COL_HOST)
			{      COL_HOST = length(name)  					;	# Column size
			}

			sub(/\/ */, "/", $3)                    				;
			split ($3, a, " ")                      				;
			switches[name]	= id							;
			id      	= a[1]                    				;       # Switch ID
			port    	= a[2]                    				;       # Port
			sub(/\[/, "", port)                     				;
			if ($3 ~  /Down/)
			{       idk1    =       ""              				;
				idk2    =       ""              				;
			} else {
				idk1    =       a[length(a)-2]  				;
				idk2    =       a[length(a)-1]  				;
				sub(/\[/, "", idk2)             				;
			}

			sub(")==>.*$", "", $3)                  				;
			split($3, a, " ")                       				;
			status		=       a[length(a)]          				;       # Status

			sub("SUN DCS 36P QDR ", "", $4)         				;
			split ($4, a, " ")                      				;
			to      	=       a[1]                    			;       # Connected to
			sub(/\..*$/, "", to)                    				;       # Remove the domain

			info[id,port] = ip"|"name"|"id"|"port"|"status"|"to"|"idk1"|"idk2	;       
		} END\
		{	# Header
			nb		=	asorti(switches, switches_sorted)		;
			printf("\n")    							;
			printf("%s", center("Port", COL_PORT, WHITE, "|"))			;
			COL_SWITCH	=	COL_HOST+COL_PORT+3				;

			for (i=1; i<=nb; i++)
			{
				switch_id 	= 	switches[switches_sorted[i]]		;
				switch_name 	=	switches_sorted[i]    			;
				split(info[switch_id,1], a, "|")        			;
				printf("%s", center(a[2]" ("switch_id")", COL_SWITCH, WHITE, "|"));
			}
			printf("\n")    							;
			print_a_line(COL_PORT*(nb+1)+COL_HOST*nb+nb*4)				;

			for (j=1; j<=36; j++)							# Switches have 36 ports
			{
				for (i=1; i<=nb; i++)
				{
					switch_id       =       switches[switches_sorted[i]]    ;
					switch_name     =       switches_sorted[i]              ;

					split(info[switch_id,j], a, "|")			;
					COLOR		=	NORMAL				;
					if (a[5] ~  /Active/)
					{       COLOR	=	GREEN             		;
					}
					if (i == 1)                     # Print the port
					{       printf("%s", center(a[4], COL_PORT, WHITE, "|"));
					}
					if (a[7] != "")
					{       idk	=	"("a[7]"/"a[8]")"		;
					} else {
						idk	=	""        			;
					}
					printf(COLOR_BEGIN COLOR " %-"COL_HOST"s " COLOR_END, a[6] );
					printf(COLOR_BEGIN COLOR "%-"COL_PORT"s" COLOR_END " |", idk );

				}
				printf("\n")                                                    ;
			}
			print_a_line(COL_PORT*(nb+1)+COL_HOST*nb+nb*4)  			;
			printf("\n")                                                    	;
		}
		'

#********************************************************************************#
#*			E N D      O F      S O U R C E 			*#
#********************************************************************************#
