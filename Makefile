# SPDX-License-Identifier: GPL-2.0+
#
# Simple Makefile
#
# Copyright (C) Facebook, 2021
#
# Authors: Paul E. McKenney <paulmck@kernel.org>

all: busywait mapper

busywait: busywait.c
	$(CC) -g -Wall -o busywait busywait.c

mapper: mapper.c
	$(CC) -g -Wall -o mapper mapper.c

check: mapper
	@echo This quick check runs for a couple of minutes.
	./run-proc-vs-map.sh --nsamples 3 -- --duration 3

test: mapper
	@echo This test runs for the better part of an hour.
	@echo But it does provide statistically defensible values.
	./run-proc-vs-map.sh --nsamples 24
