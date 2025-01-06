#!/bin/bash

# 当前版本信息
VERSION=V20250106
# 工作目录
FLYBIT_HOME=/opt/flybit
# 脚本下载地址
SHELL_URL=https://raw.githubusercontent.com/FlyBitVIP/FlyBit-Agent/main/flybit.sh
# 程序下载地址
AGENT_URL=https://raw.githubusercontent.com/FlyBitVIP/FlyBit-Agent/main/flybit-agent.tar.gz
# Service下载地址
SERVICE_URL=https://raw.githubusercontent.com/FlyBitVIP/FlyBit-Agent/main/flybit.service

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
	
	echo $LINE
	success "已成功安装并启动服务"
	echo $LINE
	open_shell
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
	# 卸载脚本
	uninstall_shell
	echo $LINE
	success "已彻底卸载服务（一个文件不留）"
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
	success "当前脚本版本: $VERSION"
	if [[ "1" != "${status_code}" ]]; then
		server_version=$("$FLYBIT_HOME/flybit-agent" test 2>&1)
		success "当前服务版本: $server_version"
		if [[ "2" = "${status_code}" ]]; then
			err "服务未启动"
		else
			success "服务运行中"
		fi
	else
		err "未安装服务"
	fi
	
	# 命令信息
	echo $LINE
	info "请选择操作："
	echo $LINE
	
	success "1. 开始服务"
	success "2. 停止服务"
	success "3. 更新状态"
	success "4. 查看日志"
	success ""
	if check_flybit_shell;then
		err "7. 卸载脚本"
		success "8. 更新脚本"
	fi
	if [[ "1" = "${status_code}" ]]; then
		success "9. 安装服务"
	else
		err "9. 卸载服务"
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
		1) systemctl start flybit && deal_userinput ;;
		2) systemctl stop flybit && deal_userinput ;;
		3) deal_userinput ;;
		4) 
			clear
			tail -fn 30 $FLYBIT_HOME/logs/info.log
			;;
		7) uninstall_shell ;;
		8) upgrade_shell ;;
		9)  
			if [[ "1" == "${status_code}" ]]; then
				install
			else
				uninstall
			fi
			;;
		0) 
			info "退出"
			exit 0
			;;
		*) echo "无效的选择。" &&  display_menu;;
	esac
}

# 倒计时进入脚本
open_shell() {
	for((i=3;i>0;i--));do
		echo -ne "\r$i 秒后进入脚本";
		sleep 1
	done
	flybit
}

# 更新脚本
upgrade_shell() {
	download $SHELL_URL /usr/bin/flybit
	success "更新成功"
	chmod +x /usr/bin/flybit
	open_shell
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
			open_shell
			exit 0
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
