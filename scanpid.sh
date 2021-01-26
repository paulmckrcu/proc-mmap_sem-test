#!/bin/bash
# SPDX-License-Identifier: GPL-2.0+
#
# Repeatedly scan /proc/PID/smaps to see if /proc scans can interfere
# with mapping operations.
#
# Usage: scanpid.sh PID
#
# Copyright (C) Facebook, 2021
#
# Authors: Paul E. McKenney <paulmck@kernel.org>

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
