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
	disk=$( $( whereis fdisk | awk '{printf $2}' ) -l | grep "Disk $( df -h / | awk '/1/ {print $1}' | sed '$s/[0-9]$//' )" | awk '{printf $3 " " $4}' | sed 's/,//g' )
	avail=$( df -h / | awk '/1/ {print $4}' )
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
    echo "虚拟化架构            : $(virt_what)"
    echo -n "公网IPv4地址          : "
    echo $( get_ipv4_pub )
    echo
    echo "########################################"
    echo 
    exit 0
}

# Get virtualization of system
virt_what() {
	set -u
	root=''
	skip_qemu_kvm=false
	skip_lkvm=false

	VERSION="1.22"

	have_cpuinfo () {
		test -e "${root}/proc/cpuinfo"
	}

	use_sysctl() {
		# Lacking /proc, on some systems sysctl can be used instead.
		OS=$(uname) || fail "failed to get operating system name"

		[ "$OS" = "OpenBSD" ]
	}

	fail () {
		echo "virt-what: $1" >&2
		exit 1
	}

	usage () {
		echo "virt-what [options]"
		echo "Options:"
		echo "  --help		  Display this help"
		echo "  --version	   Display version and exit"
		exit 0
	}

	# Handle the command line arguments, if any.
	while test $# -gt 0; do
		case "$1" in
			--help) usage ;;
			--test-root=*)
				# Deliberately undocumented: used for 'make check'.
				root=$(echo "$1" | sed 's/.*=//')
				shift 1
				test -z "$root" && fail "--test-root option requires a value"
				;;
			-v|--version) echo "$VERSION"; exit 0 ;;
			--) shift; break ;;
			*) fail "unrecognized option '$1'";;
		esac
	done
	test $# -gt 0 && fail "extra operand '$1'"

	# Add /sbin and /usr/sbin to the path so we can find system
	# binaries like dmidecode.
	# Add /usr/libexec to the path so we can find the helper binary.
	prefix=/usr
	exec_prefix=/usr
	PATH="${root}/usr/libexec:${root}/sbin:${root}/usr/sbin:${PATH}"
	export PATH

	# Check we're running as root.
	EFFUID=$(id -u) || fail "failed to get current user id"

	if [ "x$root" = "x" ] && [ "$EFFUID" -ne 0 ]; then
		fail "this script must be run as root"
	fi

	# Try to locate the CPU-ID helper program
	CPUID_HELPER=$(which virt-what-cpuid-helper 2>/dev/null)
	if [ -z "$CPUID_HELPER" ] ; then
		fail "virt-what-cpuid-helper program not found in \$PATH"
	fi

	# Many fullvirt hypervisors give an indication through CPUID.  Use the
	# helper program to get this information.

	cpuid=$(virt-what-cpuid-helper)

	# Check for various products in the BIOS information.
	# Note that dmidecode doesn't exist on all architectures.  On the ones
	# it does not, then this will return an error, which is ignored (error
	# message redirected into the $dmi variable).

	dmi=$(LANG=C dmidecode 2>&1)

	# Architecture.
	# Note for the purpose of testing, we only call uname with -m option.

	arch=$(uname -m | sed -e 's/i.86/i386/' | sed -e 's/arm.*/arm/')

	# Check for Alibaba Cloud
	if echo "$dmi" | grep -q 'Manufacturer: Alibaba'; then
		# Check for Alibaba Cloud ECS Bare Metal (EBM) Instance
		if ( { echo -e "GET /latest/meta-datainstance/instance-type HTTP/1.0\r\nHost: 100.100.100.200\r\n\r" >&3; grep -sq 'ebm' <&3 ; } 3<> /dev/tcp/100.100.100.200/80 ) 2>/dev/null ; then
			echo "alibaba_cloud-ebm"
		else
			echo "alibaba_cloud"
		fi
	fi

	# Check for VMware.
	# cpuid check added by Chetan Loke.

	if [ "$cpuid" = "VMwareVMware" ]; then
		echo vmware
	elif echo "$dmi" | grep -q 'Manufacturer: VMware'; then
		echo vmware
	fi

	# Check for Hyper-V.
	# http://blogs.msdn.com/b/sqlosteam/archive/2010/10/30/is-this-real-the-metaphysics-of-hardware-virtualization.aspx
	if [ "$cpuid" = "Microsoft Hv" ]; then
		echo hyperv
	fi

	# Check for VirtualPC.
	# The negative check for cpuid is to distinguish this from Hyper-V
	# which also has the same manufacturer string in the SM-BIOS data.
	if [ "$cpuid" != "Microsoft Hv" ] &&
		echo "$dmi" | grep -q 'Manufacturer: Microsoft Corporation' &&
		echo "$dmi" | grep -q 'Product Name: Virtual Machine'; then
		echo virtualpc
	fi

	# Check for VirtualBox.
	# Added by Laurent Léonard.
	if echo "$dmi" | grep -q 'Manufacturer: innotek GmbH'; then
		echo virtualbox
	fi

	# Check for bhyve.
	if [ "$cpuid" = "bhyve bhyve " ]; then
	  echo bhyve
	elif echo "$dmi" | grep -q "Vendor: BHYVE"; then
	  echo bhyve
	fi

	# Check for OpenVZ / Virtuozzo.
	# Added by Evgeniy Sokolov.
	# /proc/vz - always exists if OpenVZ kernel is running (inside and outside
	# container)
	# /proc/bc - exists on node, but not inside container.

	if [ -d "${root}/proc/vz" -a ! -d "${root}/proc/bc" ]; then
		echo openvz
	fi

	# Check for LXC containers
	# http://www.freedesktop.org/wiki/Software/systemd/ContainerInterface
	# Added by Marc Fournier

	if [ -e "${root}/proc/1/environ" ] &&
		cat "${root}/proc/1/environ" | tr '\000' '\n' | grep -Eiq '^container=lxc'; then
		echo lxc
	fi

	# Check for Linux-VServer
	if test -e "${root}/proc/self/status" \
	   && cat "${root}/proc/self/status" | grep -q "VxID: [0-9]*"; then
		echo linux_vserver
		if grep -q "VxID: 0$" "${root}/proc/self/status"; then
			echo linux_vserver-host
		else
			echo linux_vserver-guest
		fi
	fi

	# Check for UML.
	# Added by Laurent Léonard.
	if have_cpuinfo && grep -q 'UML' "${root}/proc/cpuinfo"; then
		echo uml
	fi

	# Check for IBM PowerVM Lx86 Linux/x86 emulator.
	if have_cpuinfo && grep -q '^vendor_id.*PowerVM Lx86' "${root}/proc/cpuinfo"
	then
		echo powervm_lx86
	fi

	# Check for Hitachi Virtualization Manager (HVM) Virtage logical partitioning.
	if echo "$dmi" | grep -q 'Manufacturer.*HITACHI' &&
	   echo "$dmi" | grep -q 'Product.* LPAR'; then
		echo virtage
	fi

	# Check for IBM SystemZ.
	if have_cpuinfo && grep -q '^vendor_id.*IBM/S390' "${root}/proc/cpuinfo"; then
		echo ibm_systemz
		if [ -f "${root}/proc/sysinfo" ]; then
			if grep -q 'VM.*Control Program.*KVM/Linux' "${root}/proc/sysinfo"; then
				echo ibm_systemz-kvm
			elif grep -q 'VM.*Control Program.*z/VM' "${root}/proc/sysinfo"; then
				echo ibm_systemz-zvm
			elif grep -q '^LPAR' "${root}/proc/sysinfo"; then
				echo ibm_systemz-lpar
			else
				# This is unlikely to be correct.
				echo ibm_systemz-direct
			fi
		fi
	fi

	# Check for Parallels.
	if echo "$dmi" | grep -q 'Vendor: Parallels'; then
		echo parallels
		skip_qemu_kvm=true
	fi

	# Check for Nutanix AHV.
	if echo "$dmi" | grep -q 'Manufacturer: Nutanix'; then
		echo nutanix_ahv
	fi

	# Check for oVirt/RHEV.
	if echo "$dmi" | grep -q 'Manufacturer: oVirt'; then
		echo ovirt
	fi
	if echo "$dmi" | grep -q 'Product Name: RHEV Hypervisor'; then
		echo rhev
	fi

	# Google Cloud
	if echo "$dmi" | grep -q 'Product Name: Google Compute Engine'; then
		echo google_cloud
	fi

	# Red Hat's hypervisor.
	if echo "$dmi" | grep -q 'Manufacturer: Red Hat'; then
		echo redhat
	fi

	# Check for Xen.

	if [ "$cpuid" = "XenVMMXenVMM" ] &&
		! echo "$dmi" | grep -q 'No SMBIOS nor DMI entry point found, sorry'; then
		echo xen; echo xen-hvm
		skip_qemu_kvm=true
	elif [ -d "${root}/proc/xen" ]; then
		echo xen
		if grep -q "control_d" "${root}/proc/xen/capabilities" 2>/dev/null; then
			echo xen-dom0
		else
			echo xen-domU
		fi
		skip_qemu_kvm=true
		skip_lkvm=true
	elif [ -f "${root}/sys/hypervisor/type" ] &&
		grep -q "xen" "${root}/sys/hypervisor/type"; then
		# Ordinary kernel with pv_ops.  There does not seem to be
		# enough information at present to tell whether this is dom0
		# or domU.  XXX
		echo xen
	elif [ "$arch" = "arm" ] || [ "$arch" = "aarch64" ]; then
		if [ -d "${root}/proc/device-tree/hypervisor" ] &&
			grep -q "xen" "${root}/proc/device-tree/hypervisor/compatible"; then
			echo xen
			skip_qemu_kvm=true
			skip_lkvm=true
		elif [ -d "${root}/proc/device-tree/hypervisor" ] &&
			grep -q "vmware" "${root}/proc/device-tree/hypervisor/compatible"; then
			echo vmware
			skip_lkvm=true
		fi
	elif [ "$arch" = "ia64" ]; then
		if [ -d "${root}/sys/bus/xen" -a ! -d "${root}/sys/bus/xen-backend" ]; then
			# PV-on-HVM drivers installed in a Xen guest.
			echo xen
			echo xen-hvm
		else
			# There is no virt leaf on IA64 HVM.  This is a last-ditch
			# attempt to detect something is virtualized by using a
			# timing attack.
			virt-what-ia64-xen-rdtsc-test > /dev/null 2>&1
			case "$?" in
				0) ;; # not virtual
				1) # Could be some sort of virt, or could just be a bit slow.
					echo virt
			esac
		fi
	fi

	# Check for QEMU/KVM.
	#
	# Parallels exports KVMKVMKVM leaf, so skip this test if we've already
	# seen that it's Parallels.  Xen uses QEMU as the device model, so
	# skip this test if we know it is Xen.

	if ! "$skip_qemu_kvm"; then
		if [ "$cpuid" = "KVMKVMKVM" ]; then
			echo kvm
		elif [ "$cpuid" = "TCGTCGTCGTCG" ]; then
			echo qemu
			skip_lkvm=true
		elif echo "$dmi" | grep -q 'Product Name: KVM'; then
			echo kvm
			skip_lkvm=true
		elif echo "$dmi" | grep -q 'Manufacturer: QEMU'; then
			# The test for KVM above failed, so now we know we're
			# not using KVM acceleration.
			echo qemu
			skip_lkvm=true
		elif [ "$arch" = "arm" ] || [ "$arch" = "aarch64" ]; then
			if [ -d "${root}/proc/device-tree" ] &&
				ls "${root}/proc/device-tree" | grep -q "fw-cfg"; then
				# We don't have enough information to determine if we're
				# using KVM acceleration or not.
				echo qemu
				skip_lkvm=true
			fi
		elif [ -d ${root}/proc/device-tree/hypervisor ] &&
			 grep -q "linux,kvm" /proc/device-tree/hypervisor/compatible; then
			# We are running as a spapr KVM guest on ppc64
			echo kvm
			skip_lkvm=true
		elif use_sysctl; then
			# SmartOS KVM
			product=$(sysctl -n hw.product)
			if echo "$product" | grep -q 'SmartDC HVM'; then
				echo kvm
			fi
		else
			# This is known to fail for qemu with the explicit -cpu
			# option, since /proc/cpuinfo will not contain the QEMU
			# string. QEMU 2.10 added a new CPUID leaf, so this
			# problem only triggered for older QEMU
			if have_cpuinfo && grep -q 'QEMU' "${root}/proc/cpuinfo"; then
				echo qemu
			fi
		fi
	fi

	if ! "$skip_lkvm"; then
		if [ "$cpuid" = "LKVMLKVMLKVM" ]; then
			echo lkvm
		elif [ "$arch" = "arm" ] || [ "$arch" = "aarch64" ]; then
			if [ -d "${root}/proc/device-tree" ] &&
				grep -q "dummy-virt" "${root}/proc/device-tree/compatible"; then
				echo lkvm
			fi
		fi
	fi

	# Check for Docker.
	if [ -f "${root}/.dockerenv" ] || [ -f "${root}/.dockerinit" ] || \
	   grep -qF /docker/ "${root}/proc/self/cgroup" 2>/dev/null; then
		echo docker
	fi

	# Check for Podman.
	if [ -e "${root}/proc/1/environ" ] &&
		cat "${root}/proc/1/environ" | tr '\000' '\n' | grep -Eiq '^container=podman'; then
		echo podman
	elif grep -qF /libpod- "${root}/proc/self/cgroup" 2>/dev/null; then
		echo podman
	fi

	# Check ppc64 lpar, kvm or powerkvm

	# example /proc/cpuinfo line indicating 'not baremetal'
	# platform  : pSeries
	#
	# example /proc/ppc64/lparcfg systemtype line
	# system_type=IBM pSeries (emulated by qemu)

	if [ "$arch" = "ppc64" ] || [ "$arch" = "ppc64le" ] ; then
		if have_cpuinfo && grep -q 'platform.**pSeries' "${root}/proc/cpuinfo"; then
			if grep -q 'model.*emulated by qemu' "${root}/proc/cpuinfo"; then
					echo ibm_power-kvm
			else
				# Assume LPAR, now detect shared or dedicated
				if grep -q 'shared_processor_mode=1' "${root}/proc/ppc64/lparcfg"; then
					echo ibm_power-lpar_shared
				else
					echo ibm_power-lpar_dedicated
				fi
			# detect powerkvm?
			fi
		fi
	fi

	# Check for OpenBSD/VMM
	if [ "$cpuid" = "OpenBSDVMM58" ]; then
			echo vmm
	fi

	# Check for LDoms
	if [ "${arch#sparc}" != "$arch" ] && [ -e "${root}/dev/mdesc" ]; then
		echo ldoms
		if [ -d "${root}/sys/class/vlds/ctrl" ] && \
				 [ -d "${root}/sys/class/vlds/sp" ]; then
			echo ldoms-control
		else
			echo ldoms-guest
		fi
		MDPROP="${root}/usr/lib/ldoms/mdprop.py"
		if [ -x "${MDPROP}" ]; then
			if [ -n "$($MDPROP -v iodevice device-type=pciex)" ]; then
				echo ldoms-root
				echo ldoms-io
			elif [ -n "$($MDPROP -v iov-device vf-id=0)" ]; then
				echo ldoms-io
			fi
		fi
	fi

	# Check for AWS.
	# AWS on Xen.
	if echo "$dmi" | grep -Eq 'Version: [0-9]+\.[0-9]+\.amazon'; then
		echo aws
	# AWS on baremetal or KVM.
	elif echo "$dmi" | grep -q 'Vendor: Amazon EC2'; then
		echo aws
	fi
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
echo "Virtualization                 : $(virt_what)"
echo -n "IPv4 address                   : "
echo $(get_ipv4_pub)
echo
echo "########################################"
echo 

