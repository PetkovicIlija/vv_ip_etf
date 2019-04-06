
#! /usr/bin/python3

import numpy
from matplotlib import pyplot

i = 0
a = []
with open("./output.bin", "rb") as f:
	byte = f.read(1)
	a.append(int.from_bytes(byte, byteorder='big'))
	while byte:
		byte = f.read(1)
		# Do stuff with byte.
		a.append(int.from_bytes(byte, byteorder='big'))

novi = []

for i in range(256):
	novi.append(a[i*4] + a[i*4 + 1]*256 + a[i*4 +2]*256*256 + a[i*4 + 3]*256*256*256)

print('obrada\n')
i = 0
b = []
with open("./bright64.bin", "rb") as f:
	byte = f.read(1)
	while byte:
		# Do stuff with byte.
		i += 1
		byte = f.read(1)
		if(i > 7):
			b.append(int.from_bytes(byte, byteorder='big'))



hist = []

for i in range(256):
	hist.append(0)


for i in range(len(b)):
	for j in range(256):
		if(b[i] == j):
			hist[j] += 1

coef = 255.0/(64.0*64.0)
cumcum = []
tmp = 0
for i in range(256):
	for j in range(i+1):
		tmp += 	hist[j]	
		
	cumcum.append(tmp)
	tmp = 0


for i in range(len(cumcum)):
	cumcum[i] = int(round(cumcum[i]*1.0*coef))

c = numpy.array(cumcum) - numpy.array(novi)

pyplot.figure(1)
pyplot.plot(c)

pyplot.show()



