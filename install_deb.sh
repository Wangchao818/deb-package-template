#!/bin/bash

# 检查是否提供了包名和版本号参数
if [ "$#" -ne 1 ]; then
    echo "错误：必须提供 deb 包名"
    echo "用法：$0 <deb 包名>"
    echo "示例：$0 orin-system-deploy-v0.0.1.deb"
    exit 1
fi

deb_name=$1

sudo dpkg -i $deb_name
exit $?
