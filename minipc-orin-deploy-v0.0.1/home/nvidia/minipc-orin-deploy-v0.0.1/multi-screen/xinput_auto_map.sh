#!/bin/bash

# 设备名称和输出显示器名称
device_name="WingCool Inc. TouchScreen"
output_display="DP-1-1"
# 初始化计数器
counter=3
while true; do
    # 获取设备ID
    device_id=$(xinput list | grep -i "$device_name" | awk -F 'id=' '{print $2}' | awk '{print $1}'| tail -1 )

    if [ -n "$device_id" ]; then
        # 映射到指定输出
        echo "Found device id: $device_id"
        xinput map-to-output $device_id $output_display
    else
        echo "Device not found."
    fi
    # 减少计数器
    ((counter--))
    # 检查计数器是否达到0
    if [ $counter -le 0 ]; then
        echo "Looping has reached 3 times, exiting..."
        break
    fi
    # 等待一定时间再次检查，例如每1分钟检查一次
    sleep 10
done