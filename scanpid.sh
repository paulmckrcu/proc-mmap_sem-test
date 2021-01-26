#!/bin/bash

pid=$1

while :
do
	if cat /proc/$pid/smaps > /dev/null 2>&1
	then
		:
	else
		echo scanpid.sh PID $$: /proc/$pid/smaps does not exist `date`
		break
	fi
done
