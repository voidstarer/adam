#!/bin/sh
current_time=`date`
ping -c 1 4.2.2.2 >> qemu.$current_time.log
        if [ `echo $?` -eq 0 ]
        then
                echo "Internet is reachable " >> qemu.`$current_time`.log
        else
        echo "Internet is Timed out ........ " >> qemu.`$current_time`.log
        fi

