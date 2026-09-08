function vessels = extractVessels(img)

gray = im2double(rgb2gray(img));

% Improve contrast
gray = adapthisteq(gray);

% Highlight dark blood vessels
se = strel('disk', 8);
vessels = imbothat(gray,se);

% Normalize
vessels = mat2gray(vessels);

% Convert to binary vessel map
level = graythresh(vessels);
vessels = imbinarize(vessels,level);

% Remove tiny noise
vessels = bwareaopen(vessels,20);

% Thin vessels
vessels = bwmorph(vessels,'thin',Inf);

end