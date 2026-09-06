%% TASK 6: Lesion-feature branch — IDRiD classical candidate extraction
% Runs extractLesionCandidates on >=10 IDRiD training images, computes
% per-quadrant haemorrhage counts and exudate distance-to-fovea, and saves
% visual-inspection montages. Validation-only (IDRiD train); official
% APTOS test set untouched.

projRoot = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(projRoot,'src'), fullfile(projRoot,'src','lesions'));
cd(projRoot);

origDir = fullfile(projRoot, 'data', 'idrid', 'A. Segmentation', '1. Original Images', 'a. Training Set');
maDir   = fullfile(projRoot, 'data', 'idrid', 'A. Segmentation', '2. All Segmentation Groundtruths', 'a. Training Set', '1. Microaneurysms');
odDir   = fullfile(projRoot, 'data', 'idrid', 'A. Segmentation', '2. All Segmentation Groundtruths', 'a. Training Set', '5. Optic Disc');
foveaCSV = fullfile(projRoot, 'data', 'idrid', 'C. Localization', '2. Groundtruths', '2. Fovea Center Location', 'IDRiD_Fovea_Center_Training Set_Markups.csv');
odCSV    = fullfile(projRoot, 'data', 'idrid', 'C. Localization', '2. Groundtruths', '1. Optic Disc Center Location', 'a. IDRiD_OD_Center_Training Set_Markups.csv');

outDir = fullfile(projRoot, 'data', 'analysis', 'day8', 'lesions');
if ~exist(outDir,'dir'), mkdir(outDir); end

% Parse coordinate CSVs (robust to trailing-comma padding)
foveaMap = parseMarkups(foveaCSV);
odMap    = parseMarkups(odCSV);
fprintf('Fovea markups parsed: %d\n', foveaMap.Count);
fprintf('OD markups parsed: %d\n', odMap.Count);

%% Process first N images (at least 10)
nImages = 10;
imgFiles = dir(fullfile(origDir, '*.jpg'));
results = struct();
montages = cell(nImages, 1);

for i = 1:nImages
    imgFile = imgFiles(i).name;                       % IDRiD_XX.jpg
    numStr = regexp(imgFile, 'IDRiD_(\d+)\.jpg', 'tokens', 'once');
    if isempty(numStr), continue; end
    num2 = str2double(numStr{1});
    id3 = sprintf('IDRiD_%03d', num2);               % IDRiD_XXX

    fov = []; odc = []; odr = 0;
    if foveaMap.isKey(id3), fov = foveaMap(id3); end
    if odMap.isKey(id3), odc = odMap(id3); end

    % Estimate optic disc radius from OD segmentation mask (train only)
    odMaskFile = fullfile(odDir, sprintf('IDRiD_%02d_OD.tif', num2));
    try
        if exist(odMaskFile, 'file')
            odm = imread(odMaskFile) > 0;
            s = sum(odm(:));
            odr = sqrt(s/pi);                        % area -> radius (orig px)
        end
    catch
        odr = 0;
    end

    if ~isempty(odc) && odr == 0
        odr = 200;   % fallback approximate disc radius (orig px)
    end

    opts = struct();
    opts.scale = 4;
    opts.odCenter = odc;
    opts.odRadius = odr;
    opts.fovea = fov;
    opts.verbose = true;

    fprintf('\n[%d/%d] %s (od=[%d,%d] r=%.0f fovea=[%d,%d])\n', ...
        i, nImages, imgFile, odc(1), odc(2), odr, fov(1), fov(2));

    feat = extractLesionCandidates(fullfile(origDir, imgFile), opts);
    feat.id = id3;
    results.(sprintf('img_%02d', i)) = feat;
    montages{i} = feat.visual;
end

%% Save aggregated results + montage mosaic
save(fullfile(outDir, 'lesion_features.mat'), 'results');

% Build a montage for visual inspection (downscaled overlays)
rows = ceil(nImages/5);
fig = figure('Visible','off','Position',[50 50 1500 1000]);
for i = 1:nImages
    if isempty(montages{i}), continue; end
    subplot(rows, 5, i);
    ov = montages{i}.overlay;
    % Mark MA (red dot), HE (magenta box), EX (yellow polygon) on overlay
    imshow(ov); hold on;
    [hy,hx] = find(montages{i}.maMask);   plot(hx,hy,'ro','MarkerSize',2); hold on;
    [ey,ex] = find(montages{i}.exMask);   plot(ex,ey,'y.','MarkerSize',1);
    title(sprintf('%s  MA=%d HE=%d EX=%d', results.(sprintf('img_%02d',i)).id, ...
        sum(montages{i}.maMask(:)), sum(montages{i}.heMask(:)), sum(montages{i}.exMask(:))), 'FontSize', 8);
end
saveas(fig, fullfile(outDir, 'lesion_montage.png'));
fprintf('\nMontage saved: %s\n', fullfile(outDir, 'lesion_montage.png'));

%% Summary table
fprintf('\n===== LESION FEATURE SUMMARY =====\n');
fprintf('%-12s %4s %4s %4s     %s\n', 'Image', 'MA', 'HE', 'EX', 'QuadHE[TR TL BL BR]  MeanFoveaDist');
for i = 1:nImages
    ft = results.(sprintf('img_%02d', i));
    q = ft.quadrantHemorrhage;
    fprintf('%-12s %4d %4d %4d     [%d %d %d %d]            %7.0f\n', ...
        ft.id, ft.microaneurysms.count, ft.haemorrhages.count, ft.exudates.count, ...
        q(1), q(2), q(3), q(4), ft.meanExudateDistToFovea);
end

%% Save a CSV summary for downstream fusion features
fid = fopen(fullfile(outDir, 'lesion_summary.csv'), 'w');
fprintf(fid, 'image,ma_count,he_count,ex_count,q_TR,q_TL,q_BL,q_BR,mean_fovea_dist_px\n');
for i = 1:nImages
    ft = results.(sprintf('img_%02d', i));
    q = ft.quadrantHemorrhage;
    fprintf(fid, '%s,%d,%d,%d,%d,%d,%d,%d,%.1f\n', ft.id, ...
        ft.microaneurysms.count, ft.haemorrhages.count, ft.exudates.count, ...
        q(1), q(2), q(3), q(4), ft.meanExudateDistToFovea);
end
fclose(fid);
fprintf('\nCSV saved: %s\n', fullfile(outDir, 'lesion_summary.csv'));
fprintf('\n=== TASK 6 COMPLETE ===\n');

%% Local function (must be at end of script)
function map = parseMarkups(csvFile)
    fid = fopen(csvFile, 'r');
    map = containers.Map('KeyType','char','ValueType','any');
    line = fgetl(fid);   % skip header
    while ischar(line) && ~isempty(line)
        if strncmp(line, 'IDRiD_', 6)
            parts = strsplit(line, ',');
            if length(parts) >= 3
                id = parts{1};
                x = str2double(parts{2});
                y = str2double(parts{3});
                if ~isnan(x) && ~isnan(y) && x > 0 && y > 0
                    map(id) = [x y];
                end
            end
        end
        line = fgetl(fid);
    end
    fclose(fid);
end