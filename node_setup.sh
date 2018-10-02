#!/bin/bash
Green_font_prefix="\033[32m" && Red_font_prefix="\033[31m" && Green_background_prefix="\033[42;37m" && Red_background_prefix="\033[41;37m" && Font_color_suffix="\033[0m"
normal=$(tput sgr0)
bold=$(tput bold)
Info="${Green_font_prefix}[信息]${Font_color_suffix}"
Error="${Red_font_prefix}[错误]${Font_color_suffix}"

user_input (){
	args="${@:2}"
	while [ true ]; do
		answer=""
		printf "~> "

		if [ "$1" ]; then
			args="${@:1}"
			read answer
			if [ "$answer" == "" ]; then
				answer=$1
				echo -en "\033[1A\033[2K"
				echo "~> $1"
				break
			fi
		else
			while [ true ]; do
				read answer
				if [ "$answer" == "" ]; then
					echo "${bold}输入无效!${normal}"
					printf "~> "
				else
					break
				fi
			done
		fi

		if [ "$2" ]; then
			for arg in $args; do
				if [ "$arg" == "_NUM" ] && [ "${answer##*[!0-9]*}" ]; then
					break 2
				elif [ "${arg,,}" == "${answer,,}" ]; then
					break 2
				fi
			done
			echo "${bold}输入无效!${normal}"
		else
			break
		fi
	done
}

check_root(){
	[[ $EUID != 0 ]] && echo -e "${Error} 当前账号非 ROOT (或没有 ROOT 权限), 无法继续操作, 请使用${Green_background_prefix} sudo su ${Font_color_suffix}来获取临时 ROOT 权限 (执行后会提示输入当前账号的密码)." && exit 1
}

check_sys(){
	if [[ -f /etc/redhat-release ]]; then
		release="centos"
	elif cat /etc/issue | grep -q -E -i "debian"; then
		release="debian"
	elif cat /etc/issue | grep -q -E -i "ubuntu"; then
		release="ubuntu"
	elif cat /etc/issue | grep -q -E -i "centos|red hat|redhat"; then
		release="centos"
	elif cat /proc/version | grep -q -E -i "debian"; then
		release="debian"
	elif cat /proc/version | grep -q -E -i "ubuntu"; then
		release="ubuntu"
	elif cat /proc/version | grep -q -E -i "centos|red hat|redhat"; then
		release="centos"
    fi
}

check_kernel(){
	kernel_version=`uname -r`
	if [[ ${kernel_version} == "3.10.0-327.el7.x86_64" ]]; then
		echo -e "${Info} 您目前使用的 Kernel ${kernel_version} 可使用锐速."
		set_appex
	elif [[ ${kernel_version} == 4.1* ]]; then
		echo -e "${Info} 您目前使用的是 Kernel ${kernel_version}, 将开启 BBR."
		set_bbr
	else
		echo -e "${Error} 当前 Kernel ${kernel_version} 不支持锐速以及 BBR. 是否尝试安装 Kernel ? [${bold}yes${normal}/no]"
		user_input "yes" "no" "y" "n"
		if [[ $answer == yes ]] || [[ $answer == y ]]; then
			install_kernel
		fi
	fi
}

install_kernel(){
	echo -e "${Info} 您需要安装 锐速内核(appex) 或 BBR内核(bbr)? [bbr/appex]"
	user_input "bbr" "appex"
	if [[ $answer == bbr ]]; then
		if [[ ${release} == "centos" ]]; then
			echo "GRUB_DEFAULT=0" >> /etc/default/grub
			wget --no-check-certificate -qO /tmp/elrepo-release-7.0-3.el7.elrepo.noarch.rpm http://elrepo.reloumirrors.net/elrepo/el7/x86_64/RPMS/elrepo-release-7.0-3.el7.elrepo.noarch.rpm
			yum install -y /tmp/elrepo-release-7.0-3.el7.elrepo.noarch.rpm
			yum --enablerepo=elrepo-kernel install -y kernel-ml
			grub2-set-default 0
			echo -e "${Info} Kernel 安装完成, 请重启机器."
			exit 1
		elif [[ ${release} == "debian" ]]; then
			cp /etc/apt/sources.list{,.bak}
			sed -i -e 's/ \(stable\|jessie\|stretch\)/ buster/ig' /etc/apt/sources.list
			apt-get update
			apt-get --download-only -y dist-upgrade
			apt-get -y dist-upgrade
			apt-get -y install linux-image-amd64 linux-headers-amd64
			echo -e "${Info} Kernel 升级完成, 请重启机器."
			exit 1
		else
			echo -e "${Error} 暂时只支持 CentOS7 以及 Debian 安装 Kernel."
			exit 1
		fi
	elif [[ $answer == appex ]]; then
		if [[ ${release} == "centos" ]]; then
			wget --no-check-certificate -qO /tmp/kernel-3.10.0-327.el7.x86_64.rpm https://raw.githubusercontent.com/ManSoraTech/Scientific-Internetsocks/manyuser/kernel/centos/7/kernel-3.10.0-327.el7.x86_64.rpm
			yum install -y /tmp/kernel-3.10.0-327.el7.x86_64.rpm
			echo -e "${Info} Kernel 安装完成, 请重启机器."
			exit 1
		else
			echo -e "${Error} 暂时只支持 CentOS7 安装 Kernel."
			exit 1
		fi
	fi
}

check_cmd(){
	if type wget >/dev/null 2>&1; then 
		echo -e "${Info} wget 已安装."
	else
		if [[ ${release} == "centos" ]]; then
			yum install -y wget
		elif [[ ${release} == "debian" ]] || [[ ${release} == "ubuntu" ]]; then
			apt-get install -y wget
		fi
	fi

	if type curl >/dev/null 2>&1; then 
		echo -e "${Info} curl 已安装."
	else
		if [[ ${release} == "centos" ]]; then
			yum install -y curl
		elif [[ ${release} == "debian" ]] || [[ ${release} == "ubuntu" ]]; then
			apt-get install -y curl
		fi
	fi

	if type ifconfig >/dev/null 2>&1; then 
		echo -e "${Info} ifconfig 命令存在."
	else
		if [[ ${release} == "centos" ]]; then
			yum install -y net-tools
		elif [[ ${release} == "debian" ]] || [[ ${release} == "ubuntu" ]]; then
			apt-get install -y net-tools
		fi
	fi

	if type make >/dev/null 2>&1 && type gcc >/dev/null 2>&1; then 
		echo -e "${Info} Development Tools 已安装."
	else
		if [[ ${release} == "centos" ]]; then
			yum groupinstall -y "Development Tools"
		elif [[ ${release} == "debian" ]] || [[ ${release} == "ubuntu" ]]; then
			apt-get install -y build-essential
		fi
	fi
}

install_docker_ce(){
	if type docker >/dev/null 2>&1; then 
		echo -e "${Info} Docker CE 已安装" 
	else
		if [[ ${release} == "centos" ]]; then
			yum remove -y docker docker-client docker-client-latest docker-common docker-latest docker-latest-logrotate docker-logrotate docker-selinux docker-engine-selinux docker-engine
			yum install -y yum-utils device-mapper-persistent-data lvm2
			yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
			yum install -y docker-ce
			systemctl enable docker
			systemctl start docker
		elif [[ ${release} == "debian" ]]; then
			apt-get remove -y docker docker-engine docker.io
			apt-get install -y apt-transport-https ca-certificates gnupg2 software-properties-common
			curl -fsSL https://download.docker.com/linux/debian/gpg | apt-key add -
			add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/debian $(lsb_release -cs) stable"
			apt-get update
			apt-get install -y docker-ce
			systemctl enable docker
			systemctl start docker
		elif [[ ${release} == "ubuntu" ]]; then
			apt-get install -y apt-transport-https ca-certificates software-properties-common
			curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add -
			add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
			apt-get update
			apt-get install -y docker-ce
			systemctl enable docker
			systemctl start docker
		fi
	fi
}

set_ssr_env(){
	echo "节点名"
	user_input 
	NODENAME="$answer"
	echo "TCP 超时时间 [${bold}7440${normal},...]"
	user_input 7440 _NUM
	TCPTIMEOUT="$answer"
	echo "UDP 超时时间 [${bold}60${normal},...]"
	user_input 60 _NUM
	UDPTIMEOUT="$answer"
	echo "限制用户客户端数 [${bold}20${normal},...]"
	user_input 20 _NUM
	PROTOCOLPARAM="$answer"
	echo "单连接限速 [${bold}0${normal},...](KB)"
	user_input 0 _NUM
	SPEEDLIMITPERCON="$answer"
	echo "单用户限速 [${bold}0${normal},...](KB)"
	user_input 0 _NUM
	SPEEDLIMITPERUSER="$answer"
	echo "数据库地址 [${bold}Domain${normal} or IP]"
	user_input 
	MYSQLHOST="$answer"
	echo "数据库端口 [${bold}3306${normal},...]"
	user_input 3306 _NUM
	MYSQLPORT="$answer"
	echo "数据库名"
	user_input 
	MYSQLDB="$answer"
	echo "数据库用户"
	user_input 
	MYSQLUSER="$answer"
	echo "数据库密码"
	user_input 
	MYSQLPASS="$answer"
	echo "Docker DNS [${bold}1.1.1.1${normal},...]"
	user_input "1.1.1.1"
	DOCKERDNS="$answer"
}

set_ssr_docker(){
	docker run -d --name=Shadowsocks \
	-e NODE_NAME=$NODENAME \
	-e TCP_TIMEOUT=$TCPTIMEOUT \
	-e UDP_TIMEOUT=$UDPTIMEOUT \
	-e PROTOCOL_PARAM=$PROTOCOLPARAM \
	-e SPEED_LIMIT_PER_CON=$SPEEDLIMITPERCON \
	-e SPEED_LIMIT_PER_USER=$SPEEDLIMITPERUSER \
	-e MYSQL_HOST=$MYSQLHOST \
	-e MYSQL_PORT=$MYSQLPORT \
	-e MYSQL_USER=$MYSQLUSER \
	-e MYSQL_DBNAME=$MYSQLDB \
	-e MYSQL_PASSWORD=$MYSQLPASS \
	-e DOCKER_DNS=$DOCKERDNS \
	--sysctl net.ipv6.conf.all.disable_ipv6=0 \
	--dns="$DOCKERDNS" \
	--ulimit nofile=98304:98304 \
	--net=host \
	--restart=always \
	-v /etc/localtime:/etc/localtime:ro \
	mansora/ssr-node:latest
}

set_iptables(){
	if [[ ${release} == "centos" ]]; then
		systemctl disable firewalld
		systemctl stop firewalld
		yum install -y iptables-services
		systemctl enable iptables
		systemctl enable ip6tables
		systemctl restart iptables
		systemctl restart ip6tables
		iptables -F
		ip6tables -F
		service iptables save
		service ip6tables save
	elif [[ ${release} == "debian" ]] || [[ ${release} == "ubuntu" ]]; then
		apt-get install -y iptables-persistent
		iptables -F
		ip6tables -F
		iptables-save > /etc/iptables/rules.v4
		ip6tables-save > /etc/iptables/rules.v6
	fi
}

optimize(){
	timedatectl set-timezone Asia/Shanghai
	if [[ ${release} == "centos" ]]; then
		setenforce 0
		sed -i '/SELINUX/s/enforcing/disabled/' /etc/selinux/config
	fi

	rm -rf /etc/security/limits.d/* 
	rm -rf /etc/sysctl.d/*
	echo -e "*    soft    nofile    1024000\n*    hard    nofile    1024000" > /etc/security/limits.conf
	echo -e "fs.file-max = 1024000\nvm.swappiness = 100\nnet.core.somaxconn = 32768\nnet.netfilter.nf_conntrack_helper = 1\nnet.netfilter.nf_conntrack_acct = 1\nnet.netfilter.nf_conntrack_checksum = 1\nnet.netfilter.nf_conntrack_max = 655350\nnet.ipv4.ip_forward = 1\nnet.ipv4.ip_no_pmtu_disc = 1\nnet.ipv4.conf.default.arp_ignore = 1\nnet.ipv4.conf.default.proxy_arp = 1\nnet.ipv4.icmp_echo_ignore_broadcasts = 1\nnet.ipv4.icmp_ignore_bogus_error_responses = 1\nnet.ipv6.conf.default.forwarding = 1\nnet.ipv6.conf.default.disable_ipv6 = 0\nnet.ipv6.conf.default.use_tempaddr = 2\nnet.ipv6.conf.default.temp_prefered_lft = 3600\nnet.ipv6.conf.default.temp_valid_lft = 7200\nnet.ipv6.conf.default.max_addresses = 26\nnet.ipv4.tcp_syncookies = 1\nnet.ipv4.tcp_tw_reuse = 1\nnet.ipv4.tcp_tw_recycle = 0\nnet.ipv4.tcp_mtu_probing = 1\nnet.ipv4.tcp_fin_timeout = 30\nnet.ipv4.tcp_keepalive_time = 1200\nnet.ipv4.ip_local_port_range = 9000 65535\nnet.ipv4.tcp_fastopen = 3\nnet.ipv4.tcp_fastopen_blackhole_timeout_sec = 0\n" > /etc/sysctl.d/10-custom.conf
	sysctl -q --system -p
	sed -i 's/#Compress=yes/Compress=yes/' /etc/systemd/journald.conf
	sed -i 's/#SystemMaxUse=/SystemMaxUse=5G/' /etc/systemd/journald.conf
	sed -i 's/#RuntimeMaxUse=/RuntimeMaxUse=100M/' /etc/systemd/journald.conf
}

set_bbr(){
	echo -e "${Info} 您需要安装 原版 BBR 或 魔改 BBR? [origin/nanqinlang]"
	user_input "origin" "nanqinlang"
	if [[ $answer == origin ]]; then
		echo -e "\nnet.core.default_qdisc = fq\nnet.ipv4.tcp_congestion_control = bbr\n" > /etc/sysctl.d/99-bbr.conf
	elif [[ $answer == nanqinlang ]]; then
		wget --no-check-certificate -qO /tmp/Makefile https://raw.githubusercontent.com/Love4Taylor/tcp_nanqinlang-test/master/Makefile

		if [[ ${kernel_version} == 4.15* ]]; then
			wget --no-check-certificate -qO /tmp/tcp_nanqinlang-test.c https://raw.githubusercontent.com/Love4Taylor/tcp_nanqinlang-test/master/Kernel_4.15/tcp_nanqinlang-test.c
		elif [[ ${kernel_version} == 4.16* ]]; then
			wget --no-check-certificate -qO /tmp/tcp_nanqinlang-test.c https://raw.githubusercontent.com/Love4Taylor/tcp_nanqinlang-test/master/Kernel_4.16/tcp_nanqinlang-test.c
		elif [[ ${kernel_version} == 4.17* ]]; then
			wget --no-check-certificate -qO /tmp/tcp_nanqinlang-test.c https://raw.githubusercontent.com/Love4Taylor/tcp_nanqinlang-test/master/Kernel_4.17/tcp_nanqinlang-test.c
		fi

		cd /tmp/
		make
		make install
		cd ~
		echo -e "\nnet.core.default_qdisc = fq\nnet.ipv4.tcp_congestion_control = nanqinlang-test\n" > /etc/sysctl.d/99-bbr.conf
	fi

	sysctl -q --system -p
}

set_appex(){
	if [ ! -d "/appex" ]; then
		wget --no-check-certificate -qO /tmp/appex.sh "https://raw.githubusercontent.com/0oVicero0/serverSpeeder_Install/master/appex.sh"
		chmod +x /tmp/appex.sh
		/tmp/appex.sh 'install'
		sed -i "s/initialCwndWan=\"22\"/initialCwndWan=\"45\"/" /appex/etc/config
		sed -i "s/l2wQLimit=\"256 2048\"/l2wQLimit=\"2560 20480\"/" /appex/etc/config
		sed -i "s/w2lQLimit=\"256 2048\"/w2lQLimit=\"2560 20480\"/" /appex/etc/config
		sed -i "s/engineNum=\"0\"/engineNum=\"1\"/" /appex/etc/config
		/appex/bin/serverSpeeder.sh restart
	fi
}

install_netdata(){
	wget --no-check-certificate -qO /tmp/kickstart.sh https://my-netdata.io/kickstart.sh
	chmod +x /tmp/kickstart.sh
	/tmp/kickstart.sh
}

check_root
check_sys
[[ ${release} != "debian" ]] && [[ ${release} != "ubuntu" ]] && [[ ${release} != "centos" ]] && echo -e "${Error} 不支持当前系统 ${release} !" && exit 1
optimize
echo -e "${Info} 正在检查所需命令."
check_cmd
wget --no-check-certificate -qO /bin/reset_ss https://raw.githubusercontent.com/ManSoraTech/Scientific-Internetsocks/manyuser/reset_ss
chmod +x /bin/reset_ss
check_kernel
echo -e "${Info} 请填写服务端参数."
set_ssr_env
install_docker_ce
echo -e "${Info} 正在设置 Docker."
set_ssr_docker
echo -e "${Info} 正在安装 netdata."
install_netdata
echo -e "${Info} 正在设置 防火墙."
set_iptables
echo -e "${Info} 配置结束, 最好重启一次机器. 请通过${Green_background_prefix} docker logs Shadowsocks -f ${Font_color_suffix}来查看 SSR 运行日志."
