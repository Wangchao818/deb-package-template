#!/bin/bash
set -ex

# 检查是否以 sudo 权限运行脚本
if [ "$(id -u)" != "0" ]; then
    echo "Error: This script must be run with sudo."
    echo "Eg: sudo bash minipc_orin_deploy.sh"
    exit 1
fi
# 工作目录
root_path=/home/nvidia/minipc-orin-deploy-v0.0.1

# 配置SSH服务允许22端口访问
sshd_config=/etc/ssh/sshd_config
# 修改01-network-manager-all.yaml文件
network_manager=/etc/netplan/01-network-manager-all.yaml
# coredump 配置
cfg_file="/etc/sysctl.conf"
coredump_path=/home/nvidia/code/mnt
mkdir -p  $coredump_path
# nfs 自动挂载：//装机用
mkdir -p /home/nvidia/code/phigent/memorize_map
fstab_file=/etc/fstab
# mount_commd="10.31.3.3:/mnt/data/users/chao.wang/test_mount  /home/nvidia/code/chao.wang/test.mount_3.3  nfs defaults 0 0"
mount_commd="10.31.1.102:/home/nvidia/code/phigent/memorize_map/ /home/nvidia/code/phigent/memorize_map/  nfs defaults 0 0"

# 当前时间戳
timestamp=$(date +%Y%m%d%H%M%S)
# 创建日志文件
log_file="$root_path/minipc_orin_deploy"-"$timestamp.log"
touch $log_file
> $log_file
# 使用tee命令将输出同时显示到终端和写入到log文件
exec > >(tee "$log_file") 2>&1

# 函数：检查命令执行结果
check_command() {
    if [ $? -ne 0 ]; then
        local lineno=$1
        echo "ERROR LINE: $lineno"
        echo "ERROR COMMMAND: $2"
        exit 1
    fi
}

backup() {
    local source_file=$1
    local backup_file="${source_file}_${timestamp}"

    # 创建备份
    cp "$source_file" "$backup_file"
    if [ $? -eq 0 ]; then
        echo "$source_file backed up to $backup_file"
    else
        echo "Failed to create backup of $source_file"
        return 1 # 返回非零值表示备份失败
    fi
}

# 定义 check_and_add 函数
check_and_add() {
    local command=$1
    local file=$2

    # 检查 $command 是否已经在 $file 中配置
    if grep -q "$command" "$file"; then
        echo "$command is already configured."
    else
        # 如果没有配置，则将 $command 添加到 $file
        echo "$command" >> "$file"
        echo "$command added to $file"
    fi
}

updata_cfg(){
    local file=$1
    local new_config=$2
    local prefix=$3

    if grep -q "^$new_config" $file; then
        echo "$new_config is exists in $file"
        return 0
    else
        # 检查是否存在 $2 前缀，如果存在则修改其值，否则添加新的配置
        if grep -q "^$prefix" $file; then
            sed -i "s|^$prefix.*|$new_config|" $file
            echo "$new_config updata in $file."
        else
            echo "$new_config" >> $file
            echo "$new_config added to $file."
        fi
    fi
}

# 更新软件包列表
echo "update package list"
apt-get update

echo ""$'\n'"[1].Start IP configuration******************************************"
# 安装SSH服务
echo "install sshd"
apt-get install -y openssh-server
check_command $(($LINENO-1)) "openssh-server install failed"
backup $sshd_config
if grep -q '^Port' $sshd_config; then
    sed -i 's/^Port.*/Port 22/' $sshd_config
    echo "Port.* change into Port 22"
elif grep -q '^#Port' $sshd_config; then
    sed -i 's/^#Port.*/Port 22/' $sshd_config
    echo "#Port.* change into Port 22"
else
    echo "Port 22" >> $sshd_config
fi
ufw allow 22
systemctl restart sshd
# 安装ifconfig工具包
echo "install ifconfig"
apt install -y net-tools
check_command $(($LINENO-1)) "net-tools install failed"
backup $network_manager
cp $root_path/net/01-network-manager-all.yaml  $network_manager
# IP配置生效
# sudo netplan apply
echo "IP configuration is done."

echo ""$'\n'"[2].deploy prepare******************************************"
prepare_file=/home/nvidia/driver/prepare_91s.sh
prepare_service_file=/etc/systemd/system/Phigent.prepare_91s.service
mkdir -p /etc/systemd/system/
mkdir -p /home/nvidia/driver/
# 备份
touch  $prepare_service_file
touch  $prepare_file
backup $prepare_service_file
backup $prepare_file
cp  $root_path/prepare/Phigent.prepare_91s.service  /etc/systemd/system/
cp  $root_path/prepare/prepare_91s.sh               /home/nvidia/driver/
# 添加路由信息到 prepare_91s.sh
# prepare_file=/home/nvidia/driver/prepare_91s.sh
# route="sudo route add -net 10.31.1.1 netmask 255.255.255.255 dev enp2s0ls"
# if grep -q "$route" $prepare_file; then
#     echo "$route is already configured."
# else
#     echo "$route" >> $prepare_file
#     echo "$route added to $prepare_file"
# fi
#配置服务自启动
 sudo systemctl enable Phigent.prepare_91s.service        #开机自启动服务激活
#  sudo systemctl restart Phigent.prepare_91s.service     #重启节点服务
 echo "deploy prepare is done."
 
echo ""$'\n'"[3].deploy time sync******************************************"
#下载ptpd
echo "download ptpd"
sudo  apt-get install ptpd
check_command $(($LINENO-1)) "ptpd install failed"
# 部署到 prepare 服务
check_and_add "sudo timedatectl set-ntp false" $prepare_file
check_and_add "sudo ptpd -s --e2e -i enp2s0" $prepare_file
# 确认与Xavier/Orin 10.31.1.102的时间同步误差命令
cp  $root_path/time_sync/clockdiff      /home/nvidia/driver/
sudo chmod 777  /home/nvidia/driver/clockdiff  
# sudo /home/nvidia/driver/clockdiff -o 10.31.1.102
echo "deploy time sync is done."

echo ""$'\n'"[4].deploy coredump******************************************"
# 加入以下内容，其中 coredump 的目录可自定义
core_uses_pid="kernel.core_uses_pid=1"
prefix_core_uses_pid="kernel.core_uses_pid"
core_pattern="kernel.core_pattern="$coredump_path"/core-%e-%s-%u-%g-%p-%t"
prefix_core_pattern="kernel.core_pattern"
suid_dumpable="fs.suid_dumpable=2"
prefix_suid_dumpable="fs.suid_dumpable"
updata_cfg $cfg_file "# cfg system" "# cfg system"
updata_cfg $cfg_file $core_uses_pid  $prefix_core_uses_pid
updata_cfg $cfg_file $core_pattern   $prefix_core_pattern
updata_cfg $cfg_file $suid_dumpable  $prefix_suid_dumpable
# 执行以下命令先让本次配置生效
sudo sysctl -p 
ulimit -c unlimited
# 在prepare_91s.sh脚本中加入以下内容
check_and_add "sudo sysctl -p >/dev/null 2>&1"      $prepare_file
check_and_add "ulimit -c unlimited >/dev/null 2>&1" $prepare_file
echo "deploy coredump is done."

echo ""$'\n'"[5].deploy NFS******************************************"
# 安装nfs工具
echo "install nfs-common"
sudo apt-get install  nfs-common -y
check_command $(($LINENO-1)) "nfs-common install failed"
check_and_add "$mount_commd"  $fstab_file
# 保存退出后执行如下命令进行重写加载fstab配置
# sudo mount -a
echo "deploy NFS is done."

echo ""$'\n'"[6].deploy multi-screen******************************************"
mkdir -p  /home/nvidia/xinput_auto_map  
mkdir -p  /home/nvidia/.config/autostart
cp  $root_path/multi-screen/xinput_auto_map.sh          /home/nvidia/xinput_auto_map 
cp  $root_path/multi-screen/xinput_auto_map.sh.desktop  /home/nvidia/.config/autostart
chmod 777  /home/nvidia/xinput_auto_map/xinput_auto_map.sh
chmod 777  /home/nvidia/.config/autostart/xinput_auto_map.sh.desktop
# 重启验证
echo "deploy multi-screen is done."

