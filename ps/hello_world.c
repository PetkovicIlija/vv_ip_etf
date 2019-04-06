/*
 * "Hello World" example.
 *
 * This example prints 'Hello from Nios II' to the STDOUT stream. It runs on
 * the Nios II 'standard', 'full_featured', 'fast', and 'low_cost' example
 * designs. It runs with or without the MicroC/OS-II RTOS and requires a STDOUT
 * device in your system's hardware.
 * The memory footprint of this hosted application is ~69 kbytes by default
 * using the standard reference design.
 *
 * For a reduced footprint version of this template, and an explanation of how
 * to reduce the memory footprint for a given application, see the
 * "small_hello_world" template.
 *
 */

#include "functions.h"

int main()
{
	FILE* input_file = NULL;
	//FILE* input_file1 = NULL;
	FILE* output_file = NULL;

	alt_u8 character[1];

	alt_u32 tmp;

	alt_u32 image_height = 0;

	alt_u32 image_width = 0;

	alt_u32* histogram;

	alt_u32* cumhist;

	alt_u8* picture;

	alt_u32 iterator = 0;

	alt_u32 iterator1 = 0;

	alt_u32 left_up_corner_x;

	alt_u32 left_up_corner_y;

	alt_u32 right_down_corner_x;

	alt_u32 right_down_corner_y;

	float coeficient;

	printf("START\n");


	input_file = fopen("/mnt/host/files/bright64.bin","r");
	//input_file1 = fopen("/mnt/host/files/orig64.bin","r");
	output_file = fopen("/mnt/host/files/output.bin","w");

	if(input_file == NULL)
	{

		printf("Input file can not be open\n");
		exit(1);


	}

//	if(input_file1 == NULL)
//	{
//
//		printf("Input file 1 can not be open\n");
//		exit(1);
//
//
//	}

	if(output_file == NULL)
	{

		printf("Output file can not be open\n");
		exit(1);


	}


	while(iterator < 4){

		fread(character,1,1,input_file);
		tmp = character[0];
		image_width += tmp << (iterator*8);
		iterator++;
		//fwrite(character,1,1,output_file);

	}

	iterator = 0;

	while(iterator < 4){

		fread(character,1,1,input_file);
		tmp = character[0];
		image_height += tmp << (iterator*8);
		iterator++;
		//fwrite(character,1,1,output_file);

	}



//	coeficient = MAX_HISTOGRAM_VALUE_FLOAT/(image_width*image_height);

//	printf("%u\n",(int)image_width);
//	printf("%u\n",(int)image_height);
//	printf("%f\n",coeficient);

	picture = (alt_u8*)malloc(image_width*image_height*sizeof(alt_u8));
//
//	histogram = (alt_u32*)calloc((MAX_HISTOGRAM_VALUE + 1),sizeof(alt_u32));
//
//	cumhist = (alt_u32*)calloc((MAX_HISTOGRAM_VALUE + 1),sizeof(alt_u32));
//
//	iterator = 0;
//
	while(iterator < image_width*image_height)
	{
		iterator++;

		fread(character,1,1,input_file);

		//histogram[(alt_u32)(character[0])]++;

		picture[iterator] = character[0];

	}

	left_up_corner_x = 0;
	left_up_corner_y = 0;
	right_down_corner_x = image_width-1;
	right_down_corner_y = image_height-1;

	hist(picture, image_width, image_height, left_up_corner_x, left_up_corner_y, right_down_corner_x, right_down_corner_y, &histogram);

	cumsum(histogram, right_down_corner_x - left_up_corner_x + 1, right_down_corner_y - left_up_corner_y + 1, &cumhist);

//
//
//	for (iterator = 0; iterator < MAX_HISTOGRAM_VALUE + 1;iterator++)
//	{
//		for (iterator1 = 0;iterator1 < iterator + 1;iterator1++)
//		{
//
//			cumhist[iterator] += histogram[iterator1];
//
//		}
//
//		cumhist[iterator] = (alt_u32)roundf(coeficient*cumhist[iterator]);
//
//	}


//	image_width = 0;
//	image_height = 0;
//	iterator = 0;
//
//	while(iterator < 4){
//
//		fread(character,1,1,input_file1);
//		tmp = character[0];
//		image_width += tmp << (iterator*8);
//		iterator++;
//		fwrite(character,1,1,output_file);
//
//	}
//
//	iterator = 0;
//
//	while(iterator < 4){
//
//		fread(character,1,1,input_file1);
//		tmp = character[0];
//		image_height += tmp << (iterator*8);
//		iterator++;
//		fwrite(character,1,1,output_file);
//
//	}


//	for(iterator = 0; iterator < image_width*image_height;iterator++)
//	{
//		fread(character,1,1,input_file1);
//		tmp = cumhist[(alt_u32)character[0]];
//		character[0] = tmp;
//		fwrite(character,1,1,output_file);
//
//	}

	for(iterator = 0;iterator < 256; iterator++)
	{
		for(iterator1 = 0;iterator1 < 4;iterator1++)
		{
			character[0] = (char)(cumhist[iterator] >> 8*iterator1);
			fwrite(character,1,1,output_file);
		}
	}

	printf("%u\n",(int)image_width);
	printf("%u\n",(int)image_height);


	free(picture);

	free(histogram);

	free(cumhist);

	fclose(input_file);

	//fclose(input_file1);

	fclose(output_file);

	printf("END!\n");

	return 0;
}
