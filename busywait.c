// SPDX-License-Identifier: GPL-2.0+
//
// Provide higher-priority busy waiting as part of the check as to whether
// /proc scans can interfere with mapping operations.  If --busyduration
// greater than zero, there is a one-millisecond sleep between busy periods.
//
// Usage: busywait.sh PID
//
// Copyright (C) Facebook, 2025
//
// Authors: Paul E. McKenney <paulmck@kernel.org>

#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <poll.h>
#include <time.h>
#include <errno.h>
#include <stdarg.h>
#include <stdint.h>
#include <limits.h>
#include <string.h>

int busyduration = 0;

unsigned long long current_time_us(void)
{
	struct timespec t;

	if (clock_gettime(CLOCK_MONOTONIC_RAW, &t) != 0)
		abort();
	return ((unsigned long long)t.tv_sec * 1000000000ULL +
	        (unsigned long long)t.tv_nsec) / 1000ULL;
}

void usage(char *progname, const char *format, ...)
{
	va_list ap;

	va_start(ap, format);
	vfprintf(stderr, format, ap);
	va_end(ap);
	fprintf(stderr, "Usage: %s\n", progname);
	fprintf(stderr, "\t--busyduration\n");
	fprintf(stderr, "\t\tDuration of busy period in milliseconds (default disabled=0).\n");
	exit(EINVAL);
}

int main(int argc, char *argv[])
{
	int i = 1;
	unsigned long long ts;
	unsigned long long te;

#ifdef TEST
	ts = current_time_us();
	poll(NULL, 0, 1); // Sleep for a millisecond.
	te = current_time_us();
	printf("One-millisecond delta = %llu.\n", te - ts);
#endif // #ifdef TEST

	while (i < argc) {
		if (strcmp(argv[i], "--busyduration") == 0) {
			busyduration = strtol(argv[++i], NULL, 0);
			if (busyduration < 0)
				usage(argv[0],
				      "%s must be >= 0\n", argv[i - 1]);
		} else {
			usage(argv[0], "Unrecognized argument: %s\n",
			      argv[i]);
		}
		i++;
	}

	for (;;) {
		ts = current_time_us();
		te = current_time_us();
		ts += busyduration * 1000; // Convert to microseconds for current_time_us().
		while (busyduration == 0 || (long long)(te - ts) < 0)
			te = current_time_us();
		poll(NULL, 0, 1); // Sleep for a millisecond.
	}
	
	return 0;
}
