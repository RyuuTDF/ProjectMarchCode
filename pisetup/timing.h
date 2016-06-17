/*
 * timing.h
 *
 *  Created on: 7 Jun 2016
 *      Author: ruben
 */

#ifndef TIMING_H_
#define TIMING_H_

#include <time.h>

/**
 * Returns the current time in microsecond resolution. Suitable for performance timing.
 */
static long get_micros() {
	struct timespec ts;
	timespec_get(&ts, TIME_UTC);
	return (long) ts.tv_sec * 1000000L + ts.tv_nsec / 1000L;
}

#endif /* TIMING_H_ */

