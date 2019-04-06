/*
 * functions.h
 *
 *  Created on: Mar 21, 2019
 *      Author: ilijap
 */

#ifndef FUNCTIONS_H_
#define FUNCTIONS_H_

#include "stdio.h"
#include "system.h"
#include "stdlib.h"
#include "string.h"
#include "altera_hostfs.h"
#include "altera_avalon_performance_counter.h"
#include "alt_types.h"
#include "math.h"

#define MAX_HISTOGRAM_VALUE (255)
#define MAX_HISTOGRAM_VALUE_FLOAT (255.0f)


void hist(alt_u8* image,alt_u32 width, alt_u32 height, alt_u32 left_up_corner_x, alt_u32 left_up_corner_y, alt_u32 right_down_corner_x,alt_u32 right_down_corner_y, alt_u32** hist_value);

void cumsum(alt_u32* hist, alt_u32 width, alt_u32 height, alt_u32** cuml);


#endif /* FUNCTIONS_H_ */
