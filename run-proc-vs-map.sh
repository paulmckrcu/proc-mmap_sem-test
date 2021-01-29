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

usage () {
	echo "Usage: $scriptname optional arguments:"
	echo "       --nsamples (default $nsamples)"
	echo "       --help"
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
	for n in 0 1 10 100 1000
	do
		./proc-vs-map.sh "$@" --nbusytasks $n
	done
done 2>&1 | awk '
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
	t[nbusytasks] += terminated;
}

END {
	for (i in n) {
		n1 = asort(a[i]);
		if (n1 != n[i])
			print "!!! size mismatch: n[" i "] = " n[i] ", n1 = " n1;
		h = int(n1 / 2);
		if (n1 == h * 2)
			med = (a[i][h + 1] + a[i][h]) / 2;
		else
			med = a[i][h + 1];
		print i, med, a[i][1], a[i][n1], t[i] ? "*" t[i] : "";
	}
}' | sort -k1n
