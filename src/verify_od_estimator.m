%% VERIFY estimateOpticDisc against IDRiD ground-truth OD centers
%  Compares heuristic OD detection with the IDRiD localization markups on the
%  same 10 training images used in Task 6. Measures center error and radius
%  vs. the OD segmentation masks. Validation-only; official test set untouched.

projRoot = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(projRoot,'src','lesions'));
cd(projRoot);

origDir = fullfile(projRoot, 'data', 'idrid', 'A. Segmentation', '1. Original Images', 'a. Training Set');
odMaskDir = fullfile(projRoot, 'data', 'idrid', 'A. Segmentation', '2. All Segmentation Groundtruths', 'a. Training Set', '5. Optic Disc');
odCSV = fullfile(projRoot, 'data', 'idrid', 'C. Localization', '2. Groundtruths', '1. Optic Disc Center Location', 'a. IDRiD_OD_Center_Training Set_Markups.csv');

fid = fopen(odCSV, 'r'); line = fgetl(fid); % skip header
odMap = containers.Map('KeyType','char','ValueType','any');
while ischar(line) && ~isempty(line)
    if strncmp(line, 'IDRiD_', 6)
        parts = strsplit(line, ',');
        if length(parts) >= 3
            id = parts{1}; x = str2double(parts{2}); y = str2double(parts{3});
            if ~isnan(x) && ~isnan(y) && x > 0 && y > 0, odMap(id) = [x y]; end
        end
    end
    line = fgetl(fid);
end
fclose(fid);

nImages = 10;
imgFiles = dir(fullfile(origDir, '*.jpg'));
fprintf('%-11s %-20s %-20s %8s %8s %8s\n', 'Image', 'GT center', 'Est center', 'Err_px', 'GT_r', 'Est_r');
totErr = 0; nOk = 0;
for i = 1:nImages
    imgFile = imgFiles(i).name;
    numStr = regexp(imgFile, 'IDRiD_(\d+)\.jpg', 'tokens', 'once');
    num2 = str2double(numStr{1});
    id3 = sprintf('IDRiD_%03d', num2);

    gt = odMap(id3);
    odMaskFile = fullfile(odMaskDir, sprintf('IDRiD_%02d_OD.tif', num2));
    odm = imread(odMaskFile) > 0;
    gtR = sqrt(sum(odm(:))/pi);

    est = estimateOpticDisc(fullfile(origDir, imgFile), struct('verbose', true));
    if isempty(est)
        fprintf('%-11s [%-6.0f %-6.0f]  EST FAILED\n', id3, gt(1), gt(2));
        continue;
    end
    err = norm(est(1:2) - gt);
    totErr = totErr + err; nOk = nOk + 1;
    fprintf('%-11s [%-6.0f %-6.0f] [%-6.0f %-6.0f] %8.0f %8.0f %8.0f\n', ...
        id3, gt(1), gt(2), est(1), est(2), err, gtR, est(3));
end
if nOk > 0
    fprintf('\nMEAN CENTER ERROR: %.0f px (n=%d)\n', totErr/nOk, nOk);
end

save(fullfile(projRoot,'data','analysis','day8','od_estimator_verification.mat'), ...
    'imgFiles', 'odMap', 'totErr', 'nOk');
fprintf('Saved verification to data/analysis/day8/od_estimator_verification.mat\n');