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

#define MAP_REGION_SIZE (128 * 1024 * 1024) // sysctl vm.max_map_count for larger.

int duration = 10;
long region_size = MAP_REGION_SIZE;
void *mrp;
int pagesize;

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

int remapit(int argc, char *argv[])
{
	void *addr;
	long long curtime;
	long nmaps;
	long nunmaps;
	unsigned long offset;
	void *retaddr;
	int retval;
	long long stoptime;

	stoptime = curtime2ns() + duration * 1000LL * 1000LL * 1000LL;

	while (curtime2ns() < stoptime) {
		offset = random() & (MAP_REGION_SIZE - 1) & ~(pagesize - 1);
		addr = ((char *)mrp) + offset;
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
	}
	printf("%s: Map region: %#lx duration: %d nmaps: %ld nunmaps: %ld\n",
	       argv[0], (uintptr_t)mrp, duration, nmaps, nunmaps);
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
		} else {
			usage(argv[0], "Unrecognized argument: %s\n",
			      argv[i]);
		}
		i++;
	}

	pagesize = sysconf(_SC_PAGESIZE);
	printf("%s duration: %d region size (pages): %ld\n",
	       argv[0], duration, region_size / pagesize);
	mrp = mmap(NULL, MAP_REGION_SIZE, PROT_WRITE,
		   MAP_ANONYMOUS | MAP_PRIVATE | MAP_POPULATE, -1, 0);
	if (mrp == MAP_FAILED) {
		retval = errno;
		perror("initial mmap");
		return retval;
	}
	retval = remapit(argc, argv);
	return retval;
}

// How to stop?
// 1. Catch a signal.
// 2. Take a run duration as a command-line argument.
