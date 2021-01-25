#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <time.h>
#include <errno.h>
#include <stdint.h>
#include <sys/mman.h>

#define MAP_REGION_SIZE (128 * 1024 * 1024) // sysctl vm.max_map_count for larger.

int duration = 10;
void *mrp;
int pagesize;

void usage(int argc, char *argv[])
{
	fprintf(stderr, "Usage: %s [ duration (s) ]\n", argv[0]);
	exit(EINVAL);
}

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

int main(int argc, char *argv[])
{
	int retval = 0;

	srandom(time(NULL));

	if (argc == 2) {
		duration = strtol(argv[1], NULL, 0); 
		if (duration < 0) {
			fprintf(stderr, "Negative runtime of %d disallowed.\n", duration);
			usage(argc, argv);
		}
	} else if (argc > 2) {
		fprintf(stderr, "Too many command-line arguments.\n");
		usage(argc, argv);
	}
	printf("duration = %d\n", duration);

	pagesize = sysconf(_SC_PAGESIZE);
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
