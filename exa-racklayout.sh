#!/bin/bash
# Fred Denis -- Jan 2019 -- http://unknowndba.blogspot.com -- fred.denis3@gmail.com
#
# Show what's on an Exadata based on the /opt/oracle.SupportTools/onecommand/databasemachine.xml file
# The output shows each Exadata component, their IP, ILOM and ILOM IP on the form of an Exadata Rack layout
#
# Please have a look at https://goo.gl/wv2z5m for more information on this script
#
# The current version of the script is 20190222
#
# 20190222 - Fred Denis - Option -s to not show the empty U slots
#			  Option -f to specify a non default databasemachine.xml file
# 20190128 - Fred Denis - Added PDUs
# 20190126 - Fred Denis - Some dbmachine files may not have the info in the same order -- fixed this
# 20190125 - Fred Denis - Moved Blue to Lightblue and Red to Lightred to have a more pastel output
# 20190124 - Fred Denis - Initial Release
#

#
# Variables
#
SHOW_EMPTY_U="YES"              # Set SHOW_EMPTY_U="NO" here to always not show the empty U by default
          IN=""			# If a file is specified with the -f option


#
# Function usage
#
usage()
{
printf "\033[1;37m%-8s\033[m\n" "NAME"                ;
cat << END
        `basename $0` - Show an Exadata Rack Layout based on the databasemachine.xml file
END

printf "\n\033[1;37m%-8s\033[m\n" "SYNOPSIS"            ;
cat << END
        $0 [-f] [-s] [-h]
END

printf "\n\033[1;37m%-8s\033[m\n" "OPTIONS"             ;
cat << END
	-f	Specify a non default databasemachine.xml file
			$0 -f /tmp/mydatabasemachine.xml
        -s      Show a short form of the Rack Layout by hiding the empty U slots
                You can set SHOW_EMPTY_U="NO" on top of the script to always show the short form
        -h      Show this help
END
printf "\n"
exit 123
}

#
# Options management
#
while getopts "shf:" OPT; do
        case ${OPT} in
        s)         SHOW_EMPTY_U="NO"                                                   ;;
	f)	             IN=${OPTARG}					       ;;
        h)         usage                                                               ;;
        \?)        echo "Invalid option: -$OPTARG" >&2; usage                          ;;
        esac
done

#
# The databasemachine.xml file we base our report on
#
if [[ -z "${IN}" ]]
then
	DBMACHINE=/opt/oracle.SupportTools/onecommand/databasemachine.xml
else
	DBMACHINE=${IN}
fi

if [ ! -f ${DBMACHINE} ] || [ ! -r ${DBMACHINE} ]
then
        cat << !
        The ${DBMACHINE} cannot be found or is not readable, cannot continue.
!
        exit 123
fi
printf "\n"

awk -v SHOW_EMPTY_U="$SHOW_EMPTY_U" 'BEGIN\
        {       FS="<|>"                                                                ;
                # some colors
             COLOR_BEGIN =       "\033[1;"                                              ;
               COLOR_END =       "\033[m"                                               ;
                # Foreground colors code
                   WHITE =       "37m"                                                  ;
                  NORMAL =       "0m"                                                   ;
                # Background colors code
                    BLUE =       "44m"                                                  ;
                    BLUE =       "104m"                                                 ;       # Lightblue
                   GREEN =       "42m"                                                  ;
                  YELLOW =       "43m"                                                  ;
                    GREY =       "100m"
                     RED =       "41m"                                                  ;
                     RED =       "101m"                                                 ;       # Lightred

                   COL_U =       3                                                      ;       # Size of the "U" column
        }
        #
        # A function to center the outputs with colors
        #
        function center( str, n, color, sep)
        {       right = int((n - length(str)) / 2)                                      ;
                left  = n - length(str) - right                                         ;
                return sprintf(COLOR_BEGIN color "%" left "s%s%" right "s" COLOR_END sep, "", str, "" )        ;
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
        {       if ($2 == "RACKS")
                {       while (getline)
                        {       if ($2 == "MACHINETYPES")       {MODEL=$3       ;}
                                if ($2 == "MACHINEUSIZE")       { NB_U=$3       ;}
                                if ($2 == "ITEMS")              {ITEMS=$3       ; break ;}
                        }
                }
                if ($2 ~ /ITEM ID/)
                {       ADMINNAME=""; ADMINIP=""; ILOMNAME=""; ILOMIP=""        ;
                        while (getline)
                        {       if ($2 == "TYPE")               {TYPE=$3        ;}
                                if ($2 == "ADMINNAME")          { ADMINNAME=$3  ; if (length($3) > MAX_COL1) {MAX_COL1 = length($3)}}
                                if ($2 == "ADMINIP")            {   ADMINIP=$3  ; if (length($3) > MAX_COL2) {MAX_COL2 = length($3)}}
                                if ($2 == "ILOMNAME")           {  ILOMNAME=$3  ; if (length($3) > MAX_COL3) {MAX_COL3 = length($3)}}
                                if ($2 == "ILOMIP")             {    ILOMIP=$3  ; if (length($3) > MAX_COL4) {MAX_COL4 = length($3)}}
                                if ($2 == "ULOCATION")          {ULOC=$3        ;}
                                if ($2 == "/ITEM")              {       if (TYPE == "pdu")
                                                                        {       if (tab[ULOC] == "")
                                                                                {       tab[ULOC]=TYPE";"ADMINNAME";"ADMINIP;
                                                                                } else {tab[ULOC]=tab[ULOC]";"ADMINNAME";"ADMINIP;
                                                                                }
                                                                        } else {        tab[ULOC]=TYPE";"ADMINNAME";"ADMINIP";"ILOMNAME";"ILOMIP ;   }
                                                                        break   ;
                                                                }
                        }
                }
        }
        END\
        {       # To have a space with the right table separator
                COL_U++                                                                 ;
                MAX_COL1++                                                              ;
                MAX_COL2++                                                              ;
                MAX_COL3++                                                              ;
                MAX_COL4++                                                              ;
                line_size=COL_U+MAX_COL1+MAX_COL2+MAX_COL3+MAX_COL4+10                  ;       # Size of the "---" lines

                printf("%s\n\n", center(MODEL, line_size, WHITE))                       ;

                #Header
                printf("%s|", center("U" ,  COL_U+1, WHITE))                            ;
                printf("%s|", center("Hostname", MAX_COL1+1, WHITE))                    ;
                printf("%s|", center("Host IP", MAX_COL2+1, WHITE))                     ;
                printf("%s|", center("ILOM name", MAX_COL3+1, WHITE))                   ;
                printf("%s|", center("ILOM IP", MAX_COL4+1, WHITE))                     ;
                printf "\n"     ;
                print_a_line(line_size)                                                 ;

                for (i=NB_U; i>=0; i--)
                {
                        split (tab[i], to_print, ";")                                   ;
                        ui="U"i ;

                        color=NORMAL                                                    ;
                        if (to_print[2] != "")
                        {
                                if (to_print[1] == "computenode") {color=BLUE}          ;
                                if (to_print[1] == "cellnode")    {color=RED}           ;
                                if (to_print[1] == "ib")          {color=YELLOW}        ;
                                if (to_print[1] == "cisco")       {color=GREEN}         ;
                                if (to_print[1] == "pdu")         {color=GREY}          ;
                        }
                        if (to_print[1] == "")
                        {
                                if (tab[i-1] ~ /cellnode/)
                                {       split(tab[i-1], temp, ";")                      ;
                                        if (temp[2] != "") {color=RED}                  ;
                                }
                        }
			#if ((to_print[2] != "") || (toupper(SHOW_EMPTY_U) == "YES"))
                        if ((to_print[2] != "") || (toupper(SHOW_EMPTY_U) == "YES") || ((temp[2] != "") && (tab[i-1] ~ /cellnode/)))
			{
                           printf(COLOR_BEGIN color "%s", "")                           ;
                           printf(" %-"COL_U"s|", ui);                                  ;       # U
                           printf(" %-"MAX_COL1"s|", to_print[2])                       ;       # Hostname
                           printf(" %-"MAX_COL2"s|", to_print[3])                       ;       # Host IP
                           if ((to_print[1] ~ /node/) || (to_print[1] == "pdu"))
                           {
                                   to_print_col3 = to_print[4]                          ;
                                   to_print_col4 = to_print[5]                          ;
                           } else {
                                   to_print_col3 = ""                                   ;
                                   to_print_col4 = ""                                   ;
                           }
                           printf(" %-"MAX_COL3"s|", to_print_col3)                     ;       # ILOM name
                           printf(" %-"MAX_COL4"s|", to_print_col4)                     ;       # ILOM IP
                           printf(COLOR_END "%s", "")                                   ;
                           printf "\n"                                                  ;
			}
                }
                print_a_line(line_size)                                                 ;
                printf "\n"                                                             ;

                # A legend to explain the colors
                printf("%s", "   ")     ;
                printf(COLOR_BEGIN BLUE"%s"COLOR_END, "Database Servers")               ;
                printf("%s", "   ")     ;
                printf(COLOR_BEGIN RED"%s"COLOR_END, "Storage Servers")                 ;
                printf("%s", "   ")     ;
                printf(COLOR_BEGIN YELLOW"%s"COLOR_END, "IB Switches")                  ;
                printf("%s", "   ")     ;
                printf(COLOR_BEGIN GREEN"%s"COLOR_END, "Cisco Switch")                  ;
                printf "\n\n"                                                           ;
        }
' ${DBMACHINE} | sed s'/^/  /'

#*********************************************************************************************************
#                               E N D     O F      S O U R C E
#*********************************************************************************************************
