#! /bin/sh
#
# Create plots from the RCU and locking data generated.
#
# Execute this script in the directory containing the data
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, you can access it online at
# http://www.gnu.org/licenses/gpl-2.0.html.
#
# Copyright (C) Meta Platforms, Inc. 2025
#
# Authors: Paul E. McKenney <paulmck@kernel.org>

fontsize=10
plotsize=0.5
medplotsize=0.75
bigplotsize=1.0

gnuplot << ---EOF---
set term postscript portrait ${fontsize}
set size square ${plotsize},${plotsize}
set output "proc-scan-wc.eps"
set xlabel "Run Number"
# set xtics rotate
set ylabel "Maximum mmap() Latency (Milliseconds)"
set style data lines
# set logscale y
set nokey
set label 1 "mm" at 90,4 r
set label 2 "lockless" at 80,.5 r
set yrange [0:]
plot "mm.dat" w l, "mm.dat" w e, "lockless.dat" w l, "lockless.dat" w e
set size 1,1
set term png large
set output "proc-scan-wc.png"
replot
---EOF---

awk < lockless.dat > lockless-med.dat '{ print $1, $3 }'
awk < mm.dat > mm-med.dat '{ print $1, $3 }'

gnuplot << ---EOF---
set term postscript portrait ${fontsize}
set size square ${plotsize},${plotsize}
set output "proc-scan-med.eps"
set xlabel "Run Number"
# set xtics rotate
set ylabel "Maximum mmap() Latency (Milliseconds)"
set style data lines
# set logscale y
set nokey
set label 1 "mm" at 90,4 r
set label 2 "lockless" at 80,.5 r
set yrange [0:]
plot "mm-med.dat" w l, "lockless-med.dat" w l
set size 1,1
set term png large
set output "proc-scan-med.png"
replot
---EOF---

awk < mm-med.dat '
{
	d[NR] = $2
}

END {
	if (NR % 2)
		print "Median mm: " d[(NR + 1) / 2]; 
	else
		print "Median mm: " (d[NR / 2] + d[NR / 2 + 1]) / 2; 
}'

awk < lockless-med.dat '
{
	d[NR] = $2
}

END {
	if (NR % 2)
		print "Median lockless: " d[(NR + 1) / 2]; 
	else
		print "Median lockless: " (d[NR / 2] + d[NR / 2 + 1]) / 2; 
}'
