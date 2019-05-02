#!/bin/bash
# Fred Denis -- May 2019 -- http://unknowndba.blogspot.com -- fred.denis3@gmail.com

## dcli -g ~/cell_group -l root "echo celldisk; cellcli -e list celldisk attributes name,status,size,errorcount,disktype; echo BREAK; echo griddisk; cellcli -e list griddisk attributes asmDiskGroupName,name,asmmodestatus,asmdeactivationoutcome,size,errorcount,disktype; echo BREAK_CELL" > a

# Variables
#
        NB_PER_LINE=$(bc <<< "`tput cols`/30")          # Number of DG to show per line,  can be changed with -n option
                TMP=/tmp/cell-status$$.tmp              # A tempfile
               TMP2=/tmp/cell-status2$$.tmp             # A tempfile

#
# An usage function
#
usage()
{
printf "\n\033[1;37m%-8s\033[m\n" "NAME"                ;
cat << END
        `basename $0` - A nice overview of the status of the disks on the Exadata cells
END
exit 123
}

# Options
while getopts "ho:f:n:" OPT; do
        case ${OPT} in
        o)         OUT=${OPTARG}                                                                ;;
        f)          IN=${OPTARG}                                                                ;;
        n) NB_PER_LINE=${OPTARG}                                                                ;;
        h)         usage                                                                        ;;
        \?)        echo "Invalid option: -$OPTARG" >&2; usage                                   ;;
        esac
done

if [[ -z ${IN} ]]       # No input file specified, we dynamically find the info from the cells
then
        ibhosts | sed s'/"//' | grep cel | awk '{print $6}' | sort > ${TMP2}    # list of cells
        dcli -g ${TMP2} -l root "echo celldisk; cellcli -e list celldisk attributes name,status,size,errorcount,disktype; echo BREAK; echo griddisk; cellcli -e list griddisk attributes asmDiskGroupName,name,asmmodestatus,asmdeactivationoutcome,size,errorcount,disktype; echo BREAK_CELL" > ${TMP}
        IN=${TMP}
fi

if [[ ! -f ${IN} ]]
then
        cat << !
        Cannot find the file ${IN}; cannot continue.
!
exit 123
fi
#IN=a

awk -v nb_per_line="$NB_PER_LINE" 'BEGIN\
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
          RED_BACKGROUND =       "41m"                          ;
        # Column size
                COL_CELL =      20                              ;
            COL_DISKTYPE =      26                              ;
                  COL_NB =      COL_DISKTYPE/3                  ;
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
        {       sub (":", "", $1)                               ;
                if ($2 == "celldisk")
                {
                        cell = $1                               ;
                        tab_cell[cell] = cell                   ;
                        while (getline)
                        {
                                if ($2 == "BREAK")
                                {
                                        break                   ;
                                }
                                if ($3 == "normal")
                                {
                                        tab_status[cell,$6,$3]++        ;
                                }
                                tab_err[cell,$6]+=$5            ;
                                tab_nbdisks[cell,$6]++          ;
                                tab_disktype[$6]=$6     ;
                        }
                }       # End                 if ($2 == "celldisk")
                if ($2 == "griddisk")
                {       cell = $1                               ;
                        while(getline)
                        {
                                if ($2 == "BREAK_CELL")
                                {
                                        break                   ;
                                }
                                if ($3 != "UNUSED")             # Unused disks have no DG
                                {
                                        tab2_err[cell,$2]+=$7           ;
                                        tab2_nbdisks[cell,$2]++         ;       # Nb disks per diskgroup
                                        tab2_dgs[$2]=$2                 ;       # Diskgroups
                                        if (tolower($5) != "yes")               # asmDeactivationOutcome
                                        {       tab2_deact[cell,$2]="no"        ;
                                        }
                                        if ($4 == "ONLINE")
                                        {
                                                tab2_status[cell,$2]++  ;       # cell,DG
                                        }       else {
                                                tab2_bad[cell,$2]++  ;          # bad status disks
                                        }
                                }
                        }
                }

        }
        function print_blue_hyphen(size, sep)
        {
                printf ("%s", center("--", size, BLUE, sep))        ;           # Just print a blue "--"
        }
        function print_red_cross(size, sep)
        {
                printf ("%s", center("xx", size, COLOR_STATUS, sep))    ;       # Just print a red "xx"
        }
        function print_griddisk_header(i)
        {
                printed=0       ;
                printf("\n", "")        ;
                printf ("%s", center("Grid Disks", COL_CELL, TEAL, "|"))        ;

                for (j=i; j<i+nb_per_line; j++)
                {
                        dg=dgs_sorted[j]        ;       # To ease the naming below

                        if (j > nb_dgs)         # Everything is printed so we stop even if line is not full
                        {       break   ;
                        }
                        printf ("%s", center(dg, COL_DISKTYPE, WHITE, "|"))        ;
                }
                printf("\n")    ;
                printf ("%s", center(" ", COL_CELL, WHITE, "|"))        ;

                for (j=i; j<i+nb_per_line; j++)
                {
                        if (j > nb_dgs)         # Everything is printed so we stop even if line is not full
                        {       break   ;
                        }
                        printf ("%s", center("Nb", COL_NB, WHITE, "|"))        ;
                        printf ("%s", center("Online", COL_NB, WHITE, "|"))        ;
                        printf ("%s", center("Errors", COL_NB, WHITE, "|"))        ;
                        printed++               ;
                }
                printf("\n")    ;
                print_a_line(COL_CELL+COL_DISKTYPE*printed+printed+1) ;
        }
        END\
        {       # Sort the arrays
                nb_cells=asort(tab_cell, tab_cell_sorted)                       ;
                #
                # CELL DISKS
                #
                # Disk Types
                printf("\n", "")        ;
                printf ("%s", center("Cell Disks", COL_CELL, TEAL, "|"))        ;
                for (disktype in tab_disktype)
                {
                        printf ("%s", center(disktype, COL_DISKTYPE, WHITE, "|"))        ;
                }
                printf("\n")    ;

                printf ("%s", center(" ", COL_CELL, WHITE, "|"))        ;
                printf ("%s", center("Nb", COL_NB, WHITE, "|"))        ;
                printf ("%s", center("Normal", COL_NB, WHITE, "|"))        ;
                printf ("%s", center("Errors", COL_NB, WHITE, "|"))        ;
                printf ("%s", center("Nb", COL_NB, WHITE, "|"))        ;
                printf ("%s", center("Normal", COL_NB, WHITE, "|"))        ;
                printf ("%s", center("Errors", COL_NB, WHITE, "|"))        ;
                printf("\n")    ;
                print_a_line(COL_CELL+COL_DISKTYPE*2+3) ;

                #for (x in tab_cell)
                for (x=1; x<=nb_cells; x++)
                {
                        cell=tab_cell_sorted[x] ;
                        printf ("%s", center(cell, COL_CELL, WHITE, "|"))        ;
                        for (y in tab_status)
                        {       #print "=>"y    ;
                                split(y,sep,SUBSEP)             ;
                                if (sep[1] == cell)
                                {
                                        for (disktype in tab_disktype)
                                        {
                                                COLOR_ERROR=GREEN       ;
                                                COLOR_STATUS=GREEN      ;

                                                # Nb disks
                                                printf ("%s", center(tab_nbdisks[cell,disktype], COL_NB, WHITE, "|"))        ;

                                                # Disks status
                                                if (tab_status[cell,disktype,sep[3]]<tab_nbdisks[cell,disktype]) { COLOR_STATUS=RED;}
                                                printf ("%s", center(tab_status[cell,disktype,sep[3]], COL_NB, COLOR_STATUS, "|"))        ;

                                                # Number of error
                                                if (tab_err[cell,disktype]>0)   { COLOR_ERROR=RED;      }
                                                printf ("%s", center(tab_err[cell,disktype], COL_NB, COLOR_ERROR, "|"))        ;
                                        }
                                        break   ;
                                }
                        }
                        printf("\n")    ;
                }
                print_a_line(COL_CELL+COL_DISKTYPE*2+3) ;
                printf("\n")    ;

                #
                # GRID DISKS
                #
                nb_dgs=asort(tab2_dgs, dgs_sorted)      ;
                #for (i=1; i<=nb_dgs; i++)
                #{      print "dg:" dgs_sorted[i]       ;
                #}

        for (i=1; i<=nb_dgs; i+=nb_per_line)
        {
                print_griddisk_header(i)        ;
                #for (x in tab_cell)
                for (x=1; x<=nb_cells; x++)
                {
                        cell=tab_cell_sorted[x]        ;        # To ease the naming below
                        nb_printed=0    ;
                        printf ("%s", center(cell, COL_CELL, WHITE, "|"))        ;
                        for (k=i; k<i+nb_per_line; k++)
                        {
                                if (k > nb_dgs)         # Everything is printed so we stop even if line is not full
                                {       break   ;
                                }
                                dg=dgs_sorted[k]        ;       # To ease the naming below

                                if (tab2_deact[cell,dg])        # asmdeactivationoutcome is NOT yes
                                {
                                        COLOR_ERROR=RED_BACKGROUND      ;
                                       COLOR_STATUS=RED_BACKGROUND      ;
                                        COLOR_STATUS_BAD=RED_BACKGROUND             ;
                                      COLOR_NB_DISKS=RED_BACKGROUND     ;
                                } else {
                                 COLOR_ERROR=GREEN                      ;
                                COLOR_STATUS=GREEN                     ;
                                COLOR_STATUS_BAD=RED                     ;
                                COLOR_NB_DISKS=WHITE                    ;
                                }

                                if (tab2_nbdisks[cell,dg])
                                {       printf ("%s", center(tab2_nbdisks[cell,dg], COL_NB, COLOR_NB_DISKS, "|"))        ;      # NB disks
                                } else {
                                        print_blue_hyphen(COL_NB, "|")  ;
                                }

                                if (tab2_status[cell,dg]<tab2_nbdisks[cell,dg]) { COLOR_STATUS=COLOR_STATUS_BAD;}
                                if (tab2_bad[cell,dg] > 0)
                                {       print_red_cross(COL_NB, "|")                    ;
                                } else {
                                        if (tab2_status[cell,dg])
                                        {       printf ("%s", center(tab2_status[cell,dg], COL_NB, COLOR_STATUS, "|"))        ; # Nb disks with ONLINE status
                                        } else {
                                                print_blue_hyphen(COL_NB, "|")     ;
                                        }
                                }

                                if (tab2_err[cell,dg]>0)    { COLOR_ERROR=RED;      }
#                               printf ("%s", center(tab2_err[cell,dg], COL_NB, COLOR_ERROR, "|"))        ;     # NB err
                                if (tab2_err[cell,dg] != "")
                                {       printf ("%s", center(tab2_err[cell,dg], COL_NB, COLOR_ERROR, "|"))        ;     # NB errors
                                } else {
                                        print_blue_hyphen(COL_NB, "|")     ;
                                }
                                nb_printed++    ;
                        }
                        printf("\n")    ;
                }
                print_a_line(COL_CELL+COL_DISKTYPE*nb_printed+nb_printed+1) ;
                printf("\n")    ;
        }       # End         for (i=1; i<=nb_dgs; i++)
        # Legend
        printf(COLOR_BEGIN BLUE " %-"3"s" COLOR_END, "--");
        printf(COLOR_BEGIN WHITE " %-"12"s |" COLOR_END, ": Unused disks");
#       printf("\n")    ;
        printf(COLOR_BEGIN RED " %-"3"s" COLOR_END, "xx");
        printf(COLOR_BEGIN WHITE " %-"20"s |" COLOR_END, ": Not ONLINE disks");
#       printf("\n")    ;
        printf(COLOR_BEGIN RED_BACKGROUND " %-"3"s" COLOR_END, "  ");
        printf(COLOR_BEGIN WHITE " %-"20"s" COLOR_END, ": asmDeactivationOutcome is NOT yes");
        printf("\n")    ;
        printf("\n")    ;
        }' $IN


for F in ${TMP} ${TMP2}
do
        if [[ -f ${F} ]]
        then
                rm -f ${F}
                #echo $F
        fi
done

#****************************************************************#
#               E N D      O F       S O U R C E                *#
#****************************************************************#
