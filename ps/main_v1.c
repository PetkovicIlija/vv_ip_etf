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
#include "altera_avalon_performance_counter.h"
#include "alt_types.h"
#include "io.h"
#include "math.h"
#include "altera_avalon_sgdma_regs.h"
#include "altera_avalon_sgdma_descriptor.h"
#include "altera_avalon_sgdma.h"
#include "sys/alt_cache.h"
#include "functions.h"
#include "altera_avalon_performance_counter.h"
//#include "altera_avalon_timer.h"
//#include "sys/alt_timestamp.h"


#define MAX_HISTOGRAM_VALUE (255)
#define MAX_HISTOGRAM_VALUE_FLOAT (255.0f)
#define MAX_NUM_DMA_TRANSFER (65535)
#define NUMBER_OF_BUFFERS_REC (1)

/* These will gate the data checking near the end of main */
volatile alt_u16 tx_done = 0;
volatile alt_u16 rx_done = 0;

void transmit_callback_function(void * context)
{
  tx_done++;  /* main will be polling for this value being 1 */
}

void receive_callback_function(void * context)
{
  rx_done++;  /* main will be polling for this value being 1 */
}

int main()
{

	FILE* input_file = NULL;
	FILE* output_file = NULL;
	alt_u32 iterator = 0;
	alt_u32 iterator1 = 0;
	alt_u8 character[1];
	alt_u32 image_width = 0;
	alt_u32 image_height = 0;
	alt_u32 tmp = 0;
	alt_u8* image;
	alt_u32* histogram;
	alt_u32** hist_value;
	alt_u32 buffer_counter = 0;

	alt_u32 tmp22;

	alt_u8 NUMBER_OF_BUFFERS_TRAN = 0;
    alt_u8 ** input_buffers;
    alt_u16 * buffer_lengths;

    alt_u32 it = 0;
    alt_u32 itr = 0;

	void * temp_ptr;

	alt_sgdma_dev* sgdma_m2s = alt_avalon_sgdma_open("/dev/sgdma_m2s");
	alt_sgdma_dev* sgdma_s2m = alt_avalon_sgdma_open("/dev/sgdma_s2m");

	alt_sgdma_descriptor *m2s_desc_copy;
	alt_sgdma_descriptor *s2m_desc_copy;
	alt_sgdma_descriptor *transmit_descriptors, *receive_descriptors;
	alt_u32 tmp_start_time_hw, tmp_end_time_hw, tmp_start_time_sw, tmp_end_time_sw;

	input_file = fopen("/mnt/host/files/bright512.bin","r");
	output_file = fopen("/mnt/host/files/histogram.bin","w");


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

	// READING DATA

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

	image = (alt_u8*)malloc(image_width*image_height*sizeof(alt_u8));

	// NUMBER_OF_BUFFERS
	NUMBER_OF_BUFFERS_TRAN += (image_width*image_height)/MAX_NUM_DMA_TRANSFER;
	if(image_width*image_height % MAX_NUM_DMA_TRANSFER > 0)
	{

		NUMBER_OF_BUFFERS_TRAN++;

	}

	printf("NUMBER_OF_BUFFERS_TRAN = %u\n",NUMBER_OF_BUFFERS_TRAN);

	buffer_lengths = (alt_u16 *)malloc(NUMBER_OF_BUFFERS_TRAN*sizeof(alt_u16));

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
	if(input_buffers == 0)
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
	}


	image = (alt_u8*)malloc(image_width*image_height*sizeof(alt_u8));
	histogram = (alt_u32*)malloc((MAX_HISTOGRAM_VALUE + 1)*sizeof(alt_u32));
	iterator = 0;

//	while(iterator < image_width*image_height)
//	{
	for(it = 0;it < NUMBER_OF_BUFFERS_TRAN;it++)
	{
		for(itr = 0;itr < buffer_lengths[it];itr++)
		{
			fread(character,1,1,input_file);
			input_buffers[it][itr] = character[0];
			image[iterator] = character[0];
			iterator++;
//			//iterator++;
		}
	}
//	}

	PERF_START_MEASURING(PERFORMANCE_COUNTER_BASE);
	PERF_BEGIN(PERFORMANCE_COUNTER_BASE,1);
	// SOFTWARE
	hist(image,image_width, image_height, 0, 0, image_width-1, image_height-1, hist_value);


	PERF_END(PERFORMANCE_COUNTER_BASE,1);

	free(image);
	free(hist_value);

	PERF_BEGIN(PERFORMANCE_COUNTER_BASE,2);

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

	// PROCESSING

	// Descriptors

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

	for(buffer_counter = 0;buffer_counter < NUMBER_OF_BUFFERS_REC; buffer_counter++)
	{
		alt_avalon_sgdma_construct_stream_to_mem_desc(&receive_descriptors[buffer_counter],
													  &receive_descriptors[buffer_counter + 1],
													  (alt_u32*) histogram,
													  (alt_u16) (MAX_HISTOGRAM_VALUE + 1)*sizeof(alt_u32),
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


	alt_dcache_flush_all();

	IOWR_32DIRECT(HISTOGRAM_CALCULATION_WRAPPER_BASE, 0, image_width*image_height);

	//printf("Configure acc done\n");

	IOWR_32DIRECT(HISTOGRAM_CALCULATION_WRAPPER_BASE, 8, 1);

	//printf("Started acc done\n");

	/* Start non blocking transfer with DMA modules. */
	if(alt_avalon_sgdma_do_async_transfer(sgdma_m2s, &transmit_descriptors[0]) != 0)
	{
		printf("Writing the head of the transmit descriptor list to the DMA failed\n");
	}
	if(alt_avalon_sgdma_do_async_transfer(sgdma_s2m, &receive_descriptors[0]) != 0)
	{
		printf("Writing the head of the receive descriptor list to the DMA failed\n");
	}

	//printf("%d\n",receive_descriptors[0].bytes_to_transfer);

	printf("Started DMA\n");
	while(tx_done < 1);
	tx_done = 0;
	printf("Trancieve done\n");

	//printf("%u\n",(alt_u32)IORD_32DIRECT(HISTOGRAM_CALCULATION_BASE, 4));

	//tmp22 = 0;
	while(rx_done < 1);

	PERF_END(PERFORMANCE_COUNTER_BASE,2);

	PERF_STOP_MEASURING(PERFORMANCE_COUNTER_BASE);



	printf("Receive done\n");
	rx_done = 0;
	alt_avalon_sgdma_stop(sgdma_m2s);
	alt_avalon_sgdma_stop(sgdma_s2m);

	printf("DMA stop\n");




	for(iterator = 0; iterator < MAX_HISTOGRAM_VALUE + 1;iterator++)
	{

		for(iterator1 = 0; iterator1 < 4; iterator1++)
		{
			character[0] = (alt_u8)(histogram[iterator] >> iterator1*8);
			fwrite(character,1,1,output_file);
		}

	}


	free(image);
	free(histogram);

	free(m2s_desc_copy);
	free(s2m_desc_copy);

	for(it = 0;it < NUMBER_OF_BUFFERS_TRAN;it++)
	{
		free(input_buffers[it]);
	}
	free(input_buffers);

	free(buffer_lengths);

	//printf("HARDWARE  = %u\n",tmp_end_time_hw - tmp_start_time_hw);
	//printf("SOFTWARE  = %u\n",tmp_end_time_sw - tmp_start_time_sw);

	perf_print_formatted_report((void *)PERFORMANCE_COUNTER_BASE, alt_get_cpu_freq(),2,"software","hardware");

	printf("END!\n");

	return 0;

}
