#!/bin/bash

duration=5
ncpus="`lscpu | grep '^CPU(s):' | awk '{ print $2 }'`"

T=/tmp/proc-vs-map.sh.$$
trap 'rm -rf $T' 0 2
mkdir $T

echo Starting test `date`

./mapper --duration $duration > $T/mapper.out &
mapper_pid=$!
echo "(Expect one complaint per CPU from scanpid.sh about /proc/$mapper_pid/smaps.)"

i=0
while test $i -lt $ncpus
do
	taskset -c $i nice -n 15 ./scanpid.sh $mapper_pid &
	i=$((i+1))
done

sleep 1

i=0
while test $i -lt $ncpus
do
	taskset -c $i nice -n 10 ./busywait.sh &
	i=$((i+1))
done

sleep $duration

cat $T/mapper.out
