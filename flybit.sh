#!/bin/bash

# 当前版本信息
VERSION="20250106"
# 工作目录
FLYBIT_HOME=/opt/flybit
# 脚本下载地址
SHELL_URL=https://raw.githubusercontent.com/FlyBitVIP/FlyBit-Agent/main/flybit.sh
# 程序下载地址
AGENT_URL=https://media.githubusercontent.com/media/FlyBitVIP/FlyBit-Agent/refs/heads/main/flybit-agent.tar.gz?download=true
# Service下载地址
SERVICE_URL=https://raw.githubusercontent.com/FlyBitVIP/FlyBit-Agent/main/flybit.service

red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
plain='\033[0m'
LINE="=================================="

check() {
  # 检查当前用户是否为root
  [[ $EUID -ne 0 ]] && echo -e "${red}错误：${plain} 必须使用root用户运行此脚本！\n" && exit 1
  # check os
  if [[ -f /etc/redhat-release ]]; then
      release="centos"
  elif cat /etc/issue | grep -Eqi "alpine"; then
      release="alpine"
      echo -e "${red}脚本暂不支持alpine系统！${plain}\n" && exit 1
  elif cat /etc/issue | grep -Eqi "debian"; then
      release="debian"
  elif cat /etc/issue | grep -Eqi "ubuntu"; then
      release="ubuntu"
  elif cat /etc/issue | grep -Eqi "centos|red hat|redhat|rocky|alma|oracle linux"; then
      release="centos"
  elif cat /proc/version | grep -Eqi "debian"; then
      release="debian"
  elif cat /proc/version | grep -Eqi "ubuntu"; then
      release="ubuntu"
  elif cat /proc/version | grep -Eqi "centos|red hat|redhat|rocky|alma|oracle linux"; then
      release="centos"
  elif cat /proc/version | grep -Eqi "arch"; then
      release="arch"
  else
      echo -e "${red}未检测到系统版本，请联系脚本作者！${plain}\n" && exit 1
  fi

  arch=$(uname -m)

  if [[ $arch == "x86_64" || $arch == "x64" || $arch == "amd64" ]]; then
      arch="64"
  elif [[ $arch == "aarch64" || $arch == "arm64" ]]; then
      arch="arm64-v8a"
  elif [[ $arch == "s390x" ]]; then
      arch="s390x"
  else
      arch="64"
      echo -e "${red}检测架构失败，使用默认架构: ${arch}${plain}"
  fi

  # 检查是否为64位系统
  if [ "$(getconf WORD_BIT)" != '32' ] && [ "$(getconf LONG_BIT)" != '64' ] ; then
      echo "本软件不支持 32 位系统(x86)，请使用 64 位系统(x86_64)，如果检测有误，请联系作者"
      exit 2
  fi
}

# 输出红色
err() {
    printf "${red}%s${plain}\n" "$*" >&2
}

# 输出绿色
success() {
    printf "${green}%s${plain}\n" "$*"
}

# 输出黄色
info() {
	printf "${yellow}%s${plain}\n" "$*"
}

# 检查脚本是否安装
check_flybit_shell() {
	test -e "/usr/bin/flybit"
}

# 检查依赖
check_env() {
	echo $LINE
	echo "开始检查依赖"
    deps="wget grep systemctl"
    for dep in $deps; do
        if ! command -v "$dep" >/dev/null 2>&1; then
            err "不支持$dep, 请先安装$dep"
            exit 1
        fi
		success "命令$dep正常安装！"
    done
}

# 安装服务
install() {
	# 检查环境
	check_env
	
	# 创建文件夹
	mkdir -p $FLYBIT_HOME
	cd $FLYBIT_HOME
	success "创建文件夹成功"
	echo $LINE
	
	# 下载文件
	download $AGENT_URL "$FLYBIT_HOME/flybit-agent.tar.gz"
	download $SERVICE_URL /etc/systemd/system/flybit.service
	echo $LINE
	success "下载成功"
	echo $LINE
	
	# 解压缩到运行目录
	info "开始解压缩"
	tar -xzvf flybit-agent.tar.gz
	success "解压成功"
	echo $LINE
	
	# 删除压缩文件
	rm -f flybit-agent.tar.gz
	success "删除临时文件成功"
	
	# 设置root用户拥有读取权限
	chmod 644 /etc/systemd/system/flybit.service
	chmod +x $FLYBIT_HOME/flybit-agent
	systemctl daemon-reload
	success "设置文件权限成功"
	
	# 设置开机启动
	systemctl enable flybit
	
	# 启动服务
	systemctl start flybit

	if [ $# -eq 0 ]; then
	  success "安装成功"
	  exit 0;
	else
    TEMP_MSG="已成功安装并启动服务"
    display_menu
	fi
}

# 卸载
uninstall() {
	info "开始卸载"
	# 关闭开机启动
	systemctl disable flybit
	info "关闭开机启动成功"
	# 关闭服务
	systemctl stop flybit
	info "关闭服务成功"
	# 删除服务
	rm -f /etc/systemd/system/flybit.service
	info "删除服务成功"
	# 删除文件夹
	rm -rf $FLYBIT_HOME
	info "删除文件夹成功"
	echo $LINE
	if [ $# -eq 0 ]; then
	    success "卸载成功"
  	  exit 0;
  	else
      TEMP_MSG="卸载成功"
      display_menu
  	fi
}

# 获取服务状态
# 未安装返回 1
# 未启动返回 2
# 运行中返回 3
get_service_status() {
	local service_name="$1"
	# 检查 /opt/flybit/flybit-agent 文件是否存在
	if [ ! -f "$FLYBIT_HOME/flybit-agent" ]; then
		return "1"
	fi
	# 检查服务是否已安装
	if ! systemctl is-enabled "$service_name" > /dev/null 2>&1; then
		# 如果 systemctl is-enabled 返回非 0，则认为未安装
		return "1"
	fi
	# 检查服务是否正在运行
	if systemctl is-active --quiet "$service_name"; then
		# 如果 systemctl is-active 返回 0，则服务正在运行
		return "3"
	else
		# 如果 systemctl is-active 返回非 0，则服务未运行
		return "2"
	fi
}

# 显示菜单
display_menu() {
	clear
	# 输出版本和状态信息
	get_service_status "flybit"
	status_code=$?
	echo $LINE
	success "当前脚本版本: V$VERSION"
	if [[ "1" != "${status_code}" ]]; then
		server_version=$("$FLYBIT_HOME/flybit-agent" version 2>&1)
		success "当前服务版本: V$server_version"
		if [[ "2" = "${status_code}" ]]; then
			err "当前状态：服务未启动"
		else
			success "当前状态：服务运行中"
		fi
	else
		err "当前状态：未安装服务"
	fi
	
	# 命令信息
	echo $LINE
	info "请选择操作："
	echo $LINE
	
	if [[ "3" == "${status_code}" ]]; then
		success "1. 停止服务"
		success "2. 重启服务"
	fi
	if [[ "2" == "${status_code}" ]]; then
		success "1. 开始服务"
	fi
	success "3. 更新状态"
	if [[ "1" != "${status_code}" ]]; then
		success "4. 查看日志"
		success "5. 清空日志"
		success "6. 配置管理"
	fi
	success ""
	if check_flybit_shell;then
		success "7. 更新脚本"
		err "8. 卸载脚本"
	fi
	
	
	if [[ "1" = "${status_code}" ]]; then
		success "9. 安装服务"
	else
		err "9. 卸载服务"
	fi
	success ""
	success "10. BBR"
	success ""
	info "0. 退出"
	echo $LINE
	if [ ! -n "$TEMP_MSG" ]; then
#	if [ $TEMP_MSG ]; then
		echo $TEMP_MSG
		unset TEMP_MSG
		echo $LINE
	fi
	deal_userinput
}

# 处理用户输入
deal_userinput () {
	# 等待用户输入
	read -p "请输入你的选择: "  choice
	echo $LINE
	# 可以根据用户的选择执行不同的操作
	case "$choice" in
		1) 
			if [[ "3" == "${status_code}" ]]; then
				systemctl stop flybit
				TEMP_MSG="已停止服务"
			fi
			if [[ "2" == "${status_code}" ]]; then
				systemctl start flybit
				TEMP_MSG="已启动服务"
			fi
			display_menu
			;;
		2) 
			systemctl restart flybit
			TEMP_MSG="已重启服务"
			display_menu 
			;;
		3) 
			TEMP_MSG="更新状态成功"
			display_menu 
			;;
		4) 
			clear
			tail -fn 30 $FLYBIT_HOME/logs/info.log
			;;
		5) 
			rm -rf $FLYBIT_HOME/logs/*
			TEMP_MSG="清空日志成功"
			display_menu
			;;
	  6) display_config;;
		7) upgrade_shell 1;;
		8) uninstall_shell ;;
		9)  
			if [[ "1" == "${status_code}" ]]; then
				install 1
			else
				uninstall 1
			fi
			;;
	  10)
	    wget -N --no-check-certificate http://sh.xdmb.xyz/tcp.sh
	    chmod +x tcp.sh
	    ./tcp.sh
	    rm -f ./tcp.sh
	    display_menu
	    ;;
		0) 
			info "退出"
			exit 0
			;;
		*) echo "无效的选择。" &&  display_menu;;
	esac
}

# 显示配置菜单
display_config() {
  clear
  echo $LINE
  info "配置信息"
  echo $LINE
  cd $FLYBIT_HOME
  ./flybit-agent config print
  echo $LINE
  info "请选择操作："
  echo ""
  success "1. 新增配置(服务地址一样进行替换)"
  err "2. 删除配置"
  echo ""
  info "0. 返回上一级"
  echo $LINE
  if [ ! -n "$TEMP_MSG" ]; then
  #  if [ $TEMP_MSG ]; then
    echo $TEMP_MSG
    unset TEMP_MSG
    echo $LINE
  fi
  # 等待用户输入
  read -p "请输入你的选择: "  choice
  echo $LINE
  # 可以根据用户的选择执行不同的操作
  case "$choice" in
    1) newConfig;;
    2) deleteConfig;;
    0) display_menu;;
  esac
}

# 删除配置
deleteConfig() {
  read -p "请输入需要删除配置的编号: "  choice
  cd $FLYBIT_HOME
  TEMP_MSG=$(./flybit-agent config remove "$choice" 2>&1)
  display_config
}

# 新增配置
newConfig() {
  read -p "请输入对接地址: "  NEW_CONFIG_HOST
  read -p "请输入ID: "  NEW_CONFIG_ID
  read -p "请输入密钥: "  NEW_CONFIG_KEY
  TEMP_MSG=$(./flybit-agent config add "-host=$NEW_CONFIG_HOST" "-id=$NEW_CONFIG_ID" "-key=$NEW_CONFIG_KEY" 2>&1)
  display_config
}

# 倒计时进入脚本
open_shell() {
	for i in 3 2 1;do
		echo -ne "\r$i 秒后进入脚本";
		sleep 1
	done
	flybit
}

# 更新脚本
upgrade_shell() {
	download $SHELL_URL /usr/bin/flybit
	chmod +x /usr/bin/flybit
  success "更新成功"
	if [ $# -eq 0 ]; then
    exit 0;
  else
    TEMP_MSG="更新成功"
    open_shell
  fi
}

# 安装脚本
install_shell() {
	if ! check_flybit_shell;then
		if [ ! -f "/usr/bin/flybit" ];then
			echo $LINE
			info "正在安装脚本"
			SHELL_FOLDER=$(dirname $(readlink -f "$0"))
			cp "$SHELL_FOLDER/${0##*/}" /usr/bin/flybit
			chmod +x /usr/bin/flybit
			success "成功安装脚本到/usr/bin/flybit！"
      success "输入flybit即可运行脚本"
			if [ $# -eq 0 ]; then
			  open_shell
			fi
		fi
	fi
}

# 卸载脚本
uninstall_shell() {
	rm -rf /usr/bin/flybit
	echo ""
	info "卸载脚本成功！"
	downloadUrl="$SHELL_URL?$(date +%s)"
	info "重新安装脚本命令: wget -L -O /usr/bin/flybit $downloadUrl && chmod +x /usr/bin/flybit && flybit"
}

# 下载文件
download() {
	wget -L -O "$2" "$1?$(date +%s)"
}

# 命令行帮助
help() {
  clear
  echo $LINE
  success "Flybit脚本帮助"
  echo $LINE
  success "* 交互操作： flybit"
  echo $LINE
  success "* 查看信息： flybit info"
  success "* 查看版本： flybit version"
  success "* 查看帮助： flybit help"
  success "* 查看日志： flybit log"
  success "* 清空日志： flybit clear"
  success "* 启动服务： flybit start"
  success "* 关闭服务： flybit stop"
  success "* 重启服务： flybit restart"
  success "* 安装服务： flybit install"
  success "* 卸载服务： flybit uninstall"
  success "* 更新服务和脚本： flybit upgrade"
  success "* 卸载服务和脚本： flybit uninstallAll"
  echo $LINE
  success "* 查看配置 flybit config"
  success "* 删除配置 flybit config remove 1"
  info "  后面的1替换成查看配置中对应的序号"
  info "  删除配置之后原来的配置序号会发生改变"
  success "* 新增配置 flybit config add -host=通信地址 -id=ID -key=密钥"
  info "  新增配置，如果域名已存在会替换原来的配置"
#  echo "----------------------------------"
#  info "说明："
#  info "1. 新增配置，如果域名已存在会替换原来的配置"
#  info "2. 删除配置之后原来的配置序号会发生改变"
  echo $LINE
}

# 检查
check


# 判断脚本执行时有没有参数
if [ $# -eq 0 ]; then
  # 安装脚本
  install_shell
  # 如果没有参数，则调用 display_menu 方法
  display_menu
else
  # 安装脚本
  install_shell 1
  # 输出版本和状态信息
  get_service_status "flybit"
  status_code=$?
  # 处理用户输入
  case "$1" in
    # 帮助
    "help"|"-h")help;;
    # 查看日志
    "logs"|'log')
      clear
      tail -fn 30 $FLYBIT_HOME/logs/info.log
      ;;
    "version"|"-v")
      server_version=$("$FLYBIT_HOME/flybit-agent" version 2>&1)
      echo "$server_version"
      ;;
    "info"|"-i")
      clear
      echo $LINE
      success "当前脚本版本: V$VERSION"
      if [[ "1" != "${status_code}" ]]; then
        server_version=$("$FLYBIT_HOME/flybit-agent" version 2>&1)
        success "当前服务版本: V$server_version"
        if [[ "2" = "${status_code}" ]]; then
          err "当前状态：服务未启动"
        else
          success "当前状态：服务运行中"
        fi
      else
        err "当前状态：未安装服务"
      fi
      echo $LINE
      ;;
    "clear")
      rm $FLYBIT_HOME/logs/*
      if [[ "3" = "${status_code}" ]]; then
        systemctl restart flybit
      fi
      ;;
    # 卸载
    "uninstall")
      uninstall
      ;;
    "uninstallAll")
      uninstall
      uninstall_shell
      ;;
    # 安装服务
    "install") install;;
    # 更新
    "upgrade" | "update")
      upgrade_shell
      systemctl stop flybit
      install
      ;;
    # 启动服务
    "start") systemctl start flybit;;
    # 停止服务
    "stop") systemctl stop flybit;;
    # 重启服务
    "restart") systemctl restart flybit;;
    # 配置
    "config")
      echo $LINE
      cd $FLYBIT_HOME
      command_output=$(./flybit-agent config "${@:2}")
      exit_code=$?
      if [ $exit_code -eq 0 ]; then
        success "$command_output"
      else
        err "$command_output"
      fi
      if [[ "3" = "${status_code}" ]]; then
        systemctl restart flybit
      fi
      echo $LINE
      ;;
    *)
      err "错误的指令！"
      ;;
  esac
fi