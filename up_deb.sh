#!/bin/bash

set -ex

# 检查是否提供了 arch  package_name
if [ "$#" -ne 2 ]; then
    echo "错误：必须提供 卸载的 软件名"
    echo "用法：$0 arch package_name"
    echo "示例：$0 focal/arm64  orin-system-deploy-v0.0.1.deb"
    exit 1
fi

arch=$1
package_name=$2

curl -X 'POST' \
  'http://62.234.8.93:8881/v1/upload/'$arch'' \
  -H 'accept: application/json' \
  -H 'Content-Type: multipart/form-data' \
  -F 'file=@'$package_name''
