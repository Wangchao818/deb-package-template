#mkdir -p /home/nvidia/code/mnt
#sudo umount /dev/sdb1
#sudo mount /dev/sdb1 /home/nvidia/code/mnt
#mkdir -p /home/nvidia/code/mnt/outpost_su-UB902K
#mkdir -p /home/nvidia/code/mnt/outpost_su-UB902K/data
#mkdir -p /home/nvidia/code/mnt/outpost_su-UB902K/log
#chmod
#sudo chmod -R 777 /home/nvidia/code/mnt

# ptp configure
sudo timedatectl set-ntp false
sudo ptpd -s --e2e -i enp2s0
