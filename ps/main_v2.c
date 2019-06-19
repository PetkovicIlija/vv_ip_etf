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

#include "stdio.h"
#include "system.h"
#include "stdlib.h"
#include "string.h"
#include "altera_hostfs.h"

#include "alt_types.h"
#include "io.h"
#include "math.h"
#include "altera_avalon_sgdma_regs.h"
#include "altera_avalon_sgdma_descriptor.h"
#include "altera_avalon_sgdma.h"
#include "sys/alt_cache.h"
#include "functions.h"

//#include "altera_avalon_timer.h"
//#include "sys/alt_timestamp.h"


#define MAX_HISTOGRAM_VALUE (255)
#define MAX_HISTOGRAM_VALUE_FLOAT (255.0f)
#define MAX_NUM_DMA_TRANSFER (65535)
//#define NUMBER_OF_BUFFERS_REC (1)
#define NUMBER_OF_BUFFERS_CONF (1)

/* These will gate the data checking near the end of main */
volatile alt_u16 tx_done = 0;
volatile alt_u16 tx_conf_done = 0;
volatile alt_u16 rx_done = 0;

void transmit_callback_function(void * context)
{
  tx_done++;  /* main will be polling for this value being 1 */
}

void transmit_conf_callback_function(void * context)
{
	tx_conf_done++;  /* main will be polling for this value being 1 */
}


void receive_callback_function(void * context)
{
  rx_done++;  /* main will be polling for this value being 1 */
}

int main()
{

	FILE* input_file = NULL;
	FILE* output_file = NULL;
	FILE* input_file_pro = NULL;
	FILE* cumhist_file = NULL;
	alt_u32 iterator = 0;
	//alt_u32 iterator1 = 0;
	alt_u8 character[1];
	alt_u32 image_width = 0;
	alt_u32 image_height = 0;
	alt_u32 tmp = 0;
	alt_u8* image;
	alt_u32* histogram;
	//alt_u32* pom;
	alt_u8* cumhist;
	//alt_u32** hist_value;
	alt_u32 buffer_counter = 0;

	//alt_u32 tmp22;

	alt_u8 NUMBER_OF_BUFFERS_TRAN = 0;
	alt_u8 NUMBER_OF_BUFFERS_REC = 0;
    alt_u8 ** input_buffers;
    alt_u8 ** output_buffers;
    alt_u16 * buffer_lengths;

    alt_u32 it = 0;
    alt_u32 itr = 0;

	void * temp_ptr;

	alt_sgdma_dev* sgdma_m2s = alt_avalon_sgdma_open("/dev/sgdma_m2s");
	alt_sgdma_dev* sgdma_s2m = alt_avalon_sgdma_open("/dev/sgdma_s2m");
	alt_sgdma_dev* sgdma_m2s_conf = alt_avalon_sgdma_open("/dev/sgdma_m2s_conf");

	alt_sgdma_descriptor *m2s_desc_copy;
	alt_sgdma_descriptor *s2m_desc_copy;
	alt_sgdma_descriptor *m2s_conf_desc_copy;
	alt_sgdma_descriptor *transmit_descriptors, *receive_descriptors, *transmit_conf_descriptors;
	//alt_u32 tmp_start_time_hw, tmp_end_time_hw, tmp_start_time_sw, tmp_end_time_sw;

	input_file = fopen("/mnt/host/files/orig512.bin","r");
	output_file = fopen("/mnt/host/files/image.bin","w");
	input_file_pro = fopen("/mnt/host/files/bright64.bin","r");
	cumhist_file = fopen("/mnt/host/files/cumhist.txt","w");



	if(input_file == NULL)
	{

		printf("Input file can not be open\n");
		exit(1);


	}

	if(output_file == NULL)
	{

		printf("Output file can not be open\n");
		exit(1);


	}

	if(input_file_pro == NULL)
	{

		printf("Input file can not be open\n");
		exit(1);


	}


	if(sgdma_m2s == NULL)
	{
		printf("Could not open the transmit SG-DMA\n");
		return 1;
	}

	if(sgdma_s2m == NULL)
	{
		printf("Could not open the receive SG-DMA\n");
		return 1;
	}

	// READING DATA CALCULATING CUMULATING SUM

	// WIDTH
	while(iterator < 4){

		fread(character,1,1,input_file_pro);
		tmp = character[0];
		image_width += tmp << (iterator*8);
		iterator++;

	}

	iterator = 0;
	tmp = 0;

	// HEIGHT
	while(iterator < 4){

		fread(character,1,1,input_file_pro);
		tmp = character[0];
		image_height += tmp << (iterator*8);
		iterator++;

	}

	image = (alt_u8*)malloc(image_width*image_height*sizeof(alt_u8));

	iterator = 0;

	// READING IMAGE
	while(iterator < image_width*image_height)
	{

		fread(character,1,1,input_file_pro);
		image[iterator] = character[0];
		iterator++;


	}

	iterator = 0;


	// SOFTWARE
	hist(image,image_width, image_height, 0, 0, image_width-1, image_height-1, &histogram);

	cumsum(histogram, image_width, image_height, &cumhist);


	free(histogram);
	free(image);


	// READING DATA FOR PROCESSING
	// READING DATA

	image_width = 0;
	image_height = 0;
	tmp = 0;
	iterator = 0;
	while(iterator < 4){

		fread(character,1,1,input_file);
		tmp = character[0];
		image_width += tmp << (iterator*8);
		iterator++;

	}

	iterator = 0;
	tmp = 0;

	while(iterator < 4){

		fread(character,1,1,input_file);
		tmp = character[0];
		image_height += tmp << (iterator*8);
		iterator++;

	}

	//image = (alt_u8*)malloc(image_width*image_height*sizeof(alt_u8));

	// NUMBER_OF_BUFFERS
	NUMBER_OF_BUFFERS_TRAN += (image_width*image_height)/MAX_NUM_DMA_TRANSFER;
	NUMBER_OF_BUFFERS_REC += (image_width*image_height)/MAX_NUM_DMA_TRANSFER;
	if(image_width*image_height % MAX_NUM_DMA_TRANSFER > 0)
	{

		NUMBER_OF_BUFFERS_TRAN++;
		NUMBER_OF_BUFFERS_REC++;

	}

	printf("NUMBER_OF_BUFFERS_TRAN = %u\n",NUMBER_OF_BUFFERS_TRAN);
	//printf("dvgnfgnfjkgnfjnhf");

	buffer_lengths = (alt_u16 *)malloc(NUMBER_OF_BUFFERS_TRAN*sizeof(alt_u16));
	//printf("prosao");

	if(buffer_lengths == NULL)
	{
		printf("Bad alloc of 'buffer_lengths' \n");
		exit(1);
	}

	if(NUMBER_OF_BUFFERS_TRAN == 1)
	{
		buffer_lengths[0] = image_width*image_height;
		printf("buffer_lengths[%d] = %u\n",0,buffer_lengths[0]);
	}
	else
	{
		for(it = 0;it < NUMBER_OF_BUFFERS_TRAN - 1;it++)
		{
			buffer_lengths[it] = MAX_NUM_DMA_TRANSFER;
			printf("buffer_lengths[%d] = %u\n",it,buffer_lengths[it]);
		}
		buffer_lengths[NUMBER_OF_BUFFERS_TRAN - 1] = image_width*image_height - (NUMBER_OF_BUFFERS_TRAN - 1)*MAX_NUM_DMA_TRANSFER;
		printf("buffer_lengths[%d] = %u\n",NUMBER_OF_BUFFERS_TRAN - 1,buffer_lengths[NUMBER_OF_BUFFERS_TRAN - 1]);
	}

	// Allocation of array of input buffers
	input_buffers = (alt_u8**)malloc(NUMBER_OF_BUFFERS_TRAN*sizeof(alt_u8*));
	output_buffers = (alt_u8**)malloc(NUMBER_OF_BUFFERS_TRAN*sizeof(alt_u8*));
	if(input_buffers == 0)
	{
		printf("Bad alloc 'input buffers'\n");
		exit(1);
	}

	if(output_buffers == 0)
	{
		printf("Bad alloc 'input buffers'\n");
		exit(1);
	}
	// Allocation of buffers
	for(it = 0;it < NUMBER_OF_BUFFERS_TRAN;it++)
	{
		input_buffers[it] = (alt_u8*)malloc(buffer_lengths[it]*sizeof(alt_u8));
		if(input_buffers[it] == 0)
		{
			printf("Bad alloc 'input buffers[%d]'\n",it);
			exit(1);

		}
		output_buffers[it] = (alt_u8*)malloc(buffer_lengths[it]*sizeof(alt_u8));
		if(output_buffers[it] == 0)
		{
			printf("Bad alloc 'input buffers[%d]'\n",it);
			exit(1);

		}

	}

	//iterator = 0;
	for(it = 0;it < NUMBER_OF_BUFFERS_TRAN;it++)
	{
		for(itr = 0;itr < buffer_lengths[it];itr++)
		{
			fread(character,1,1,input_file);
			input_buffers[it][itr] = character[0];
			//image[iterator] = character[0];
			//iterator++;
		}
	}


	// DMA PROCESSING
	if(sgdma_m2s == NULL)
	{
		printf("Could not open the transmit SG-DMA\n");
		return 1;
	}

	if(sgdma_s2m == NULL)
	{
		printf("Could not open the receive SG-DMA\n");
		return 1;
	}

	if(sgdma_m2s_conf == NULL)
	{
		printf("Could not open the transmit configure SG-DMA\n");
		return 1;
	}

	// ALOCATION OF TRANCIVE DESCRIPTORS --> M2S
	temp_ptr = malloc((NUMBER_OF_BUFFERS_TRAN + 2) * ALTERA_AVALON_SGDMA_DESCRIPTOR_SIZE);

	if(temp_ptr == NULL)
	{
		printf("Failed to allocate memory for the transmit descriptors\n");
	    return 1;
	}

	m2s_desc_copy = (alt_sgdma_descriptor*)temp_ptr;

	while((((alt_u32)temp_ptr) % ALTERA_AVALON_SGDMA_DESCRIPTOR_SIZE) != 0)
	{
		temp_ptr++;
	}

	transmit_descriptors = (alt_sgdma_descriptor *)temp_ptr;


	transmit_descriptors[NUMBER_OF_BUFFERS_TRAN].control = 0;

	// ALLOCATION OF RECEIVE DESCRIPTORS
	temp_ptr = malloc((NUMBER_OF_BUFFERS_REC + 2) * ALTERA_AVALON_SGDMA_DESCRIPTOR_SIZE);

	if(temp_ptr == NULL)
	{
		printf("Failed to allocate memory for the transmit descriptors\n");
	    return 1;
	}

	s2m_desc_copy = (alt_sgdma_descriptor*)temp_ptr;

	while((((alt_u32)temp_ptr) % ALTERA_AVALON_SGDMA_DESCRIPTOR_SIZE) != 0)
	{
		temp_ptr++;
	}

	receive_descriptors = (alt_sgdma_descriptor *)temp_ptr;


	receive_descriptors[NUMBER_OF_BUFFERS_REC].control = 0;


	// ALLOCATION FOR TRANSMITION DESCRIPTORS FOR CONFIGURATION
	temp_ptr = malloc((NUMBER_OF_BUFFERS_CONF + 2) * ALTERA_AVALON_SGDMA_DESCRIPTOR_SIZE);

	if(temp_ptr == NULL)
	{
		printf("Failed to allocate memory for the transmit descriptors\n");
	    return 1;
	}

	m2s_conf_desc_copy = (alt_sgdma_descriptor*)temp_ptr;

	while((((alt_u32)temp_ptr) % ALTERA_AVALON_SGDMA_DESCRIPTOR_SIZE) != 0)
	{
		temp_ptr++;
	}

	transmit_conf_descriptors = (alt_sgdma_descriptor *)temp_ptr;


	transmit_conf_descriptors[NUMBER_OF_BUFFERS_CONF].control = 0;


	// PROCESSING

	// Descriptors

	// Transmition data
	for(buffer_counter = 0;buffer_counter < NUMBER_OF_BUFFERS_TRAN; buffer_counter++)
	{
		alt_avalon_sgdma_construct_mem_to_stream_desc(&transmit_descriptors[buffer_counter],
													  &transmit_descriptors[buffer_counter + 1],
													  (alt_u32*) input_buffers[buffer_counter],
													  (alt_u16) buffer_lengths[buffer_counter],
													  0,
													  0,
													  0,
													  0
		);
	}

	// Reciving processed data
	for(buffer_counter = 0;buffer_counter < NUMBER_OF_BUFFERS_REC; buffer_counter++)
	{
		alt_avalon_sgdma_construct_stream_to_mem_desc(&receive_descriptors[buffer_counter],
													  &receive_descriptors[buffer_counter + 1],
													  (alt_u32*) output_buffers[buffer_counter],
													  (alt_u16) buffer_lengths[buffer_counter]*sizeof(alt_u8),
													  0
		);
	}

	// Transmition data for configuration
	for(buffer_counter = 0;buffer_counter < NUMBER_OF_BUFFERS_CONF; buffer_counter++)
	{
		alt_avalon_sgdma_construct_mem_to_stream_desc(&transmit_conf_descriptors[buffer_counter],
													  &transmit_conf_descriptors[buffer_counter + 1],
													  (alt_u32*) cumhist,
													  (alt_u16) (MAX_HISTOGRAM_VALUE + 1),
													  0,
													  0,
													  0,
													  0
		);
	}



	alt_avalon_sgdma_register_callback(sgdma_m2s,
									   &transmit_callback_function,
									   (ALTERA_AVALON_SGDMA_CONTROL_IE_GLOBAL_MSK | ALTERA_AVALON_SGDMA_CONTROL_IE_CHAIN_COMPLETED_MSK | ALTERA_AVALON_SGDMA_CONTROL_PARK_MSK),
									   NULL
	);

	alt_avalon_sgdma_register_callback(sgdma_s2m,
									   &receive_callback_function,
									   (ALTERA_AVALON_SGDMA_CONTROL_IE_GLOBAL_MSK | ALTERA_AVALON_SGDMA_CONTROL_IE_CHAIN_COMPLETED_MSK | ALTERA_AVALON_SGDMA_CONTROL_PARK_MSK),
									   NULL
	);

	alt_avalon_sgdma_register_callback(sgdma_m2s_conf,
									   &transmit_conf_callback_function,
									   (ALTERA_AVALON_SGDMA_CONTROL_IE_GLOBAL_MSK | ALTERA_AVALON_SGDMA_CONTROL_IE_CHAIN_COMPLETED_MSK | ALTERA_AVALON_SGDMA_CONTROL_PARK_MSK),
									   NULL
	);


	alt_dcache_flush_all();

	IOWR_32DIRECT(MAPPING_INTENSITY_BASE, 0, image_width*image_height);

	IOWR_32DIRECT(MAPPING_INTENSITY_BASE, 8, 1);

	/* Start non blocking transfer with DMA modules. */
	if(alt_avalon_sgdma_do_async_transfer(sgdma_m2s, &transmit_descriptors[0]) != 0)
	{
		printf("Writing the head of the transmit descriptor list to the DMA failed\n");
	}

	if(alt_avalon_sgdma_do_async_transfer(sgdma_s2m, &receive_descriptors[0]) != 0)
	{
		printf("Writing the head of the receive descriptor list to the DMA failed\n");
	}

	if(alt_avalon_sgdma_do_async_transfer(sgdma_m2s_conf, &transmit_conf_descriptors[0]) != 0)
	{
		printf("Writing the head of the transmit conf descriptor list to the DMA failed\n");
	}

	printf("Started DMA\n");
	while(tx_conf_done < 1);
	tx_conf_done = 0;
	printf("Trancieve conf done\n");

	IOWR_32DIRECT(MAPPING_INTENSITY_BASE, 8, 2);

	while(tx_done < 1);
	tx_done = 0;
	printf("Trancieve done\n");

	while(rx_done < 1);
	printf("Receive done\n");
	rx_done = 0;
	alt_avalon_sgdma_stop(sgdma_m2s);
	alt_avalon_sgdma_stop(sgdma_m2s_conf);
	alt_avalon_sgdma_stop(sgdma_s2m);

	printf("DMA stop\n");

	for(it = 0;it < NUMBER_OF_BUFFERS_TRAN;it++)
	{
		for(itr = 0;itr < buffer_lengths[it];itr++)
		{
			character[0] = output_buffers[it][itr];
			fwrite(character,1,1,output_file);
		}
	}


	free(m2s_desc_copy);
	free(s2m_desc_copy);
	free(m2s_conf_desc_copy);

	for(it = 0;it < NUMBER_OF_BUFFERS_TRAN;it++)
	{
		free(input_buffers[it]);
	}
	free(input_buffers);

	for(it = 0;it < NUMBER_OF_BUFFERS_TRAN;it++)
	{
		free(output_buffers[it]);
	}
	free(output_buffers);

	free(buffer_lengths);

	printf("END!\n");

	fclose(input_file);
	fclose(output_file);
	fclose(input_file_pro);


	return 0;

}
