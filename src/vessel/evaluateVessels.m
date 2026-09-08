function results = evaluateVessels()
%EVALUATEVESSELS Evaluate extractVessels on the DRIVE test set (n=20).
%   Primary ground truth: 1st_manual (official DRIVE benchmark), with
%   2nd_manual as an independent second observer.
%
%   Metrics: Dice, F1, sensitivity, specificity, accuracy, precision,
%   plus pixel-level ROC-AUC (response vs 1st_manual).
%
%   FOV handling: all metrics are computed on pixels INSIDE the DRIVE FOV
%   mask (eroded by `evalFovErode` px for both prediction and ground truth)
%   so that the black background outside the retina cannot artificially
%   inflate accuracy.
%
%   Outputs (saved to data\analysis\vessel\):
%     metrics.txt          - per-image and mean metric table
%     drive_vessel_metrics.mat - results struct
%     drive_montage.png    - 4x5 grid: Original | GT(1st) | Predicted |
%                            Overlay for 5 representative DRIVE images.
%
%   NOTE: research prototype, not a clinically validated system.

scriptDir = fileparts(mfilename('fullpath'));
addpath(scriptDir);            % ensure extractVessels is found

projRoot = 'C:\projects\DrishtiCare';
testRoot = fullfile(projRoot, 'data', 'drive', 'DRIVE', 'test');
outDir   = fullfile(projRoot, 'data', 'analysis', 'vessel');
if ~exist(outDir, 'dir')
    mkdir(outDir);
end

%% ------------------------- Evaluation configuration ----------------------
evalFovErode = 5;               % px: FOV erosion applied to BOTH the
                                % prediction and the ground truth when
                                % scoring (fair, avoids FOV-rim artifacts).
montageImgs = [1 5 10 15 20];   % 5 representative DRIVE test images
                                % (indices 1..20) shown in the montage.
%% -------------------------------------------------------------------------

f = dir(fullfile(testRoot, 'images', '*.tif'));
f = sort({f.name});
n = numel(f);
assert(n == 20, 'Expected 20 DRIVE test images, found %d', n);

names   = cell(n, 1);
M1row   = zeros(n, 6);   % [dice f1 sens spec acc prec] vs 1st_manual
M2row   = zeros(n, 6);   % same vs 2nd_manual
OLDrow  = zeros(n, 6);   % OLD baseline algorithm, same metrics vs 1st_manual
aucRow  = zeros(n, 1);
diceHuman = zeros(n, 1);

for i = 1:n
    numImg = i;
    img = imread(fullfile(testRoot, 'images', sprintf('%02d_test.tif', numImg)));
    F  = imread(fullfile(testRoot, 'mask', sprintf('%02d_test_mask.gif', numImg))) > 0;
    G1 = imread(fullfile(testRoot, '1st_manual', sprintf('%02d_manual1.gif', numImg))) > 0;
    G2 = imread(fullfile(testRoot, '2nd_manual', sprintf('%02d_manual2.gif', numImg))) > 0;

    Fe  = imerode(F, strel('disk', evalFovErode));
    Fm  = Fe(:);

    [M, resp] = extractVessels(img, 'fov', Fe);
    Mm = M(:) & Fm;

    M1row(i, :)   = scoreMetrics(Mm, G1(:), Fm);
    M2row(i, :)   = scoreMetrics(Mm, G2(:), Fm);

    % OLD baseline (single-scale disk-8 bottom-hat, Otsu, area20, thin),
    % same FOV-restricted scoring, for an apples-to-apples comparison.
    Old = oldBaselineMap(img) & Fe;
    OLDrow(i, :)  = scoreMetrics(Old(:), G1(:), Fm);
    diceHuman(i)  = dicePair(G1(:), G2(:), Fm);

    % Pixel-level ROC-AUC of the raw vessel response vs 1st_manual.
    [~, ~, ~, aucRow(i)] = perfcurve(double(G1(:) & Fm), resp(:), true);

    names{i} = sprintf('%02d_test.tif', numImg);
    fprintf('%02d  Dice=%.3f Sens=%.3f Spec=%.3f Acc=%.3f Prec=%.3f AUC=%.3f  human=%.3f\n', ...
        numImg, M1row(i,1), M1row(i,3), M1row(i,4), M1row(i,5), M1row(i,6), ...
        aucRow(i), diceHuman(i));
end

%% --------------------------- Summary -------------------------------------
summ = mean(M1row, 1);
summ2 = mean(M2row, 1);
oldm = mean(OLDrow, 1);
fprintf('\n==== DRIVE TEST (n=%d, scored inside eroded FOV) ====\n', n);
fprintf('  vs 1st_manual : Dice=%.4f  F1=%.4f  Sens=%.4f  Spec=%.4f  Acc=%.4f  Prec=%.4f  AUC=%.4f\n', ...
    summ(1), summ(2), summ(3), summ(4), summ(5), summ(6), mean(aucRow));
fprintf('  vs 2nd_manual : Dice=%.4f  F1=%.4f  Sens=%.4f  Spec=%.4f  Acc=%.4f  Prec=%.4f\n', ...
    summ2(1), summ2(2), summ2(3), summ2(4), summ2(5), summ2(6));
fprintf('  OLD baseline  : Dice=%.4f  F1=%.4f  Sens=%.4f  Spec=%.4f  Acc=%.4f  Prec=%.4f\n', ...
    oldm(1), oldm(2), oldm(3), oldm(4), oldm(5), oldm(6));
fprintf('  human inter-observer (2nd vs 1st): Dice=%.4f\n', mean(diceHuman));

%% --------------------------- Save results --------------------------------
results = struct();
results.names      = names;
results.m1         = M1row;            % vs 1st_manual, rows = images
results.m2         = M2row;            % vs 2nd_manual, rows = images
results.old        = OLDrow;           % OLD baseline vs 1st_manual
results.auc        = aucRow;
results.humanDice  = diceHuman;
results.summary1   = summ;
results.summary2   = summ2;
results.summaryOld = oldm;
results.meanAuc    = mean(aucRow);
results.meanHumanDice = mean(diceHuman);
results.evalFovErode = evalFovErode;
results.date       = datestr(now);

save(fullfile(outDir, 'drive_vessel_metrics.mat'), 'results');

% Text report
fid = fopen(fullfile(outDir, 'metrics.txt'), 'w');
fprintf(fid, 'DRIVE vessel evaluation (%s)\n', results.date);
fprintf(fid, 'Method: extractVessels.m (classical multi-scale Frangi + morphology)\n');
fprintf(fid, 'FOV: DRIVE mask eroded by %d px, scored inside it.\n\n', evalFovErode);
fprintf(fid, '%4s | %6s %6s %6s %6s %6s %6s %6s | %6s\n', '##', 'Dice', 'F1', ...
    'Sens', 'Spec', 'Acc', 'Prec', 'AUC', 'Human');
for i = 1:n
    fprintf(fid, '%4d | %6.3f %6.3f %6.3f %6.3f %6.3f %6.3f %6.3f | %6.3f\n', ...
        i, M1row(i,1), M1row(i,2), M1row(i,3), M1row(i,4), M1row(i,5), ...
        M1row(i,6), aucRow(i), diceHuman(i));
end
fprintf(fid, '\nMEAN vs 1st_manual: Dice=%.4f F1=%.4f Sens=%.4f Spec=%.4f Acc=%.4f Prec=%.4f AUC=%.4f\n', ...
    summ(1), summ(2), summ(3), summ(4), summ(5), summ(6), mean(aucRow));
fprintf(fid, 'MEAN vs 2nd_manual: Dice=%.4f F1=%.4f Sens=%.4f Spec=%.4f Acc=%.4f Prec=%.4f\n', ...
    summ2(1), summ2(2), summ2(3), summ2(4), summ2(5), summ2(6));
fprintf(fid, 'OLD baseline     : Dice=%.4f F1=%.4f Sens=%.4f Spec=%.4f Acc=%.4f Prec=%.4f\n', ...
    oldm(1), oldm(2), oldm(3), oldm(4), oldm(5), oldm(6));
fprintf(fid, 'HUMAN inter-observer Dice: %.4f\n', mean(diceHuman));
fclose(fid);

%% --------------------------- Montage --------------------------------------
saveMontage(testRoot, montageImgs, evalFovErode, outDir);

fprintf('\nSaved:\n  %s\n  %s\n  %s\n', ...
    fullfile(outDir, 'metrics.txt'), ...
    fullfile(outDir, 'drive_vessel_metrics.mat'), ...
    fullfile(outDir, 'drive_montage.png'));

end

%% ============================ LOCAL FUNCTIONS ===============================

function m = scoreMetrics(M, G, Fm)
%SCOREMETRICS Binary metrics computed only on FOV pixels (Fm).
%   m = [dice, f1, sensitivity, specificity, accuracy, precision]
    g = G(Fm); p = M(Fm);
    TP = sum(g & p);  FP = sum(~g & p);
    FN = sum(g & ~p); TN = sum(~g & ~p);
    denom = 2 * TP + FP + FN;
    m(1) = 2 * TP / max(denom, 1);            % Dice
    m(2) = 2 * TP / max(denom, 1);            % F1 == Dice for binary
    m(3) = TP / max(TP + FN, 1);              % sensitivity / recall
    m(4) = TN / max(TN + FP, 1);              % specificity
    m(5) = (TP + TN) / max(TP + FN + FP + TN, 1); % accuracy
    m(6) = TP / max(TP + FP, 1);              % precision
end

function d = dicePair(A, B, Fm)
%DICEPAIR Dice between two segmentations inside the FOV (inter-observer).
    a = A(Fm); b = B(Fm);
    inter = sum(a & b);
    d = 2 * inter / max(sum(a) + sum(b), 1);
end

function old = oldBaselineMap(img)
%OLDBASELINEMAP Replicates the previous src/extractVessels.m algorithm:
%   grayscale -> CLAHE -> disk-8 bottom-hat -> Otsu -> bwareaopen(20) -> thin.
%   Kept for a fair old-vs-new DRIVE comparison.
    gray = im2double(rgb2gray(img));
    gray = adapthisteq(gray);
    se = strel('disk', 8);
    old = imbothat(gray, se);
    old = mat2gray(old);
    level = graythresh(old);
    old = old > level;
    old = bwareaopen(old, 20);
    old = bwmorph(old, 'thin', Inf);
end

function saveMontage(testRoot, idxList, erodePx, outDir)
%SAVEMONTAGE 4 (rows) x K grid: Original | 1st-manual GT | Predicted | Overlay.
    K = numel(idxList);
    fig = figure('Visible', 'off', 'Position', [50 50 200*K+80 4*230]);
    for c = 1:K
        i = idxList(c);
        img = imread(fullfile(testRoot, 'images', sprintf('%02d_test.tif', i)));
        F  = imread(fullfile(testRoot, 'mask', sprintf('%02d_test_mask.gif', i))) > 0;
        G1 = imread(fullfile(testRoot, '1st_manual', sprintf('%02d_manual1.gif', i))) > 0;
        Fe = imerode(F, strel('disk', erodePx));
        [M, ~] = extractVessels(img, 'fov', Fe);

        tiles = {img, G1, M, vesselOverlayRGB(img, M)};
        titles = {'Original', 'Ground Truth', 'Predicted', 'Overlay'};
        for r = 1:4
            subplot(4, K, (r-1)*K + c);
            if r == 1
                imshow(img);
            else
                imshow(tiles{r});
            end
            title(sprintf('%s  %02d', titles{r}, i), 'FontSize', 9);
        end
    end
    sgtitle('DRIVE test: classical vessel segmentation (extractVessels.m)', ...
        'FontSize', 11);
    exportgraphics(fig, fullfile(outDir, 'drive_montage.png'), 'Resolution', 110);
    close(fig);
end

function ov = vesselOverlayRGB(img, mask)
%BUILDVESSELOVERLAY Detected vessels (green) over the original image.
    if size(img, 3) == 1
        ov = repmat(im2double(img), [1 1 3]);
    else
        ov = im2double(img);
    end
    r = ov(:,:,1); g = ov(:,:,2); b = ov(:,:,3);
    r(mask) = 0.15 * r(mask);
    g(mask) = 0.90;
    b(mask) = 0.15 * b(mask);
    ov = cat(3, r, g, b);
    ov = im2uint8(ov);
end