#! /usr/bin/python3

import numpy
from matplotlib import pyplot

i = 0
a = []

histogram_in = numpy.zeros(256)



with open("./low_contrast64.bin", "rb") as f:
	byte = f.read(1)
#	print(repr(byte))
#	print('\n')
	while byte:
		# Do stuff with byte.
		i += 1
		byte = f.read(1)
		if(i > 7):
			a.append(int.from_bytes(byte, byteorder='big'))
		else:
			print(repr(byte))
			print('\n')

for j in range(len(a) - 1):
	histogram_in[a[j]] += 1

print('obrada\n')

i = 0
histogram = []
pom = 0
with open("./histogram.bin", "rb") as f:
	byte = f.read(1)
	print(repr(byte))
	print('\n')
	while byte:
		# Do stuff with byte.
		i += 1
		#byte = f.read(1)
		pom += (int.from_bytes(byte, byteorder='big'))*(2**(8*(i - 1)))
		if(i == 4):
			histogram.append(pom)
			i = 0
			pom = 0
		byte = f.read(1)
		#else:
		print(byte)
		print('\n')


#print(a[0:5])
#print(b[0:5])

c = numpy.array(histogram_in) - numpy.array(histogram)
b = numpy.array(histogram_in)
v = numpy.array(histogram)

pyplot.figure(1)
pyplot.plot(c)
pyplot.title('Diff')


pyplot.figure(2)
pyplot.plot(b)
pyplot.title('ORG')

pyplot.figure(3)
pyplot.plot(v)
pyplot.title('Cal')
pyplot.show()





