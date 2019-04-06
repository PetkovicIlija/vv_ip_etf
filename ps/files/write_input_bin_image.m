I = imread('dark.tif');
%I = rgb2gray(I);
I = imresize(I, [64 64]);

fp = fopen('dark64.bin', 'wb');

width = size(I, 2);
height = size(I, 1);

fwrite(fp, width, 'uint32');
fwrite(fp, height, 'uint32');
fwrite(fp, I', 'uint8');

fclose(fp);