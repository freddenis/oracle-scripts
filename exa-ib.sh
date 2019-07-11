#!/bin/bash
# Fred Denis -- July 2019
#
#


iblinkinfo --switches-only -l |\
	 awk 'BEGIN\
		{             FS =	"\""				;
			      nb =	0				;
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
		  RED_BACKGROUND =       "41m"                          ;

		# Columns size
		      COL_SWITCH = 	20				;
			COL_PORT = 	6				;
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
		       {       size = COL_DB+COL_VER+(COL_NODE*n)+COL_TYPE+n+3                  ;
		       }
		       printf("%s", COLOR_BEGIN WHITE)                                          ;
		       for (k=1; k<=size; k++) {printf("%s", "-");}                             ;
		       printf("%s", COLOR_END"\n")                                              ;
		}
	     {	# Cleaned the data from the output
		split ($2, a, " ")			;
		ip	=	a[length(a)]		;	# IP switch
		name	=	a[length(a)-1]		;	# IP name

		sub(/\/ */, "/", $3)			;
		split ($3, a, " ")			;
		id	=	a[1]			;	# Switch ID
		if (id > nb)	{ nb = id}		;	# Number of switches
		port	=	a[2]			;	# Port
		sub(/\[/, "", port)			;
		if ($3 ~  /Down/)
		{	idk1	=	""		;
		 	idk2	=	""		;
		} else {
			idk1	=	a[length(a)-2]	;
			idk2	=	a[length(a)-1]	;
			sub(/\[/, "", idk2)		;
		}

		sub(")==>.*$", "", $3)			;
		split($3, a, " ")			;
		status	=	a[length(a)]    	;	# Status

		sub("SUN DCS 36P QDR ", "", $4)		;	
		split ($4, a, " ")			;	
		to	=	a[1]			;	# Connected to
		sub(/\..*$/, "", to)			;	# Remove the domain
		
		info[id,port] = ip"|"name"|"id"|"port"|"status"|"to"|"idk1"|"idk2	;
	     } END\
	     {	
		# Header
		printf("\n")	;
		printf("%s", center("Port", COL_PORT, WHITE, "|"))
		for (i=1; i<=nb; i++)
		{
			split(info[i,1], a, "|")	;
			printf("%s", center(a[2]" ("i")", COL_SWITCH, WHITE, "|"))
		}
		printf("\n")	;
		print_a_line(COL_PORT+COL_SWITCH*nb+nb+1)	;

		for (j=1; j<=36; j++)
		{		
			for (i=1; i<=nb; i++)
			{	
				split(info[i,j], a, "|")	;
				COLOR=NORMAL		;
				if (a[5] ~  /Active/)
				{	COLOR=GREEN		;
				}
				if (i == 1)			# Print the port
				{	printf("%s", center(a[4], COL_PORT, WHITE, "|"))	;
				}
				if (a[7] != "")
				{	idk = "("a[7]"/"a[8]")"
				} else {
					idk = ""	;
				}
				printf("%s", center(a[6]" "idk, COL_SWITCH, COLOR, "|"))		;
			
			}
			printf("\n")							;
		}
		print_a_line(COL_PORT+COL_SWITCH*nb+nb+1)	;
		printf("\n")							;
	     }
	     '
