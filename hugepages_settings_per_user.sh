#!/bin/bash
#
# hugepages_settings.sh
#
# Linux bash script to compute values for the
# recommended HugePages/HugeTLB configuration
# on Oracle Linux
#
# Note: This script does calculation for all shared memory
# segments available when the script is run, no matter it
# is an Oracle RDBMS shared memory segment or not.
#
# This script is provided by Doc ID 401749.1 from My Oracle Support
# http://support.oracle.com

# Welcome text
echo "
This script is provided by Doc ID 401749.1 from My Oracle Support
(http://support.oracle.com) where it is intended to compute values for
the recommended HugePages/HugeTLB configuration for the current shared
memory segments on Oracle Linux. Before proceeding with the execution please note following:
 * For ASM instance, it needs to configure ASMM instead of AMM.
 * The 'pga_aggregate_target' is outside the SGA and
   you should accommodate this while calculating SGA size.
 * In case you changes the DB SGA size,
   as the new SGA will not fit in the previous HugePages configuration,
   it had better disable the whole HugePages,
   start the DB with new SGA size and run the script again.
And make sure that:
 * Oracle Database instance(s) are up and running
 * Oracle Database 11g Automatic Memory Management (AMM) is not setup
   (See Doc ID 749851.1)
 * The shared memory segments can be listed by command:
     # ipcs -m


Press Enter to proceed..."

read

# Check for the kernel version
KERN=`uname -r | awk -F. '{ printf("%d.%d\n",$1,$2); }'`

# Find out the HugePage size
HPG_SZ=`grep Hugepagesize /proc/meminfo | awk '{print $2}'`
if [ -z "$HPG_SZ" ];then
    echo "The hugepages may not be supported in the system where the script is being executed."
    exit 1
fi

# Initialize the counter
NUM_PG=0

# Start Original code
## Cumulative number of pages required to handle the running shared memory segments
#for SEG_BYTES in `ipcs -m | cut -c44-300 | awk '{print $1}' | grep "[0-9][0-9]*"`
#do
#    MIN_PG=`echo "$SEG_BYTES/($HPG_SZ*1024)" | bc -q`
#    if [ $MIN_PG -gt 0 ]; then
#        NUM_PG=`echo "$NUM_PG+$MIN_PG+1" | bc -q`
#    fi
#done
# End Original code

# Start Fred
declare -A an_array
# Cumulative number of pages required to handle the running shared memory segments
for X in `ipcs -m | awk '{print $3"|"$5}' | grep "[0-9][0-9]*"`
do
        OWNER=`echo ${X} | awk -F "|" '{print $1}'`
    SEG_BYTES=`echo ${X} | awk -F "|" '{print $2}'`
    MIN_PG=`echo "$SEG_BYTES/($HPG_SZ*1024)" | bc -q`
    if [ $MIN_PG -gt 0 ]; then
        NUM_PG=`echo "$NUM_PG+$MIN_PG+1" | bc -q`
        ((an_array[$OWNER] += $MIN_PG+1  ))
    fi
done

printf "\t%10s\t|%15s\t|%15s\n" "Owner" "Nb Huge Pages" "Size in GB"
printf "\t%10s\t|%15s\t|%15s\n" "--------" "--------" "--------"
for Y in "${!an_array[@]}"
do
        printf "\t%10s\t|%15s\t|%15s\n" $Y ${an_array[$Y]} `echo "${an_array[$Y]} * $HPG_SZ / 1024 / 1024" | bc -q`
        (( sum_pages += ${an_array[$Y]} ))
        ((    sum_gb += `echo "${an_array[$Y]} * $HPG_SZ / 1024 / 1024" | bc -q` ))
done
printf "\t%10s\t|%15s\t|%15s\n" "--------" "--------" "--------"
printf "\t%10s\t|%15s\t|%15s\n" "Total" $sum_pages $sum_gb
printf "\n"
# End Fred

RES_BYTES=`echo "$NUM_PG * $HPG_SZ * 1024" | bc -q`

# An SGA less than 100MB does not make sense
# Bail out if that is the case
if [ $RES_BYTES -lt 100000000 ]; then
    echo "***********"
    echo "** ERROR **"
    echo "***********"
    echo "Sorry! There are not enough total of shared memory segments allocated for
HugePages configuration. HugePages can only be used for shared memory segments
that you can list by command:

    # ipcs -m

of a size that can match an Oracle Database SGA. Please make sure that:
 * Oracle Database instance is up and running
 * Oracle Database 11g Automatic Memory Management (AMM) is not configured"
    exit 1
fi

# Finish with results
case $KERN in
    '2.2') echo "Kernel version $KERN is not supported. Exiting." ;;
    '2.4') HUGETLB_POOL=`echo "$NUM_PG*$HPG_SZ/1024" | bc -q`;
           echo "Recommended setting: vm.hugetlb_pool = $HUGETLB_POOL" ;;
    '2.6') echo "Recommended setting: vm.nr_hugepages = $NUM_PG" ;;
    '3.8') echo "Recommended setting: vm.nr_hugepages = $NUM_PG" ;;
    '3.10') echo "Recommended setting: vm.nr_hugepages = $NUM_PG" ;;
    '4.1') echo "Recommended setting: vm.nr_hugepages = $NUM_PG" ;;
esac

# End
