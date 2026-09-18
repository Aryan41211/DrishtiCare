function vessels = legacy_extractVessels(img)
% LEGACY - single-scale Otsu vessel extractor (Dice ~0.312, superseded).
% Kept for audit provenance. Production code lives in extractVessels.m
% (same folder). Renamed 18-Sep-2026 during src/ reorganization to end
% the shadowing of the production version (see FINAL_DRISHTICARE_TECHNICAL_AUDIT P1).

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