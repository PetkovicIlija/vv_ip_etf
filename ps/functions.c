/*
 * functions.c
 *
 *  Created on: Mar 21, 2019
 *      Author: ilijap
 */

#include "functions.h"

void hist(alt_u8* image,alt_u32 width, alt_u32 height, alt_u32 left_up_corner_x, alt_u32 left_up_corner_y, alt_u32 right_down_corner_x,alt_u32 right_down_corner_y, alt_u32** hist_value)
{
	//int iterator = 0;
	alt_u32 y = right_down_corner_y - left_up_corner_y + 1;
	alt_u32 x = right_down_corner_x - left_up_corner_x + 1;
	alt_u32 index = 0;
	alt_u32 idx = 0;

	*hist_value = (alt_u32*)calloc((MAX_HISTOGRAM_VALUE + 1),sizeof(alt_u32));

	while(idx < y)
	{

		(*hist_value)[image[(left_up_corner_y + idx)*width + left_up_corner_x + index]]++;

		//iterator++;
		index++;
		if(index == x)
		{
			idx++;
			index = 0;
		}

	}

}

void cumsum(alt_u32* hist, alt_u32 width, alt_u32 height, alt_u8** cuml)
{
	int iterator = 0;
	int iterator1 = 0;
	float coeficient = MAX_HISTOGRAM_VALUE_FLOAT/(width*height);
	alt_u32 tmp = 0;

	*cuml = (alt_u8*)calloc((MAX_HISTOGRAM_VALUE + 1),sizeof(alt_u8));

	for (iterator = 0; iterator < MAX_HISTOGRAM_VALUE + 1;iterator++)
	{
		for (iterator1 = 0;iterator1 < iterator + 1;iterator1++)
		{

			tmp += hist[iterator1];

		}

		(*cuml)[iterator] = (alt_u8)roundf(coeficient*tmp);
		tmp = 0;

	}


}


