fp = fopen('dark512.bin', 'rb');

width = fread(fp, 1, 'uint32');
height = fread(fp, 1, 'uint32');

I = uint8(reshape(fread(fp), [width height])');

fclose(fp);

hist = imhist(I);

cumhist = uint8(round(255*(double(cumsum(hist))/(width*height))));

J = intlut(I, cumhist);

