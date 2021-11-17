#!/bin/bash
# Fred Denis -- May 31st 2021
# nfs-status.sh - list NFS status (healthy, hung, not mounted, in fstab or not)
# Copyright (C) 2021 Fred Denis
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <https://www.gnu.org/licenses/>.
#
#
# More info and git repo: https://github.com/freddenis/oracle-scripts
#
# The current script version is 20211117
#
# History :
#
# 20211117 - Fred Denis - Fixed the tput error when the script is executed on many hosts with dcli for example
# 20211111 - Fred Denis - GPLv3 licence
# 20210531 - Fred Denis - Initial release
#
set -o pipefail
#
# Variables
#
     TS="date "+%Y-%m-%d_%H%M%S""      # A timestamp for a nice outut in a logfile
     declare -A    tab_nfs             # Mounted NFS
     declare -A    tab_fstab           # NFS defined in fstab
     declare -A    all_nfs             # All the NFS (mounted + fstab)
     declare -i    nb_hung=0           # An integer to count how many NFS are hung
     declare -i     col_fs=0           # An integer for the FS column size
     declare -i  col_mount=0           # An integer for the mount column size
     declare -i col_status=11          # An integer for the mount column size
     declare -i  col_fstab=8           # An integer for is in fstab or not column
     SHOW="False"                      # Show the umount command for the hung NFS ? (-s/--show)
   UMOUNT="False"                      # Umount the NFS ? (-u/--umount)
   PMOUNT="False"                      # Mount the umounted NFS ? (-m/--mount)
   PURPLE=35
      RED=31
    GREEN=32
     BLUE=34
[[ $(id -u) == "0" ]] && IAMROOT="True" || IAMROOT="False"
# If UTF8, we show a nice checkmark when NFS is in fstab, if not we just write "yes/no"
if [[ $(locale charmap) == "UTF-8" ]]; then
    CHECKMARK="\xE2\x9C\x94"
      C_RIGHT=3
      BADMARK="xxx"
      B_RIGHT=2
else
    CHECKMARK="yes"
      C_RIGHT=1
      BADMARK=" no"
      B_RIGHT=2
fi
# fstab -- same on all Unix except Solaris; use -f/--fstab for other locations
FSTAB="/etc/fstab"
if [[ $(uname) == "SunOS" ]]; then
    FSTAB="/etc/vfstab"
fi
# To avoid a bad error when the script is executed on many hosts with dcli for example
if [[ -z "${TERM}" || "${TERM}" == "dumb" ]]; then export TERM="xterm"; fi
#
# Just print a "-" line
#
print_a_line() {
    for i in $(seq 1 $1); do
        printf "\033[1;37m%s\033[m" "-"
    done
    printf "\n"
}
#
# Usage function
#
usage() {
    printf "\n\033[1;37m%-8s\033[m\n" "NAME"                ;
    cat << END
        $(basename $0) - show a status of the NFS (hung, healthy, not mounted, not in fstab, etc ...)
END

    printf "\n\033[1;37m%-8s\033[m\n" "SYNOPSIS"            ;
    cat << END
        $0 <options [-s]     [-m]      [-u]       [-f]      [-h]
        $0 <options [--show] [--mount] [--umount] [--fstab] [--help]
END

    printf "\n\033[1;37m%-8s\033[m\n" "DESCRIPTION"            ;
    cat << END
        $(basename $0) - Show a status of the NFS (hung / healthy)
        Also show if a NFS defined in ${FSTAB} is not mounted and if a mounted NFS is in ${FSTAB} or not
        In case of non root users using this script and being unable to read ${FSTAB}, a "n/a" will be printed in the status column
        /etc/fstab is used and /etc/vfstab for Solaris; please use -f/--fstab to use a fstab at another location
END

    printf "\n\033[1;37m%-8s\033[m\n" "OPTIONS"            ;
    cat << END
        -s | --show  ) Show the umount commands to umount the hung NFS
        -m | --mount ) Mount the unmounted NFS
        -u | --umount) Umount the hung NFS
        -f | --fstab ) For non standard fstab, default is: ${FSTAB}
        -h | --help  ) Shows this help
END

    printf "\n\033[1;37m%-8s\033[m\n" "EXAMPLES"            ;
    cat << END
        ./nfs-status.sh                     # Show the NFS status
        ./nfs-status.sh --show              # Also show the umount commands to umount the hung NFS
        ./nfs-status.sh --umount            # Umount the hung NFS
        ./nfs-status.sh --mount             # Mount the umounted NFS
        ./nfs-status.sh --mount --umount    # Mount the umounted NFS + Umount the hung NFS

END
exit 999
}
#
# Options
#
SHORT="u,m,s,f:,y"
 LONG="umount,mount,show,fstab:,help,yes"
#
options=$(getopt -a --longoptions "${LONG}" --options "${SHORT}" -n "$0" -- "$@")
#
if [[ $? -ne 0 ]]; then
    printf "\033[1;31m%s\033[m\n" "$($TS) [ERROR] Invalid options provided: $*; use -h for help; cannot continue." >&2
    exit 864
fi
#
eval set -- "${options}"
#
while true; do
    case "$1" in
        -s | --show     )   SHOW="True"            ; shift   ;;
        -m | --mount    ) PMOUNT="True"            ; shift   ;;
        -u | --umount   ) UMOUNT="True"            ; shift   ;;
        -f | --fstab    )  FSTAB="$2"              ; shift 2 ;;
        -h | --help     ) usage                    ; shift   ;;
        --              ) shift                    ; break   ;;
    esac
done
#
# Get the NFS defined in fstab -- if possible
#
if [[ -r "${FSTAB}" ]]; then
    for X in $(cat /etc/fstab | grep -v "^#" | grep -v "^$" | grep nfs | awk '{print $1"|"$2}' | sort | uniq); do
           FS=$(echo ${X} | awk -F "|" '{print $1}')
        MOUNT=$(echo ${X} | awk -F "|" '{print $2}')
        tab_fstab[${X}]="${X}"
          all_nfs[${X}]="${X}"
        if (( ${#FS}    >    $col_fs )); then    col_fs=${#FS}   ; fi
        if (( ${#MOUNT} > $col_mount )); then col_mount=${#MOUNT}; fi
    done
    SHOWFSTAB="True"
else
    SHOWFSTAB="False"       # We cannot read fstab so we ignore it (then non root users can use the script as well just without this feature)
fi
#
# Get the infos about hung/healthy NFS
#
for NFS in $(mount -t nfs | awk '{print $1"|"$3}' | sort); do
       FS=$(echo ${NFS} | awk -F "|" '{print $1}')
    MOUNT=$(echo ${NFS} | awk -F "|" '{print $2}')
    printf "%-60s" "Checking ${MOUNT} . . ."
    tput hpa 0
    read -t1 < <(stat -t "${MOUNT}" 2>&-)
    if [[ $? -ne 0 ]]; then
        ((nb_hung++))
        tab_nfs[${NFS}]="Hung"
    else
        tab_nfs[${NFS}]="Healthy"
    fi
    all_nfs[${NFS}]="${NFS}" ;
    if (( ${#FS}    >    $col_fs )); then    col_fs=${#FS}   ; fi
    if (( ${#MOUNT} > $col_mount )); then col_mount=${#MOUNT}; fi
done
#
# Make a nice table with infos collected above
#
line_size=$(( col_fs+col_mount+col_status+col_fstab+13 ))
# Header
print_a_line ${line_size}
printf " %-${col_mount}s |"  "Mount Point"
printf " %-${col_fs}s |"     "NFS"
printf " %-${col_status}s  |" "Status"
printf " %-${col_fstab}s  |" "in fstab"
printf "\n"
print_a_line ${line_size}
# Add the not mounted status here in a dedicated loop as the next one making the table body is executed into () so in a subshell
# and then the show mount commands would not work
for X in ${!all_nfs[@]}; do
    if [[ -z "${tab_nfs[${X}]}" ]]          ; then STATUS_COLOR="${PURPLE}"; tab_nfs[${X}]="Not Mounted";  fi
done
# Table body
(for X in ${!all_nfs[@]}; do
    if [[ "${tab_nfs[${X}]}" == "Not Mounted" ]]; then STATUS_COLOR="${PURPLE}" ; fi
    if [[ "${tab_nfs[${X}]}" == "Healthy" ]]    ; then STATUS_COLOR="${GREEN}" ; fi
    if [[ "${tab_nfs[${X}]}" == "Hung" ]]       ; then STATUS_COLOR="${RED}"   ; fi
       FS=$(echo ${X} | awk -F "|" '{print $1}')
    MOUNT=$(echo ${X} | awk -F "|" '{print $2}')

    printf " %-${col_mount}s |"  "${MOUNT}"
    printf " %-${col_fs}s |"     "${FS}"
    printf "\033[1;${STATUS_COLOR}m %-${col_status}s \033[m |" "${tab_nfs[${X}]}"
    if [[ "${SHOWFSTAB}" == "True" ]]; then
        if [[ -z "${tab_fstab[${X}]}" ]]; then       # Not in fstab
            printf "\033[1;${RED}m    ${BADMARK} %-${B_RIGHT}s\033[m |"
        else                                         # In fstab
            printf "\033[1;${GREEN}m     ${CHECKMARK} %-${C_RIGHT}s\033[m |"
        fi
    else   # We were unable to read fstab
        printf "\033[1;${BLUE}m    %-4s  \033[m |" "n/a"
    fi
    printf "\n"
done) | sort
# Footer
print_a_line ${line_size}
#
# If we have found hung NFS, show how to umount them
#
if (( ${nb_hung} > 0 )); then
    printf "%s\n\n" "Hung NFS can be umount using: umount -f -l <mountpoint>; use --show to generate the umount commands"
fi
#
# Show the NFS commands to umount the hung NFS ?
#
if [[ "${SHOW}" == "True" ]]; then
    (for X in ${!all_nfs[@]}; do
        MOUNT=$(echo ${X} | awk -F "|" '{print $2}')
        if [[ "${tab_nfs[${X}]}" == "Hung" ]]; then
            printf "%s\n" "umount -f -l ${MOUNT}"
        fi
        if [[ "${tab_nfs[${X}]}" == "Not Mounted" ]]; then
            printf "%s\n" "mount ${MOUNT}"
        fi
    done) | sort
fi
#
# Automatically umount the hung NFS ?
#
if [[ "${UMOUNT}" == "True" ]]; then
    if [[ "${IAMROOT}" == "True" ]]; then
        for X in ${!all_nfs[@]}; do
            MOUNT=$(echo ${X} | awk -F "|" '{print $2}')
            if [[ "${tab_nfs[${X}]}" == "Hung" ]]; then
                printf "%-60s" "Umounting ${MOUNT} . . ."
                tput hpa 0
                printf "%s\n" "umount -f -l ${MOUNT}" | bash
            fi
        done
    else
        printf "\033[1;33m%s\033[m\n" "$($TS) [WARNING] Only root can umount the NFS, skipping." ;>&2
    fi
fi
#
# Automatically mount the umounted NFS ?
#
if [[ "${PMOUNT}" == "True" ]]; then
    if [[ "${IAMROOT}" == "True" ]]; then
        for X in ${!all_nfs[@]}; do
            MOUNT=$(echo ${X} | awk -F "|" '{print $2}')
            if [[ "${tab_nfs[${X}]}" == "Not Mounted" ]]; then
                printf "%-60s" "Mounting ${MOUNT} . . ."
                tput hpa 0
                printf "%s\n" "mount ${MOUNT}" | bash
            fi
        done
    else
        printf "\033[1;33m%s\033[m\n" "$($TS) [WARNING] Only root can mount the NFS, skipping." ;>&2
    fi
fi
#
# Exit with number of hung NFS
#
exit "${nb_hung}"

