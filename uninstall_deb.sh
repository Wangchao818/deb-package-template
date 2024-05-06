#!/bin/bash

# 检查是否提供了 软件名
if [ "$#" -ne 1 ]; then
    echo "错误：必须提供 卸载的 软件名"
    echo "用法：$0 <软件名>"
    echo "示例：$0 orin-system-deploy"
    exit 1
fi

software_name=$1

dpkg --remove $software_name
exit $?
