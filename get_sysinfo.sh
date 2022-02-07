#!/usr/bin/env bash
#
# Author: David Deng
# Url: https://covear.top
#

set -u

# Name of this tool
TOOL_NAME="get_sysinfo"

# Version of this tool
VERSION="2.1"

# Help of this tool
usage () {
    echo "$TOOL_NAME [options]"
    echo "Options:"
    echo "  -h, --help          Display this help and exit"
    echo "  -v, --version       Display version and exit"
    exit 0
}

# Program was terminated unexpectedly
fail () {
    echo "$TOOL_NAME: $1" >&2
    exit 1
}

# Get operating system version
get_opsy(){
    [ -f /etc/redhat-release ] && awk '{print ($1,$3~/^[0-9]/?$3:$4)}' /etc/redhat-release && return
    [ -f /etc/os-release ] && awk -F'[= "]' '/PRETTY_NAME/{print $3,$4,$5}' /etc/os-release && return
    [ -f /etc/lsb-release ] && awk -F'[="]+' '/DESCRIPTION/{print $2}' /etc/lsb-release && return
}

# Get IPv4 address of public Internet
get_ipv4_pub(){
    local IP=''
    IP=$( ip addr | egrep -o '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' | egrep -v "^192\.168|^172\.1[6-9]\.|^172\.2[0-9]\.|^172\.3[0-2]\.|^10\.|^127\.|^255\.|^0\." | head -n 1 )
    [ -z ${IP} ] && IP=$( wget -qO- -t1 -T2 ipv4.icanhazip.com )
	echo -n $IP
}

# Handle the command line arguments, if any.
while test $# -gt 0; do
    case "$1" in
        -h|--help) usage ;;
        -v|--version) echo "$TOOL_NAME $VERSION"; exit 0 ;;
        --) shift; break ;;
        *) fail "unrecognized option '$1'";;
    esac
done
test $# -gt 0 && fail "extra operand '$1'"

echo "########################################"
echo "##                                    ##"
echo "##       Get System Information       ##"
echo "##                                    ##"
echo "########################################"
echo 
echo "CPU model            : $( awk -F: '/model name/ {name=$2} END {print name}' /proc/cpuinfo | sed 's/^[ \t]*//;s/[ \t]*$//' )"
echo "Number of cores      : $( awk -F: '/model name/ {core++} END {print core}' /proc/cpuinfo )"
echo "CPU frequency        : $( awk -F: '/cpu MHz/ {freq=$2} END {print freq}' /proc/cpuinfo | sed 's/^[ \t]*//;s/[ \t]*$//' ) MHz"
echo "Total amount of ram  : $( free -m | awk '/Mem/ {print $2}' ) MB"
echo "Total amount of swap : $( free -m | awk '/Swap/ {print $2}' ) MB"
echo "System uptime        : $( awk '{a=$1/86400;b=($1%86400)/3600;c=($1%3600)/60;d=$1%60} {printf("%ddays, %d:%d:%d\n",a,b,c,d)}' /proc/uptime )"
echo "Load average         : $( w | head -1 | awk -F'load average:' '{print $2}' | sed 's/^[ \t]*//;s/[ \t]*$//' )"
echo "OS                   : $( get_opsy )"
echo "Architecture         : $( uname -m ) ($( getconf LONG_BIT ) Bit)"
echo "Kernel               : $( uname -r )"
echo "Hostname             : $( hostname )"
echo "Virtualization       : $( hostnamectl | awk '/Virtualization/ {print $2}' )"
echo -n "IPv4 address         : "
echo $( get_ipv4_pub )
echo
echo "########################################"
echo 
