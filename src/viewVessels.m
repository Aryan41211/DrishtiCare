[file,path] = uigetfile( ...
    {'*.png;*.jpg;*.jpeg;*.tif;*.tiff'}, ...
    'Select retinal image');

if isequal(file,0)
    return;
end

img = imread(fullfile(path,file));

vessels = extractVessels(img);

figure;
imshowpair(img,vessels,'montage');
title(['Original | Retinal Blood Vessels - ' file]);