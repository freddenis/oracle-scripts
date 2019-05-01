#!/bin/bash
#[root@goblxdex01db01 pythian]# dcli -g ~/cell_group -l root "echo celldisk; cellcli -e list celldisk attributes name,status,size,errorcount,disktype; echo BREAK; echo griddisk; cellcli -e list griddisk attributes asmDiskGroupName,name,asmmodestatus,asmdeactivationoutcome,size,errorcount,disktype; echo BREAK_CELL" > a

#goblxdex01cel01: CD_11_goblxdex01cel01   normal  2.7284698486328125T     0       HardDisk
#goblxdex01cel01: FD_00_goblxdex01cel01   normal  186.25G                 0       FlashDisk

#goblxdex01cel01: DATA            DATA_CD_00_goblxdex01cel01      ONLINE  Yes     2.6954193115234375T     0       HardDisk



IN=a

awk 'BEGIN {
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
        # Column size
                COL_CELL=20     ;
                COL_DISKTYPE=26 ;
                COL_NB=COL_DISKTYPE/3   ;
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
                                if ($4 == "ONLINE")
                                {
                                        tab2_status[cell,$2,$4]++       ;
                                }
                                tab2_err[cell,$2]+=$7           ;
                                tab2_nbdisks[cell,$2]++         ;       # Nb disks per diskgroup
                                tab2_dgs[$2]=$2                 ;       # Diskgroups
                        }
                }

        } END\
        {       #
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

                for (x in tab_cell)
                {
                        cell=tab_cell[x]        ;
                        printf ("%s", center(tab_cell[x], COL_CELL, WHITE, "|"))        ;
                        for (y in tab_status)
                        {       #print "=>"y    ;
                                split(y,sep,SUBSEP)             ;
                                if (sep[1] == cell)
                                {
                                        for (disktype in tab_disktype)
                                        {
                                                COLOR_ERROR=GREEN       ;
                                                COLOR_STATUS=GREEN      ;

                                                printf ("%s", center(tab_nbdisks[cell,disktype], COL_NB, WHITE, "|"))        ;

                                                if (tab_status[cell,disktype,sep[3]]<tab_nbdisks[cell,disktype]) { COLOR_STATUS=RED;}
                                                printf ("%s", center(tab_status[cell,disktype,sep[3]], COL_NB, COLOR_STATUS, "|"))        ;

                                                if (tab_err[tab_cell[x],disktype]>0)    { COLOR_ERROR=RED;      }
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
                printf("\n", "")        ;
                printf ("%s", center("Grid Disks", COL_CELL, TEAL, "|"))        ;
                for (dg in tab2_dgs)
                {
                        printf ("%s", center(dg, COL_DISKTYPE, WHITE, "|"))        ;
                }
                printf("\n")    ;

                printf ("%s", center(" ", COL_CELL, WHITE, "|"))        ;
                for (i=1; i<=length(tab2_dgs); i++)
                {       printf ("%s", center("Nb", COL_NB, WHITE, "|"))        ;
                        printf ("%s", center("Online", COL_NB, WHITE, "|"))        ;
                        printf ("%s", center("Errors", COL_NB, WHITE, "|"))        ;
                }
                printf("\n")    ;
                print_a_line(COL_CELL+COL_DISKTYPE*length(tab2_dgs)+length(tab2_dgs)+1) ;
                for (x in tab_cell)
                {
                        cell=tab_cell[x]        ;
                        printf ("%s", center(tab_cell[x], COL_CELL, WHITE, "|"))        ;
                        for (y in tab2_status)
                        {       #print "=>"y    ;
                                split(y,sep,SUBSEP)             ;
                                if (sep[1] == cell)
                                {
                                        for (dg in tab2_dgs)
                                        {
                                                COLOR_ERROR=GREEN       ;
                                                COLOR_STATUS=GREEN      ;

                                                printf ("%s", center(tab2_nbdisks[cell,dg], COL_NB, WHITE, "|"))        ;

                                                if (tab2_status[cell,dg,sep[3]]<tab2_nbdisks[cell,dg]) { COLOR_STATUS=RED;}
                                                printf ("%s", center(tab2_status[cell,dg,sep[3]], COL_NB, COLOR_STATUS, "|"))        ;

                                                if (tab2_err[tab_cell[x],dg]>0)    { COLOR_ERROR=RED;      }
                                                printf ("%s", center(tab2_err[cell,dg], COL_NB, COLOR_ERROR, "|"))        ;
                                        }
                                        break   ;
                                }
                        }
                        printf("\n")    ;
                }
                print_a_line(COL_CELL+COL_DISKTYPE*length(tab2_dgs)+length(tab2_dgs)+1) ;
                printf("\n")    ;
        }' $IN
