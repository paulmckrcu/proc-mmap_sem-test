#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <time.h>
#include <errno.h>
#include <stdint.h>
#include <sys/mman.h>

#define MAP_REGION_SIZE (1024 * 1024 * 1024)

int duration = 10;

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

int remapit(void)
{
	long long curtime;
	int retval;
	long long stoptime;

	stoptime = curtime2ns() + duration * 1000LL * 1000LL * 1000LL;

	while (curtime2ns() < stoptime)
		sleep(1);
	return 0;
}

int main(int argc, char *argv[])
{
	int retval = 0;
	void *mrp;

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

	mrp = mmap(NULL, MAP_REGION_SIZE, PROT_WRITE,
		   MAP_ANONYMOUS | MAP_PRIVATE | MAP_POPULATE, -1, 0);
	if (mrp == MAP_FAILED) {
		retval = errno;
		perror("initial mmap");
		return retval;
	}
	printf("Map region at %#lx\n", (uintptr_t)mrp);
	retval = remapit();
	return retval;
}

// How to stop?
// 1. Catch a signal.
// 2. Take a run duration as a command-line argument.
