#!/bin/bash
#################################################################################
# Script:       check_snmp_innovaphone_sip
# Author:       Michael Geschwinder (Maerkischer-Kreis)
# Description:  Plugin for Nagios to Monitor the state of innovaphone sip status via snmp
#
# Version:      1.0
#
# History:
# 20170807      Created plugin
#
#################################################################################################################
# Usage:        ./check_snmp_innovaphone_sip.sh -H host -C community -N Number [-D debug]
##################################################################################################################

help="check_snmp_innovaphone_sip (c) 2017 Michael Geschwinder published under GPL license
\nUsage: ./check_snmp_innovaphone_sip.sh -H host -C community -N Number [-D debug]
\nRequirements: snmp2csv-v1, awk, sed, grep\n
\nOptions: \t-H hostname\n\t\t-C Community (to be defined in snmp settings)\n\t\t-D enable Debug messages\n\t\t-N The phone number to check"

##########################################################
# Nagios exit codes and PATH
##########################################################
STATE_OK=0              # define the exit code if status is OK
STATE_WARNING=1         # define the exit code if status is Warning
STATE_CRITICAL=2        # define the exit code if status is Critical
STATE_UNKNOWN=3         # define the exit code if status is Unknown
PATH=$PATH:/usr/local/bin:/usr/bin:/bin:/usr/lib/nagios/plugins/custom: # Set path

##########################################################
# Debug Ausgabe aktivieren
##########################################################
DEBUG=0

##########################################################
# Debug output function
##########################################################
function debug_out {
        if [ $DEBUG -eq "1" ]
        then
                datestring=$(date +%d%m%Y-%H:%M:%S)
                echo -e $datestring DEBUG: $1
        fi
}

###########################################################
# Check if programm exist $1
###########################################################
function check_prog {
        if ! `which $1 1>/dev/null`
        then
                echo "UNKNOWN: $1 does not exist, please check if command exists and PATH is correct"
                exit ${STATE_UNKNOWN}
        else
                debug_out "OK: $1 does exist"
        fi
}

############################################################
# Check Script parameters and set dummy values if required
############################################################
function check_param {
        if [ ! $host ]
        then
                echo "No Host specified... exiting..."
                exit $STATE_UNKNOWN
        fi

        if [ ! $community ]
        then
                debug_out "Setting default community (public)"
                community="public"
        fi
        if [ ! $number ]
        then
                debug_out "Please specify number to check!"
                exit $STATE_UNKNOWN
        fi
}



############################################################
# Get SNMP Table
############################################################
function get_snmp_table {
        oid=$1
        snmpret=$(snmptable2csv-v1 $host --community=$community $oid)
        IFSold=$IFS
        IFS=$'\n'
        if [ $?  == 0 ]
        then
                for line in $snmpret
                do
                        echo $line
                done;
        else
                exit $STATE_UNKNOWN
        fi
        IFS=$IFSold
}

function check_ret
{
        if [ "$1" == "" ]
        then
                echo "No data received!"
                exit $STATE_UNKNOWN
        fi
}

#################################################################################
# Display Help screen
#################################################################################
if [ "${1}" = "--help" -o "${#}" = "0" ];
       then
       echo -e "${help}";
       exit $STATE_UNKNOWN;
fi

################################################################################
# check if requiered programs are installed
################################################################################
for cmd in snmptable2csv-v1 awk sed grep;do check_prog ${cmd};done;

################################################################################
# Get user-given variables
################################################################################
while getopts "H:C:N:D" Input;
do
       case ${Input} in
       H)      host=${OPTARG};;
       C)      community=${OPTARG};;
       N)      number=${OPTARG};;
       D)      DEBUG=1;;
       *)      echo "Wrong option given. Please use options --help for more information"
               exit 1
               ;;
       esac
done

debug_out "Host=$host, Community=$community"

check_param


ret=$(get_snmp_table .1.3.6.1.4.1.6666.2.1.1.1)
check_ret $ret
IFSold=$IFS
IFS=$'\n'


debug_out "looking for number $number"
for line in $ret
do
        debug_out "Trying line $line"
        data=$(echo $line | grep $number)

        if [ "$data" == "" ]
        then
                debug_out "No match trying next ...."
        else
                debug_out "Line matched! Writing return value"
                retval=$data
                debug_out "Exiting loop"
                break
        fi

done;

if [ ! $retval ]
then
        echo "No matching entry found. Check number!"
        exit $STATE_UNKNOWN
else
        ifgwname=$(echo $retval | cut -d "," -f1 | sed 's/\"//g')
        voiceifaddr=$(echo $retval | cut -d "," -f3 | sed 's/\"//g')
        voiceifstate=$(echo $retval | cut -d "," -f4 | sed 's/\"//g')
        voiceifnumber=$(echo $retval | cut -d "," -f5 | sed 's/\"//g')


        debug_out "$ifgwname $voiceifaddr $voiceifstate"

        if [ "$voiceifstate" == 1 ]
        then
                echo "Number $voiceifnumber is up! (ifname=$ifgwname ifaddress=$voiceifaddr)"
                exit $STATE_OK
        elif [ "$voiceifstate" == 0 ]
        then
                echo "Number $voiceifnumber is down! (ifname=$ifgwname ifaddress=$voiceifaddr)"
                exit $STATE_CRITICAL
        else
                echo "$number is in unknown state!"
                exit $STATE_UNKNOWN
        fi


fi
