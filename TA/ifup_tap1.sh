#!/bin/sh

ifconfig $1 192.168.7.2 netmask 255.255.255.0
#brctl addbr br0
#brctl addif br0 $1

exit 0
