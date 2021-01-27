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

scriptname=$0
args="$*"
ncpus="`lscpu | grep '^CPU(s):' | awk '{ print $2 }'`"
if test "$ncpus" -lt 2
then
	echo Need at least two CPUs, and ncpus = $ncpus
	exit 1
fi

echo " --- $scriptname $args"

# Defaults:
cpubusytasks=2
cpumapper=0
cpuscript=1
duration=10
nbusytasks=20

usage () {
	echo "Usage: $scriptname optional arguments:"
	echo "       --cpubusytasks CPU# (default $cpubusytasks)"
	echo "       --cpumapper CPU# (default $cpumapper)"
	echo "       --cpuscript CPU# (default $cpuscript)"
	echo "       --duration seconds (default $duration)"
	echo "       --help"
	echo "       --nbusytasks # (default $nbusytasks)"
	exit 1
}

while test $# -gt 0
do
	case "$1" in
	--cpubusytasks)
		cpubusytasks=$2
		if echo $cpubusytasks | grep -q '[^0-9]'
		then
			echo Error: $1 $2 non-numeric.
			usage
		fi
		shift
		;;
	--cpumapper)
		cpumapper=$2
		if echo $cpumapper | grep -q '[^0-9]'
		then
			echo Error: $1 $2 non-numeric.
			usage
		fi
		shift
		;;
	--cpuscript)
		cpuscript=$2
		if echo $cpuscript | grep -q '[^0-9]'
		then
			echo Error: $1 $2 non-numeric.
			usage
		fi
		shift
		;;
	--duration)
		duration=$2
		if echo $duration | grep -q '[^0-9]'
		then
			echo Error: $1 $2 non-numeric.
			usage
		fi
		shift
		;;
	--help|-h)
		usage
		;;
	--nbusytasks)
		nbusytasks=$2
		if echo $nbusytasks | grep -q '[^0-9]'
		then
			echo Error: $1 $2 non-numeric.
			usage
		fi
		shift
		;;
	*)
		echo Unknown argument $1
		usage
		;;
	esac
	shift
done

if test "$cpumapper" -eq "$cpubusytasks"
then
	echo Running ./mapper and the busy scripts on CPU $cpumapper!!!
	echo '    ' This can result in false positives.
fi

if test "$cpubusytasks" -eq "$cpuscript"
then
	echo Running the main script and the busy scripts on CPU $cpumapper!!!
	echo '    ' This can result in test hangs.
fi

T=/tmp/proc-vs-map.sh.$$
trap 'rm -rf $T' 0 2
mkdir $T

echo Starting ${duration}-second test at `date`.

# Launch the mapper.
maskmapper="`echo $cpuscript |
	     awk '{ z = ""; for (i = 1; 4 * i <= $1; i++) z = z "0"; print "0x" 2 ^ ($1 % 4) z }'`"
taskset -p $maskmapper $$
taskset -c $cpumapper ./mapper --duration $duration > $T/mapper.out &
mapper_pid=$!

# Launch the /proc scanners at low priority.
busy_pids=
i=0
while test $i -lt $nbusytasks
do
	taskset -c $cpubusytasks nice -n 15 ./scanpid.sh $mapper_pid > $T/scanpid.sh.$i.out 2>&1 &
	busy_pids="$busy_pids $!"
	i=$((i+1))
done

sleep 1

# Launch higher-priority busy-waiters.
i=0
while test $i -lt $nbusytasks
do
	taskset -c $cpubusytasks ./busywait.sh $mapper_pid &
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
	if test -f $i
	then
		head -n -1 $i > $T/scanpid.sh.summary
	fi
done
if test -s $T/scanpid.sh.summary
then
	echo --- scanpid.sh output:
	cat $T/scanpid.sh.summary
	echo --- mapper output:
fi
cat $T/mapper.out
