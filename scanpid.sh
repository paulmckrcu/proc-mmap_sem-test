#!/bin/bash
# SPDX-License-Identifier: GPL-2.0+
#
# Repeatedly scan /proc/PID/procfile to see if /proc scans can interfere
# with mapping operations.
#
# Usage: scanpid.sh PID procfile
#
# Copyright (C) Facebook, 2021
#
# Authors: Paul E. McKenney <paulmck@kernel.org>

pid=$1
procfile=${2-maps}

while :
do
	if cat /proc/$pid/$procfile > /dev/null 2>&1
	then
		:
	else
		echo scanpid.sh PID $$: /proc/$pid/$procfile does not exist `date`
		break
	fi
done
