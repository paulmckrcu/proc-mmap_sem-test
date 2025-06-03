#!/bin/sh

# for i in 1 2 5 10
# do
	i=2
 	echo ./run-proc-vs-map.sh --nsamples 100 --rawdata -- --busyduration $i
 	./run-proc-vs-map.sh --nsamples 100 --rawdata -- --busyduration $i
# done
