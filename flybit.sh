#!/bin/bash

# 当前版本信息
VERSION=V20250106
# 工作目录
FLYBIT_HOME=/opt/flybit
# 脚本下载地址
SHELL_URL=https://raw.githubusercontent.com//FlyBitVIP/FlyBit-Agent/main/flybit.sh
# 程序下载地址
AGENT_URL=https://raw.githubusercontent.com//FlyBitVIP/FlyBit-Agent/main/flybit.sh

red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
plain='\033[0m'
LINE="=================================="

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

# 检查是否安装flybit服务
check_flybit_service() {
	return command -v "flybit" >/dev/null 2>&1
}

# 检查脚本是否安装
check_flybit_shell() {
	test -e "/usr/bin/flybit"
}

# 检查依赖
check_env() {
	echo $LINE
	echo "开始检查依赖"
    deps="wget grep systemctl curl"
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
	check_env
}

# 卸载
uninstall() {
	err "开始卸载"
}

# 显示菜单
display_menu() {
	clear
	echo $LINE
	success "当前版本: $VERSION"
	echo $LINE
	info "请选择操作："
	echo $LINE
	success "1. 开始服务"
	success "2. 停止服务"
	success "3. 查看状态"
	success "4. 查看日志"
	success ""
	if check_flybit_shell;then
		err "7. 卸载脚本"
		success "8. 更新脚本"
	fi
	if check_flybit_service;then
		err "9. 卸载服务"
	else
		success "9. 安装服务"
	fi
	success ""
	err "0. 退出"
	echo $LINE
	deal_userinput
}

# 处理用户输入
deal_userinput () {
	# 等待用户输入
	read -p "请输入你的选择: "  choice
	echo $LINE
	# 可以根据用户的选择执行不同的操作
	case "$choice" in
		1) echo "你选择了开始服务" ;;
		2) echo "你选择了停止服务" ;;
		3) echo "你选择了查看状态" ;;
		4) echo "你选择了查看日志" ;;
		7) uninstall_shell ;;
		8) upgrade_shell ;;
		9)  
			if check_flybit_service;then
				uninstall
			else
				install
			fi
			;;
		0) 
			info "退出"
			exit 0
			;;
		*) echo "无效的选择。" &&  display_menu;;
	esac
}

# 更新脚本
upgrade_shell() {
	wget -O /usr/bin/flybit $SHELL_URL
	success "更新成功"
	chmod +x /usr/bin/flybit
	for((i=3;i>0;i--));do
		echo -ne "\r$i 秒后进入脚本";
		sleep 1
	done
	flybit
	exit 0
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
			for((i=3;i>0;i--));do
				echo -ne "\r$i 秒后进入脚本";
				sleep 1
			done
			flybit
			exit 0
		fi
	fi
}

# 卸载脚本
uninstall_shell() {
	rm -rf /usr/bin/flybit
	echo ""
	info "卸载成功！"
	info "重新安装命令: wget -O /usr/bin/flybit $SHELL_URL&&chmod +x /usr/bin/flybit&&flybit"
}

install_shell

# 判断脚本执行时有没有参数
if [ $# -eq 0 ]; then
  # 如果没有参数，则调用 display_menu 方法
  display_menu
else
  # 如果有参数，则提示用户如何使用
  echo "用法: $0  (不带任何参数显示菜单)"
  exit 1 # 以非零状态退出，表示有错误
fi
