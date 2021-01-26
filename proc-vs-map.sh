#!/bin/bash
# SPDX-License-Identifier: GPL-2.0+
#
# Check whether /proc scans can interfere with mapping operations.
#
# Usage: proc-vs-map.sh [ options ]
#
# Copyright (C) Facebook, 2021
#
# Authors: Paul E. McKenney <paulmck@kernel.org>

duration=${1-5}
ncpus="`lscpu | grep '^CPU(s):' | awk '{ print $2 }'`"
if test "$ncpus" -lt 2
then
	echo Need at least two CPUs, and ncpus = $ncpus
	exit 1
fi
nbusytasks=20

T=/tmp/proc-vs-map.sh.$$
trap 'rm -rf $T' 0 2
mkdir $T

echo Starting ${duration}-second test at `date`.

# Launch the mapper.
taskset -p 0x1 $$
taskset -c 0 ./mapper --duration $duration > $T/mapper.out &
mapper_pid=$!

# Launch the /proc scanners at low priority.
busy_pids=
i=0
while test $i -lt $nbusytasks
do
	taskset -c 2 nice -n 15 ./scanpid.sh $mapper_pid > $T/scanpid.sh.$i.out 2>&1 &
	busy_pids="$busy_pids $!"
	i=$((i+1))
done

sleep 1

# Launch higher-priority busy-waiters.
i=0
while test $i -lt $nbusytasks
do
	taskset -c 2 ./busywait.sh $mapper_pid &
	busy_pids="$busy_pids $!"
	i=$((i+1))
done

# Normally, procscan.sh and busywait.sh will stop as soon as the mapper
# process stops because its /proc/PID/smaps file will vanish.  But if
# more convincing is needed, this code does that convincing.
sleep $duration
if test -f /proc/$mapper_pid/smaps
then
	echo ./mapper still running, so giving it another five seconds.
	sleep 5
	if test -f /proc/$mapper_pid/smaps
	then
		echo ./mapper STILL running, so kill busy-wait PIDs.
		kill $busy_pids
	fi
fi

# Dump the statistics.
for i in $T/scanpid.sh.*.out
do
	head -n -1 $i > $T/scanpid.sh.summary
done
if test -s $T/scanpid.sh.summary
then
	echo --- scanpid.sh output:
	cat $T/scanpid.sh.summary
	echo --- mapper output:
fi
cat $T/mapper.out
