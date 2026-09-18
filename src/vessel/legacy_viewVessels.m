% LEGACY viewer for the legacy single-scale extractor (renamed 18-Sep-2026,
% see legacy_extractVessels.m). Production viewer is viewVessels.m.
[file,path] = uigetfile( ...
    {'*.png;*.jpg;*.jpeg;*.tif;*.tiff'}, ...
    'Select retinal image');

if isequal(file,0)
    return;
end

img = imread(fullfile(path,file));

vessels = legacy_extractVessels(img);

figure;
imshowpair(img,vessels,'montage');
title(['Original | Retinal Blood Vessels - ' file]);