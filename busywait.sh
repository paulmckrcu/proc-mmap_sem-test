#!/bin/bash

pid=$1

while test -f /proc/$pid/smaps
do
	:
done
