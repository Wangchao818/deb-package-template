#!/bin/bash

# set -x

# 检查是否提供了包名和版本号参数
if [ "$#" -ne 3 ]; then
    echo "错误：必须提供 包名 、版本号、root_path 三个参数。"
    echo "用法：$0 <包名> <版本号> <root_path>"
    echo "示例：$0 my_package 1.2.3 /home/nvidia/orin-system-deploy-v0.0.1"
    exit 1
fi

# 获取包名和版本号参数
package_name=$1
version=$2
root_path=$3
control_path="$package_name/DEBIAN/control"
prerm_path="$package_name/DEBIAN/prerm"
deploy_sh_dir="$package_name/usr/local/bin/"

# 使用sed命令替换 control 文件中的 Version 字段
sed -i "s/^Version:.*$/Version: ${version}/" "${control_path}"
# 检查
if [ $? -ne 0 ]; then
    echo "错误:无法修改DEBIAN/control文件中的Version字段。"
    exit 1
fi

# 使用sed命令替换 prerm 文件中的 root_path= 字段
sed -i "s|^root_path=.*$|root_path=${root_path}|" "${prerm_path}"
# 检查
if [ $? -ne 0 ]; then
    echo "错误:无法修改 DEBIAN/prerm 文件中的 root_path= 字段。"
    exit 1
fi

# 使用find和sed命令组合替换 $package_name/usr/bin/*.sh 文件中的 root_path 字段
deploy_sh_file=$(find $deploy_sh_dir -name "*.sh")
sed -i "s|^root_path=.*$|root_path=${root_path}|" "${deploy_sh_file}"
# 检查
if [ $? -ne 0 ]; then
    echo "错误:无法修改 $deploy_sh_dir 文件中的 root_path 字段。"
    exit 1
fi

dpkg-deb --build $package_name
exit $?