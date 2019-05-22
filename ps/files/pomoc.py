#! /usr/bin/python3

import numpy
from matplotlib import pyplot

i = 0
a = []
with open("./bright64.bin", "rb") as f:
	byte = f.read(1)
	print(repr(byte))
	print('\n')
	while byte:
		# Do stuff with byte.
		i += 1
		byte = f.read(1)
		if(i > 7):
			a.append(int.from_bytes(byte, byteorder='big'))
		else:
			print(repr(byte))
			print('\n')


print('obrada\n')
i = 0
b = []
with open("./output1.bin", "rb") as f:
	byte = f.read(1)
	print(repr(byte))
	print('\n')
	while byte:
		# Do stuff with byte.
		i += 1
		byte = f.read(1)
		if(i > 7):
			b.append(int.from_bytes(byte, byteorder='big'))
		else:
			print(repr(byte))
			print('\n')


print(a[0:5])
print(b[0:5])

c = numpy.array(a)-numpy.array(b)

pyplot.figure(1)
pyplot.plot(c)

pyplot.show()


