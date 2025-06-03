#!/bin/bash
# SPDX-License-Identifier: GPL-2.0+
#
# Run a series of proc-vs.map.sh tests and summarize the output.
#
# Usage: run-proc-vs-map.sh [ options [ -- proc-vs-map.sh options ]
#
# Copyright (C) Facebook, 2021
#
# Authors: Paul E. McKenney <paulmck@kernel.org>

scriptname=$0
args="$*"
echo "Running $scriptname $args"

# Default!
nsamples=7
rawdata=0

usage () {
	echo "Usage: $scriptname optional arguments:"
	echo "       --nsamples (default $nsamples)"
	echo "       --help"
	echo "       --rawdata"
	echo "       -- proc-vs-map.sh options (no default)"
	exit 1
}

while test $# -gt 0
do
	case "$1" in
	--nsamples)
		nsamples=$2
		if echo $nsamples | grep -q '[^0-9]'
		then
			echo Error: $1 $2 non-numeric.
			usage
		fi
		shift
		;;
	--rawdata)
		rawdata=1
		;;
	--help|-h)
		usage
		;;
	--)
		shift
		break
		;;
	*)
		echo Unknown argument $1
		usage
		;;
	esac
	shift
done

for ((i = 0; i < $nsamples; i++))
do
	for n in 2
	do
		./proc-vs-map.sh "$@" --nbusycpus $n
	done
done 2>&1 | gawk -v rawdata="${rawdata}" '
/^ --- / {
	nbusytasks = $NF;
	terminated = 0;
}

/Terminated/ {
	terminated = 1;
}

/opmax:/ {
	n[nbusytasks]++;
	a[nbusytasks][n[nbusytasks]] = $(NF - 1);
	m[nbusytasks][n[nbusytasks]] = $(NF - 4);
	t[nbusytasks] += terminated;
}

END {
	if (!rawdata) {
		print "";
		print "          Average mmap()/munmap()";
		print "           latency (milliseconds)";
		print "         --------------------------";
		print "#Busy    Median   Minimum   Maximum #Hangs";
	}
	for (i in n) {
		n1 = asort(a[i]);
		n2 = asort(m[i]);
		if (n1 != n[i] || n1 != n2)
			print "!!! size mismatch: n[" i "] = " n[i] ", n1 = " n1, " n2 = " n2;
		h = int(n1 / 2);
		if (n1 == h * 2)
			med = (a[i][h + 1] + a[i][h]) / 2;
		else
			med = a[i][h + 1];
		if (!rawdata) {
			printf "%5d %9.3f %9.3f %9.3f %6s\n", i, med, a[i][1], m[i][n1], t[i] ? "*" t[i] : "";
		} else {
			print "";
			for (j = 1; j <= n[i]; j++)
				printf "%9.3f %9.3f %9.3f\n", med, a[i][j], m[i][j];
		}
	}
	print "";
}'
