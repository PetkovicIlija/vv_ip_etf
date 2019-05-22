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
//#include "altera_avalon_performance_counter.h"
#include "alt_types.h"
#include "math.h"
#include "altera_avalon_sgdma_regs.h"
#include "altera_avalon_sgdma_descriptor.h"
#include "altera_avalon_sgdma.h"
#include "sys/alt_cache.h"

#define MAX_HISTOGRAM_VALUE (255)
#define MAX_HISTOGRAM_VALUE_FLOAT (255.0f)
#define NUMBER_OF_BUFFERS (1)

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
	alt_u32 buffer_counter = 0;

	alt_u32 tmp22;

	void * temp_ptr;

	alt_sgdma_dev* sgdma_m2s = alt_avalon_sgdma_open("/dev/sgdma_m2s");
	alt_sgdma_dev* sgdma_s2m = alt_avalon_sgdma_open("/dev/sgdma_s2m");

	//alt_sgdma_descriptor *m2s_desc,
	alt_sgdma_descriptor *m2s_desc_copy;
	//alt_sgdma_descriptor *s2m_desc,
	alt_sgdma_descriptor *s2m_desc_copy;
	alt_sgdma_descriptor *transmit_descriptors, *receive_descriptors;

	input_file = fopen("/mnt/host/files/low_contrast64.bin","r");
	output_file = fopen("/mnt/host/files/histogram.bin","w");

	//printf("START!\n");

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

	// ALOCATION OF TRANCIVE DESCRIPTORS --> M2S
	temp_ptr = malloc((NUMBER_OF_BUFFERS + 2) * ALTERA_AVALON_SGDMA_DESCRIPTOR_SIZE);

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

	//m2s_desc = transmit_descriptors;

	transmit_descriptors[NUMBER_OF_BUFFERS].control = 0;

	// ALLOCATION OF RECEIVE DESCRIPTORS
	temp_ptr = malloc((NUMBER_OF_BUFFERS + 2) * ALTERA_AVALON_SGDMA_DESCRIPTOR_SIZE);

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

	//s2m_desc = receive_descriptors;

	receive_descriptors[NUMBER_OF_BUFFERS].control = 0;


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

	//printf("image_width = %u\n",image_width);
	//printf("image_height = %u\n",image_height);

	image = (alt_u8*)malloc(image_width*image_height*sizeof(alt_u8));
	//image_out = (alt_u16*)malloc(image_width*image_height*sizeof(alt_u16));MAX_HISTOGRAM_VALUE
	histogram = (alt_u32*)malloc((MAX_HISTOGRAM_VALUE + 1)*sizeof(alt_u32));
	iterator = 0;

	while(iterator < image_width*image_height)
	{
		fread(character,1,1,input_file);
		image[iterator] = character[0];
		iterator++;
	}

	// PROCESSING

	// Descriptors

	for(buffer_counter = 0;buffer_counter < NUMBER_OF_BUFFERS; buffer_counter++)
	{
		alt_avalon_sgdma_construct_mem_to_stream_desc(&transmit_descriptors[buffer_counter],
													  &transmit_descriptors[buffer_counter+1],
													  (alt_u32*) image,
													  (alt_u16) image_width*image_height,
													  0,
													  0,
													  0,
													  0
		);

		alt_avalon_sgdma_construct_stream_to_mem_desc(&receive_descriptors[buffer_counter],
													  &receive_descriptors[buffer_counter + 1],
													  (alt_u32*) histogram,
													  (alt_u16) (MAX_HISTOGRAM_VALUE + 1)*sizeof(alt_u32),
													  0
		);

	}
	//(MAX_HISTOGRAM_VALUE + 1)

    //printf("Made descriptors\n");

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

	IOWR_32DIRECT(HISTOGRAM_CALCULATION_BASE, 0, 4096);
	//IOWR_8DIRECT(HISTOGRAM_CALC_BASE, 1, (alt_8)(5));

	printf("Configure acc done\n");

	IOWR_32DIRECT(HISTOGRAM_CALCULATION_BASE, 8, 1);

	printf("Started acc done\n");

	/* Start non blocking transfer with DMA modules. */
	if(alt_avalon_sgdma_do_async_transfer(sgdma_m2s, &transmit_descriptors[0]) != 0)
	{
		printf("Writing the head of the transmit descriptor list to the DMA failed\n");
	}
	if(alt_avalon_sgdma_do_async_transfer(sgdma_s2m, &receive_descriptors[0]) != 0)
	{
		printf("Writing the head of the receive descriptor list to the DMA failed\n");
	}

	printf("%d\n",receive_descriptors[0].bytes_to_transfer);

	printf("Started DMA\n");
	while(tx_done < 1);
	tx_done = 0;
	printf("Trancieve done\n");

	//tmp22 = (alt_u32)IORD_32DIRECT(HISTOGRAM_CALC_BASE, 4);
	//printf("%u\n",tmp22);

	// Start sendindg
//	while(1)
//	{
//
//		tmp22 = (alt_u32)IORD_32DIRECT(HISTOGRAM_CALC_BASE, 4);
//		//printf("%u\n",tmp22);
//		if(tmp22 == 3)
//		{
//			printf("End calculating\n");
//			break;
//		}
//
//	}

	printf("%u\n",(alt_u32)IORD_32DIRECT(HISTOGRAM_CALCULATION_BASE, 4));

	//IOWR_32DIRECT(HISTOGRAM_CALC_BASE, 8, 4);
	tmp22 = 0;
	while(rx_done < 1)
	{
		//printf("%u\n",(alt_u32)IORD_32DIRECT(HISTOGRAM_CALC_BASE, 4));
//		if((IORD_32DIRECT(HISTOGRAM_CALC_BASE, 4) & 0x0006) && (tmp22 == 0))
//		{
//			printf("End calculating\n");
//			tmp22 = 1;
//		}
//		if((IORD_32DIRECT(HISTOGRAM_CALC_BASE, 4) & 0x0008) && (tmp22 == 1))
//		{
//			printf("End sending\n");
//			tmp22 = 2;
//		}
		//printf(".08x",sgdma_s2m)
		//printf("%u\n",receive_descriptors[0].status);

	}

	printf("Receive done\n");
	rx_done = 0;
	alt_avalon_sgdma_stop(sgdma_m2s);
	alt_avalon_sgdma_stop(sgdma_s2m);

	printf("DMA stop\n");

//	iterator = 0;
//
//	while(iterator < 4){
//
//		character[0] = (alt_u8)(image_width >> iterator*8);
//		iterator++;
//		fwrite(character,1,1,output_file);
//	}
//
//	iterator = 0;
//
//	while(iterator < 4){
//
//		character[0] = (alt_u8)(image_height >> (iterator*8));
//		iterator++;
//		fwrite(character,1,1,output_file);
//
//	}


	for(iterator = 0; iterator < MAX_HISTOGRAM_VALUE + 1;iterator++)
	{

		//character[0] = MAX_HISTOGRAM_VALUE - image[iterator];
		for(iterator1 = 0; iterator1 < 4; iterator1++)
		{
			character[0] = (alt_u8)(histogram[iterator] >> iterator1*8);
			fwrite(character,1,1,output_file);
		}

	}
//	printf("%u\n",(alt_u16)image[0]);
//	printf("%u\n",(alt_u16)image[1]);
//	printf("%u\n",(alt_u16)image[2]);
//	printf("%u\n",(alt_u16)image[3]);
//	printf("%u\n",(alt_u16)image[4]);
//	printf("%u\n",image_out[0]);
//	printf("%u\n",image_out[1]);
//	printf("%u\n",image_out[2]);
//	printf("%u\n",image_out[3]);
//	printf("%u\n",image_out[4]);

	free(image);
	free(histogram);

	free(m2s_desc_copy);
	free(s2m_desc_copy);

	//free(temp_ptr);

	printf("END!\n");

	return 0;

}
