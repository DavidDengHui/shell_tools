#!/usr/bin/env bash
#
# Author: David Deng
# Url: https://covear.top

set -u

# Name of this tool
TOOL_NAME="get_sysinfo"

# Version of this tool
VERSION="4.0"

LET_CLEAR=0
ZHCN=0

# Help of this tool
usage () {
	echo "$TOOL_NAME [options]"
	echo "Options:"
	echo "  -h, --help		  Display this help and exit"
	echo "  -v, --version	   Display version and exit"
	echo "  -c, --zhcn		  Display information with Chinese"
	exit 0
}

# Program was terminated unexpectedly
fail () {
	echo "$TOOL_NAME: $1" >&2
	exit 1
}

# Get operating system version
get_opsy() {
	[ -f /etc/redhat-release ] && awk '{print ($1,$3~/^[0-9]/?$3:$4)}' /etc/redhat-release && return
	[ -f /etc/os-release ] && awk -F'[= "]' '/PRETTY_NAME/{print $3,$4,$5}' /etc/os-release && return
	[ -f /etc/lsb-release ] && awk -F'[="]+' '/DESCRIPTION/{print $2}' /etc/lsb-release && return
}

# Get IPv4 address of public Internet
get_ipv4_pub() {
	local IP=''
	IP=$( ip addr | egrep -o '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' | egrep -v "^192\.168|^172\.1[6-9]\.|^172\.2[0-9]\.|^172\.3[0-2]\.|^10\.|^127\.|^255\.|^0\." | head -n 1 )
	[ -z ${IP} ] && IP=$( wget -qO- -t1 -T2 ipv4.icanhazip.com )
	echo -n $IP
}

# Get system information
make_info() {
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
	disk=$( if [ $(id -u) == 0 ]; then $( whereis fdisk | awk '{printf $2}' ) -l | grep "Disk $( df -h / | awk '/1/ {print $1}' | sed '$s/[0-9]$//' )" | awk '{printf $3 " " $4}' | sed 's/,//g'; else df -h / | awk '/1/ {print $2}'; fi )
	avail=$( df -h / | awk '/1/ {print $4}' )
}

# Get virtualization of system
get_virt() {
	# Check we're running as root.
	root=''
	EFFUID=$(id -u) || echo "failed to get current user id"
	if [ "x$root" = "x" ] && [ "$EFFUID" -ne 0 ]; then
		echo -n $( hostnamectl | awk '/Virtualization/ {print $2}' )" "
		if [ $ZHCN == 1 ]; then echo "（如需获取更准确的信息，请使用sudo权限或者root用户）"; else echo "(For more accurate information, please use root or sudo)"; fi 
		exit 1
	fi
	if command -v virt-what >/dev/null 2>&1; then
		echo $(sudo virt-what)
	else 
		if command -v dnf >/dev/null 2>&1; then
			sudo dnf -y install virt-what
		elif command -v yum >/dev/null 2>&1; then
			sudo yum -y install virt-what
		elif command -v apt-get >/dev/null 2>&1; then
			sudo apt-get -y install virt-what
		elif command -v pkg >/dev/null 2>&1; then
			sudo pkg install -y virt-what
		fi
		LET_CLEAR=1
		if [ $ZHCN == 1 ]; then 
			echo -e "\n测试virt-what: $(sudo virt-what)\n"; 
			showinfo_zhcn; 
		else 
			echo -e "\nChecking virt-what: $(sudo virt-what)\n"; 
			showinfo; 
		fi 
	fi
	exit 1
}

showinfo_zhcn() {
	make_info
	echo -e "################################################"
	echo -e "#\t\t\t\t\t\t#"
	echo -e "#\t     Get System Information\t\t#"
	echo -e "#\t\t获取系统信息参数\t\t#"
	echo -e "#\t\t\t\t\t\t#"
	echo -e "################################################"
	echo -e 
	echo -e "主机名称\t\t: ${host}"
	echo -e "CPU型号\t\t\t: ${cname}"
	echo -e "CPU核心数\t\t: ${cores}"
	echo -e "CPU频率\t\t\t: ${freq} MHz"
	echo -e "运行内存RAM\t\t: ${tram} MB"
	echo -e "虚拟内存SWAP\t\t: ${swap} MB"
	echo -e "硬盘总空间\t\t: ${disk}"
	echo -e "磁盘可用空间\t\t: ${avail}"
	echo -e "开机连续运行时间\t: ${up}"
	echo -e "平均负荷\t\t: ${load}"
	echo -e "操作系统\t\t: ${opsy}"
	echo -e "系统架构\t\t: ${arch} (${lbit} Bit)"
	echo -e "内核版本\t\t: ${kern}"
	if [ $(id -u) -eq 0 ] && !(command -v virt-what >/dev/null 2>&1) ; then
		echo "正在安装插件virt-what..."
	fi	
	echo -e "虚拟化架构\t\t: $(get_virt)"
	if [ $LET_CLEAR == 1 ]; then 
		LET_CLEAR=0
		exit 1
	fi
	echo -e -n "公网IPv4地址\t\t: "
	echo -e $(get_ipv4_pub)
	echo -e
	echo -e "########################################"
	echo -e 
	exit 0
}

showinfo() {
	make_info
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
	if [ $(id -u) -eq 0 ] && !(command -v virt-what >/dev/null 2>&1) ; then
		echo "Getting virt-what..."
	fi
	echo "Virtualization                 : $(get_virt)"
	if [ $LET_CLEAR == 1 ]; then 
		LET_CLEAR=0
		exit 1
	fi
	echo -n "IPv4 address                   : "
	echo $(get_ipv4_pub)
	echo
	echo "########################################"
	echo 
	exit 0
}

# Handle the command line arguments, if any.
while test $# -gt 0; do
	case "$1" in
		-h|--help) usage;;
		-v|--version) echo "$TOOL_NAME $VERSION"; exit 0;;
		-c|--zhcn) ZHCN=1; showinfo_zhcn;;
		--) shift; break;;
		*) fail "unrecognized option '$1'";;
	esac
done
test $# -gt 0 && fail "extra operand '$1'"
showinfo
