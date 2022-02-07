#!/usr/bin/env bash
#
# Author: David Deng
# Url: https://covear.top

set -u

# Name of this tool
TOOL_NAME="get_sysinfo"

# Version of this tool
VERSION="3.5"

# Help of this tool
usage () {
    echo "$TOOL_NAME [options]"
    echo "Options:"
    echo "  -h, --help          Display this help and exit"
    echo "  -v, --version       Display version and exit"
    echo "  -c, --zhcn          Display information with Chinese"
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

# Get system information
get_sysinfo(){
    cname=$( awk -F: '/model name/ {name=$2} END {print name}' /proc/cpuinfo | sed 's/^[ \t]*//;s/[ \t]*$//' )
    cores=$( awk -F: '/model name/ {core++} END {print core}' /proc/cpuinfo )
    freq=$( awk -F: '/cpu MHz/ {freq=$2} END {print freq}' /proc/cpuinfo | sed 's/^[ \t]*//;s/[ \t]*$//' )
    tram=$( free -m | awk '/Mem/ {print $2}' )
    swap=$( free -m | awk '/Swap/ {print $2}' )
    up=$( awk '{a=$1/86400;b=($1%86400)/3600;c=($1%3600)/60;d=$1%60} {printf("%ddays, %d:%d:%d\n",a,b,c,d)}' /proc/uptime )
    load=$( w | head -1 | awk -F'load average:' '{print $2}' | sed 's/^[ \t]*//;s/[ \t]*$//' )
    opsy=$( get_opsy )
    arch=$( uname -m )
    lbit=$( getconf LONG_BIT )
    host=$( hostname )
    kern=$( uname -r )
    virt=$( hostnamectl | awk '/Virtualization/ {print $2}' )
    disk=$( fdisk -l | grep 'Disk /dev/' | awk -F'Disk /dev/' '{print $2}' | sed 's/^.*://g' | sed 's/,.*//g' | sed 's/^[ \t]*//;s/[ \t]*$//' )
    avail=$( df -h / | awk '/2/ {print $4}' )
}

showinfo_zhcn(){
	get_sysinfo
	echo "########################################"
	echo "#                                      #"
	echo "#        Get System Information        #"
	echo "#           获取系统信息参数           #"
	echo "#                                      #"
	echo "########################################"
	echo 
	echo "主机名称              : ${host}"
	echo "CPU型号               : ${cname}"
	echo "CPU核心数             : ${cores}"
	echo "CPU频率               : ${freq} MHz"
	echo "运行内存RAM           : ${tram} MB"
	echo "虚拟内存SWAP          : ${swap} MB"
	echo "硬盘总空间            : ${disk}"
	echo "磁盘可用空间          : ${avail}"
	echo "开机连续运行时间      : ${up}"
	echo "平均负荷              : ${load}"
	echo "操作系统              : ${opsy}"
	echo "系统架构              : ${arch} (${lbit} Bit)"
	echo "内核版本              : ${kern}"
	echo "虚拟化架构            : ${virt}"
	echo -n "公网IPv4地址          : "
	echo $( get_ipv4_pub )
	echo
	echo "########################################"
	echo 
	exit 0
}

# Handle the command line arguments, if any.
while test $# -gt 0; do
    case "$1" in
        -h|--help) usage ;;
        -v|--version) echo "$TOOL_NAME $VERSION"; exit 0 ;;
        -c|--zhcn) showinfo_zhcn ;;
        --) shift; break ;;
        *) fail "unrecognized option '$1'";;
    esac
done
test $# -gt 0 && fail "extra operand '$1'"

get_sysinfo
echo "########################################"
echo "#                                      #"
echo "#        Get System Information        #"
echo "#                                      #"
echo "########################################"
echo 
echo "Hostname                       : ${host}"
echo "CPU model                      : ${cname}"
echo "Number of cores                : ${cores}"
echo "CPU frequency                  : ${freq} MHz"
echo "Total amount of RAM            : ${tram} MB"
echo "Total amount of SWAP           : ${swap} MB"
echo "Disk space                     : ${disk}"
echo "Disk partition free space      : ${avail}"
echo "System uptime                  : ${up}"
echo "Load average                   : ${load}"
echo "Operating system               : ${opsy}"
echo "Architecture                   : ${arch} (${lbit} Bit)"
echo "Kernel                         : ${kern}"
echo "Virtualization                 : ${virt}"
echo -n "IPv4 address                   : "
echo $( get_ipv4_pub )
echo
echo "########################################"
echo 
