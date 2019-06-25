#! /usr/bin/python3

import numpy
import math
import matplotlib.pyplot as pyplot
from pylab import *
from string import Template
import sys
import subprocess
from PIL import Image



height = 0
width = 0

#values of images members
a = []
i = 0
# Size
width_hist = 0
height_hist = 0

# Reading picture for calcuclating histogram and cumulative sum
with open("./dark512.bin", "rb") as f1:
	byte = f1.read(1)
	width_hist += int.from_bytes(byte, byteorder='big')
	while byte:
		i += 1
		byte = f1.read(1)
		# First 4 bytes -- WIDTH
		if(i < 4):
			width_hist += int.from_bytes(byte, byteorder='big') << (8**i)
		# Second 4 bytes -- HEIGHT
		elif(i < 8):
			height_hist += int.from_bytes(byte, byteorder='big') << (8**(i - 4))
		else:
			a.append(int.from_bytes(byte, byteorder='big'))


histogram = numpy.zeros(256)

# Histogram
for i in range(len(a)-1):
	histogram[a[i]] += 1


cumhist = []

# Cumulative sum
tmp = histogram[0]
cumhist.append(int(round(1.0*tmp*(255.0/(len(a)-1)))))
for i in range(len(histogram) - 1):  
	
	tmp += histogram[i + 1]
	cumhist.append(int(round(1.0*tmp*(255.0/(len(a)-1)))))
	

# Image for processing
b = []
i = 0
# Size
width_mapp = 0
height_mapp = 0

# Reading picture for processing
with open("./dark512.bin", "rb") as f2:
	byte = f2.read(1)
	width_mapp += int.from_bytes(byte, byteorder='big')
	while byte:
		i += 1
		byte = f2.read(1)
		# First 4 bytes -- WIDTH
		if(i < 4):
			width_mapp += int.from_bytes(byte, byteorder='big') << (8**i)
		# Second 4 bytes -- HEIGHT
		elif(i < 8):
			height_mapp += int.from_bytes(byte, byteorder='big') << (8**(i - 4))
		else:
			b.append(int.from_bytes(byte, byteorder='big'))


	
new_data = []

# Output image in software
for i in range(len(b)):

	new_data.append(cumhist[b[i]])


width_calc = 0
height_calc = 0

calc = []
i = 0
# Result of hardware
with open("./image.bin", "rb") as f3:
	byte = f3.read(1)
	width_calc += int.from_bytes(byte, byteorder='big')
	while byte:
		i += 1
		byte = f3.read(1)
		# First 4 bytes -- WIDTH
		if(i < 4):
			width_calc += int.from_bytes(byte, byteorder='big') << (8**i)
		# Second 4 bytes -- HEIGHT
		elif(i < 8):
			height_calc += int.from_bytes(byte, byteorder='big') << (8**(i - 4))
		else:
			calc.append(int.from_bytes(byte, byteorder='big'))


# Showing images

calc_tmp = numpy.array(calc[:width_calc*height_calc])

calc_tmp = calc_tmp.reshape(width_calc,height_calc)

calc_tmp = numpy.uint8(calc_tmp)

new_data_img = Image.fromarray(numpy.uint8(numpy.array(new_data[:len(new_data)-1])).reshape(width_mapp,height_mapp),'L')

img_hist = Image.fromarray(numpy.uint8(numpy.array(a[:width_hist*height_hist])).reshape(width_hist,height_hist),'L')
img_mapp = Image.fromarray(numpy.uint8(numpy.array(b[:width_mapp*height_mapp])).reshape(width_mapp,height_mapp),'L')
img_calc = Image.fromarray(calc_tmp,'L')

#img = Image.open('./bright.tif')


new_data_img.show('1')
img_hist.show('2')
img_mapp.show('3')
img_calc.show('4')






