#!/bin/bash

duration=${1-5}
ncpus="`lscpu | grep '^CPU(s):' | awk '{ print $2 }'`"
if test "$ncpus" -lt 2
then
	echo Need at least two CPUs, and ncpus = $ncpus
	exit 1
fi
nbusytasks=5

T=/tmp/proc-vs-map.sh.$$
trap 'rm -rf $T' 0 2
mkdir $T

echo Starting ${duration}-second test at `date`.

taskset -p 0x1 $$
taskset -c 0 ./mapper --duration $duration > $T/mapper.out &
mapper_pid=$!
echo "(Expect $nbusytasks complaints from scanpid.sh about /proc/$mapper_pid/smaps at end of test.)"

busy_pids=
i=0
while test $i -lt $nbusytasks
do
	taskset -c 2 nice -n 15 ./scanpid.sh $mapper_pid &
	busy_pids="$busy_pids $!"
	i=$((i+1))
done

sleep 1

i=0
while test $i -lt $nbusytasks
do
	taskset -c 2 nice -n 10 ./busywait.sh &
	busy_pids="$busy_pids $!"
	i=$((i+1))
done

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

cat $T/mapper.out
