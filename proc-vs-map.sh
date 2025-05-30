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
busyduration=0
cpubusytasks=2
cpumapper=0
cpuscript=1
duration=10
mempar=
nbusycpus=1
nbusytasks=1
procfile=maps

usage () {
	echo "Usage: $scriptname optional arguments:"
	echo "       --busyduration millseconds (default $busyduration)"
	echo "       --cpubusytasks CPU# (default $cpubusytasks)"
	echo "       --cpumapper CPU# (default $cpumapper)"
	echo "       --cpuscript CPU# (default $cpuscript)"
	echo "       --duration seconds (default $duration)"
	echo "       --gb gigabytes"
	echo "       --help"
	echo "       --mb megabytes"
	echo "       --nbusycpus # (default $nbusycpus)"
	echo "       --nbusytasks # (default $nbusytasks per CPU)"
	echo "       --procfile # (default $procfile)"
	exit 1
}

while test $# -gt 0
do
	case "$1" in
	--busyduration)
		busyduration=$2
		if echo $busyduration | grep -q '[^0-9]'
		then
			echo Error: $1 $2 non-numeric.
			usage
		fi
		shift
		;;
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
	--gb|--mb)
		if test -n "$mempar"
		then
			echo Error: Only one instance of --gb and --mb may be specified.
			usage
		fi
		if echo $2 | grep -q '[^0-9]'
		then
			echo Error: $1 $2 non-numeric.
			usage
		fi
		mempar="$1 $2"
		shift
		;;
	--help|-h)
		usage
		;;
	--nbusycpus)
		nbusycpus=$2
		if echo $nbusycpus | grep -q '[^0-9]'
		then
			echo Error: $1 $2 non-numeric.
			usage
		fi
		shift
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
	--procfile)
		procfile=$2
		if echo $procfile | grep -q '/' || ! test -f /proc/$$/"$procfile"
		then
			echo Error: $1 $2 is not a /proc/PID file.
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

if test "$cpumapper" -ge "$cpubusytasks" && test "$cpumapper" -lt "$((cpubusytasks+nbusycpus))"
then
	echo Running ./mapper and the busy scripts on CPU $cpumapper!!!
	echo '    ' This can result in false positives.
fi

if test "$cpubusytasks" -eq "$cpuscript"
then
	echo Running the main script and the busy scripts on CPU $cpumapper!!!
	echo '    ' This can result in test hangs.
fi

T="`mktemp -d ${TMPDIR-/tmp}/proc-vs-map.sh.XXXXXX`"
trap 'rm -rf $T' 0 2
mkdir $T

echo Starting ${duration}-second test at `date`.

# Launch the mapper.
W="$T/waitfile"
touch "$W"
maskmapper="`echo $cpuscript |
	     awk '{ z = ""; for (i = 1; 4 * i <= $1; i++) z = z "0"; print "0x" 2 ^ ($1 % 4) z }'`"
taskset -p $maskmapper $$
taskset -c $cpumapper ./mapper --duration $duration --waitfile "$W" $mempar > $T/mapper.out &
mapper_pid=$!

# Launch the /proc scanners at low priority.
busy_pids=
curcpu=$cpubusytasks
while test $curcpu -lt $((cpubusytasks+nbusycpus))
do
	i=0
	while test $i -lt $nbusytasks
	do
		taskset -c $curcpu nice -n 15 ./scanpid.sh $mapper_pid $procfile > $T/scanpid.sh.$i.out 2>&1 &
		busy_pids="$busy_pids $!"
		i=$((i+1))
	done
	curcpu=$((curcpu+1))
done

sleep 1

# Launch higher-priority busy-waiters.
curcpu=$cpubusytasks
while test $curcpu -lt $((cpubusytasks+nbusycpus))
do
	i=0
	while test $i -lt $nbusytasks
	do
		taskset -c $curcpu ./busywait --busyduration $busyduration --pid $mapper_pid &
		busy_pids="$busy_pids $!"
		i=$((i+1))
	done
	curcpu=$((curcpu+1))
done
rm "$W" # Now that everything is running, tell ./mapper to start testing.

# Normally, procscan.sh and busywait will stop as soon as the mapper
# process stops because its /proc/PID/$procfile file will vanish.  But if
# more convincing is needed, this code does that convincing.
sleep $duration
if test -f /proc/$mapper_pid/$procfile
then
	echo ./mapper still running, so giving it another five seconds.
	sleep 5
	if test -f /proc/$mapper_pid/$procfile
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
