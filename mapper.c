// SPDX-License-Identifier: GPL-2.0+
/*
 * Program to map a large region of anonymous memory, then repeatedly
 * unmap and remap one-page portions of that region.  This is used with
 * a set of scripts to determine whether /proc scan can block mapping
 * operations.
 */

#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <time.h>
#include <errno.h>
#include <stdarg.h>
#include <stdint.h>
#include <limits.h>
#include <string.h>
#include <sys/mman.h>
#include <sys/stat.h>

#define MAP_REGION_SIZE (128 * 1024 * 1024) // sysctl vm.max_map_count for larger.

int duration = 10;
long region_size = MAP_REGION_SIZE;
void *mrp;
int pagesize;
char *waitfile;

// Get current time in nanoseconds since some random time in the past.
long long curtime2ns(void)
{
	struct timespec curspec;
	int retval;

	if (clock_gettime(CLOCK_MONOTONIC, &curspec)) {
		retval = errno;
		perror("initial clock_gettime");
		exit(retval);
	}
	return curspec.tv_sec * 1000LL * 1000LL * 1000LL + curspec.tv_nsec;
}

// If --waitfile was specified, wait for that file to be removed.
void waitfiledeletion(int argc, char *argv[])
{
	struct stat statbuf;

	if (!waitfile)
		return;
	while (!stat(waitfile, &statbuf))
		sleep(1);
}

// Repeatedly unmap and remap pages in the mapped region, tracking the
// duration in nanoseconds of the longest-duration operation.
int remapit(int argc, char *argv[])
{
	void *addr;
	long nmaps = 0;
	long nunmaps = 0;
	unsigned long offset;
	long long opbegin;
	long long opdur;
	long long opmax = 0LL;
	long long opsum = 0LL;
	void *retaddr;
	int retval;
	long long stoptime;
	struct timespec ts = { .tv_sec = 0, .tv_nsec = 10 * 1000L };

	stoptime = curtime2ns() + duration * 1000LL * 1000LL * 1000LL;

	while (curtime2ns() < stoptime) {
		offset = random() & (region_size - 1) & ~(pagesize - 1);
		addr = ((char *)mrp) + offset;
		opbegin = curtime2ns();
		if (random() & 0x8) {
			retaddr = mmap(addr, pagesize, PROT_WRITE,
				       MAP_FIXED | MAP_ANONYMOUS | MAP_PRIVATE | MAP_POPULATE,
				       -1, 0);
			if (retaddr == MAP_FAILED) {
				retval = errno;
				perror("mmap fixed");
				exit(retval);
			}
			if (retaddr != addr) {
				fprintf(stderr, "Remap address mismatch: %p vs. %p\n",
					retaddr, addr);
				exit(-1);
			}
			nmaps++;
		} else {
			if (munmap(addr, pagesize)) {
				retval = errno;
				perror("munmap");
				exit(retval);
			}
			nunmaps++;
		}
		opdur = curtime2ns() - opbegin;
		if (opdur > opmax)
			opmax = opdur;
		opsum += opdur;
		if (nanosleep(&ts, NULL)) {
			if (errno != EINTR) {
				perror("nanosleep");
				exit(1);
			}
		}
	}
	printf("%s: Map region: %#lx duration: %d nmaps: %ld nunmaps: %ld opmax: %.3f ms opavg: %.3f ms\n",
	       argv[0], (uintptr_t)mrp, duration, nmaps, nunmaps, opmax / 1000. / 1000., opsum / (nmaps + nunmaps) / 1000. / 1000.);
	return 0;
}


void usage(char *progname, const char *format, ...)
{
	va_list ap;

	va_start(ap, format);
	vfprintf(stderr, format, ap);
	va_end(ap);
	fprintf(stderr, "Usage: %s\n", progname);
	fprintf(stderr, "\t--duration\n");
	fprintf(stderr, "\t\tDuration of test in seconds.\n");
	fprintf(stderr, "\t--gb\n");
	fprintf(stderr, "\t\tRegion size in gigabytes.\n");
	fprintf(stderr, "\t--mb\n");
	fprintf(stderr, "\t\tRegion size in megabytes (Default of 128).\n");
	fprintf(stderr, "\t--waitfile\n");
	fprintf(stderr, "\t\tDon't start test until this file is removed.\n");
	exit(EINVAL);
}

int main(int argc, char *argv[])
{
	int i = 1;
	int retval = 0;
	int size_specified = 0;

	srandom(time(NULL));

	while (i < argc) {
		if (strcmp(argv[i], "--duration") == 0) {
			duration = strtol(argv[++i], NULL, 0);
			if (duration < 0)
				usage(argv[0],
				      "%s must be >= 0\n", argv[i - 1]);
		} else if (strcmp(argv[i], "--gb") == 0) {
			region_size = strtol(argv[++i], NULL, 0);
			if (size_specified)
				usage(argv[0],
				      "Only one of --gb and --mb may be specified");
			if (region_size < 0)
				usage(argv[0],
				      "%s must be >= 0\n", argv[i - 1]);
			if (LONG_MAX / 1024 / 1024 / 1024 < region_size)
				usage(argv[0],
				      "%s %d too large for address space\n", argv[i - 1], argv[i]);
			region_size = region_size * 1024 * 1024 * 1024;
			size_specified = 1;
		} else if (strcmp(argv[i], "--mb") == 0) {
			region_size = strtol(argv[++i], NULL, 0);
			if (size_specified)
				usage(argv[0],
				      "Only one of --gb and --mb may be specified");
			if (region_size < 0)
				usage(argv[0],
				      "%s must be >= 0\n", argv[i - 1]);
			if (LONG_MAX / 1024 / 1024 < region_size)
				usage(argv[0],
				      "%s %d too large for address space\n", argv[i - 1], argv[i]);
			region_size = region_size * 1024 * 1024;
			size_specified = 1;
		} else if (strcmp(argv[i], "--waitfile") == 0) {
			waitfile = argv[++i];
		} else {
			usage(argv[0], "Unrecognized argument: %s\n",
			      argv[i]);
		}
		i++;
	}

	pagesize = sysconf(_SC_PAGESIZE);
	printf("%s PID: %d duration: %d region size (pages): %ld\n",
	       argv[0], getpid(), duration, region_size / pagesize);
	mrp = mmap(NULL, region_size, PROT_WRITE,
		   MAP_ANONYMOUS | MAP_PRIVATE | MAP_POPULATE, -1, 0);
	if (mrp == MAP_FAILED) {
		retval = errno;
		perror("initial mmap");
		return retval;
	}
	waitfiledeletion(argc, argv);
	retval = remapit(argc, argv);
	return retval;
}
