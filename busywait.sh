#!/bin/bash
# SPDX-License-Identifier: GPL-2.0+
#
# Provide higher-priority busy waiting as part of the check as to whether
# /proc scans can interfere with mapping operations.
#
# Usage: busywait.sh PID
#
# Copyright (C) Facebook, 2021
#
# Authors: Paul E. McKenney <paulmck@kernel.org>

pid=$1

while test -f /proc/$pid/smaps
do
	:
done
