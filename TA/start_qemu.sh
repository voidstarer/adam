#!/bin/sh
#sudo -p "Password for cyberoam :$pass" qemu-system-x86_64 -M q35 -drive file=openwrt-x86-64-combined-ext4.img,id=d0,if=none,bus=0,unit=0 -device ide-hd,drive=d0,bus=ide.0 -nographic -name router -net nic -net tap,ifname=tap0,script=ifup_tap0.sh -net nic -net tap,ifname=tap1,script=ifup_tap1.sh 
LOGPATH=~/openwrt/makeimages/logs/
echo > $LOGPATH/Test_Result.log
echo > $LOGPATH/qemu.log
check_connectivity()
{
	ip=$1
	port=$2
	while [ 1 ]; do
		echo Checking connectivity to $ip $port
		nc -vz "$ip" "$port"
		[ $? -eq 0 ] && return 0
		sleep 1
	done
	return 1
}
check_icmp_connectivity()
{
	ipaddr=$1
	while [ 1 ]; do
		echo Checking connectivity to $ipaddr 
		ping -c 1 $ipaddr
		[ $? -eq 0 ] && return 0
		sleep 1
	done
	return 1
}

#copy new image to install qeumu
cp ~/openwrt/openwrt/bin/x86/openwrt-x86-64-combined-ext4.img .

##start qemu
sudo qemu-system-x86_64 -M q35 -drive file=openwrt-x86-64-combined-ext4.img,id=d0,if=none,bus=0,unit=0 -device ide-hd,drive=d0,bus=ide.0 -nographic -name router -net nic -net tap,ifname=tap0,script=ifup_tap0.sh -net nic -net tap,ifname=tap1,script=ifup_tap1.sh 2>1 & 
sleep 
#wait for Qemu up
check_icmp_connectivity 192.168.1.1
Test_Result=`echo $?`
echo ".......... print $Test_Result"
# copy networking configuration to qemu 
#step:1 enable ip forwarding on qemu
ssh -q -o StrictHostKeyChecking=no  root@192.168.1.1 sysctl -w net.ipv4.ip_forward=1 
ssh -q -o StrictHostKeyChecking=no  root@192.168.1.1 sysctl -p  

#step:2 copy network configuration from host system to qemu
sudo ssh-keygen -f "/root/.ssh/known_hosts" -R 192.168.1.1
check_connectivity 192.168.1.1 22
sudo scp -o  StrictHostKeyChecking=no  config.reference/network root@192.168.1.1:/etc/config
ssh -q -o StrictHostKeyChecking=no  root@192.168.1.1 /etc/init.d/network restart
sleep 5
ssh -q -o StrictHostKeyChecking=no  root@192.168.1.1 route add default gw 172.16.16.234 
#ssh -q -o StrictHostKeyChecking=no  root@192.168.1.1 ls -l /etc/config
#Changes on host system to route the traffic
#step 3: network configuration on host system, to route through router- Qemu-openwrt
sudo ifconfig eth0 172.16.16.61 netmask 255.255.255.0 up
sudo ifconfig bridge0 down
sudo ifconfig bridge0 up
sudo brctl addif bridge0 tap1
sudo brctl addif bridge0 eth0
sudo route add default gw 192.168.1.1
#check internet conectivity from host
##Network
##Host -> router --> internet
##192.168.1.2(Host)-> 192.168.1.1(router-brlan)--172.16.16.200(router-brwan->172.16.16.234(Router's Gateway)-->  4.2.2.2

##step 4: Check the host connectivity to gateway
ping -c 1 192.168.1.1 >> qemu.log
        if [ `echo $?` -eq 0 ]
        then
                echo "Test1### Pass ###  Host's Gateway(Router-192.168.1.1)  is reachable " >> logs/Test_Result.log
        else
	echo "Test1### Fail ### Host's Gateway (Router-192.168.1.1) is Timed out ........ " >> logs/Test_Result.log
        fi
##step 2: Check the qemu connectivity to gateway
ssh -q -o StrictHostKeyChecking=no  root@192.168.1.1 ping -c 1 172.16.16.234
        if [ `echo $?` -eq 0 ]
        then
                echo "Test2### Pass ###Gateway of Router is reachable " >> logs/Test_Result.log
        else
	echo "Test2### Fail ###Gateway of Router is Timed out ........ " >> logs/Test_Result.log
        fi
##step 3: Check the qemu connectivity to internet
ssh -q -o StrictHostKeyChecking=no  root@192.168.1.1 ping -c 1 4.2.2.2
        if [ `echo $?` -eq 0 ]
        then
                echo "Test3### Pass ###Internet from is reachable from Router " >> logs/Test_Result.log
        else
	echo "Test3### Fail ###Internet from is Timed out fromRouter ........ " >> logs/Test_Result.log
        fi
##step 4: Check the host connectivity to internet
ping -c 1 4.2.2.2 >> qemu.log
        if [ `echo $?` -eq 0 ]
        then
                echo "Test4### Pass ###Internet is reachable from host " >> logs/Test_Result.log
        else
	echo "Test4### Fail ###Internet is Timed out from host ........ " >> logs/Test_Result.log
        fi
