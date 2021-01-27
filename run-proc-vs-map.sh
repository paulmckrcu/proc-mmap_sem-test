#!/bin/bash
# SPDX-License-Identifier: GPL-2.0+
#
# Run a series of proc-vs.map.sh tests and summarize the output.
#
# Usage: run-proc-vs-map.sh
#
# Copyright (C) Facebook, 2021
#
# Authors: Paul E. McKenney <paulmck@kernel.org>

nsamples=5

for ((i = 0; i < $nsamples; i++))
do
	for n in 0 1 10 100 1000
	do
		./proc-vs-map.sh --nbusytasks $n
	done
done | awk '
/^ --- / {
	nbusytasks = $NF;
	terminated = " ";
}

/Terminated/ {
	terminated = "* "
}

/opmax:/ {
	a[nbusytasks] = a[nbusytasks] $(NF - 1) terminated;
}

END {
	for (i in a)
		print i, a[i];
}' | sort -k1n
