[file,path] = uigetfile({'*.png;*.jpg;*.jpeg'}, ...
    'Select retinal image');

if isequal(file,0)
    return;
end

img = imread(fullfile(path,file));

[enhanced,quality] = enhanceImage(img);

figure;
imshowpair(img,enhanced,'montage');
title(['Original vs Enhanced: ' file]);

disp('Quality improvement:');
disp(quality);