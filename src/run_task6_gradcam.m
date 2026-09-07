%% TASK 6: Grad-CAM saliency scoring vs IDRiD ground-truth lesion masks
% Scores the 5-class champion's predicted-class Grad-CAM saliency maps on
% the IDRiD segmentation set against MA/HE/EX/SE ground-truth masks.
%
% Metrics (per lesion type + overall "any lesion", pooled over images that
% contain >=1 lesion of that type):
%   (a) saliency-mass-in-lesion = sum(sal .* mask) / sum(sal)
%   (b) pointing-game accuracy  = max-saliency pixel inside mask
%   (c) IoU-like overlap        = Dice & Jaccard of top-20% saliency vs mask
%
% Validation/annotation only. IDRiD test-set masks are used for annotation
% only (this is evaluation, not training). APTOS closed test set untouched.
% Models and thresholds are NOT modified.

projRoot = 'C:\projects\DrishtiCare';
cd(projRoot);
addpath(genpath(fullfile(projRoot, 'src')));

tStart = tic;
outDir = fullfile(projRoot, 'data', 'analysis', 'day8');
if ~exist(outDir, 'dir'), mkdir(outDir); end

%% 0. Environment checks
fprintf('===== TASK 6: Grad-CAM vs IDRiD lesion masks =====\n');
vs = ver;
if ~any(strcmpi({vs.Name}, 'Deep Learning Toolbox'))
    error('Deep Learning Toolbox not available');
end
dltIdx = find(strcmpi({vs.Name}, 'Deep Learning Toolbox'), 1);
fprintf('[ENV] Deep Learning Toolbox %s present\n', vs(dltIdx).Version);
if exist('gradCAM', 'file') == 2
    fprintf('[ENV] gradCAM: using built-in gradCAM object\n');
    useGradCAM = true;
else
    warning('gradCAM not found; falling back to gradient saliency via dlnetwork');
    useGradCAM = false;
end

%% 1. Data layout (actual disk contents)
segRoot = fullfile(projRoot, 'data', 'idrid', 'A. Segmentation');
origTrain = fullfile(segRoot, '1. Original Images', 'a. Training Set');
origTest  = fullfile(segRoot, '1. Original Images', 'b. Testing Set');
gtRoot    = fullfile(segRoot, '2. All Segmentation Groundtruths');
typeDirs  = {'1. Microaneurysms', '2. Haemorrhages', '3. Hard Exudates', '4. Soft Exudates'};
suffix    = {'MA', 'HE', 'EX', 'SE'};

% Enumerate images on disk
trainFiles = dir(fullfile(origTrain, '*.jpg'));
testFiles  = dir(fullfile(origTest, '*.jpg'));
allFiles   = [trainFiles; testFiles];
allFolds   = [repmat({'train'}, numel(trainFiles), 1); repmat({'test'}, numel(testFiles), 1)];
gtSubDirs  = [repmat({'a. Training Set'}, numel(trainFiles), 1); repmat({'b. Testing Set'}, numel(testFiles), 1)];
fprintf('[DATA] IDRiD segmentation images: %d train + %d test = %d total\n', ...
    numel(trainFiles), numel(testFiles), numel(allFiles));

%% 2. Load champion (read-only)
S5 = load(fullfile(projRoot, 'data', 'models', 'day7_pretrained_resnet18_5class_stage2.mat'), 'trainedNet');
net = S5.trainedNet;
inputSize = net.Layers(1).InputSize;
featLayer = 'res5b_relu';
fprintf('[MODEL] 5-class champion loaded, input %dx%dx%d, feature layer %s\n', ...
    inputSize(1), inputSize(2), inputSize(3), featLayer);

classNames = {'NoDR', 'Mild', 'Moderate', 'Severe', 'Proliferative'};

%% 3. Score each image
nImg = numel(allFiles);
perImage = cell(nImg, 1);
segImgSize = [];

topFrac = 0.20;   % threshold: top-20% saliency mass region

for i = 1:nImg
    if strcmp(allFolds{i}, 'train')
        imgPath = fullfile(origTrain, allFiles(i).name);
    else
        imgPath = fullfile(origTest, allFiles(i).name);
    end
    fname = allFiles(i).name;
    idTag = regexprep(fname, '\.jpg$', '');

    img = imread(imgPath);
    if isempty(segImgSize)
        segImgSize = size(img);
        fprintf('[DATA] Reference image size HxW: %dx%d (rows x cols)\n', size(img,1), size(img,2));
    end

    masks = zeros(size(img,1), size(img,2), 4);
    for t = 1:4
        p = fullfile(gtRoot, gtSubDirs{i}, typeDirs{t}, sprintf('%s_%s.tif', idTag, suffix{t}));
        if exist(p, 'file')
            m = imread(p);
            if ndims(m) > 2
                m = m(:,:,1);
            end
            if ~isequal(size(m,1), size(img,1)) || ~isequal(size(m,2), size(img,2))
                error('Mask %s size %s != image size %s for %s', p, mat2str(size(m)), mat2str(size(img)), fname);
            end
            masks(:,:,t) = double(m > 0);
        end
    end

    % Same transform to image + masks: resize both to 224x224
    img224 = imresize(img, [inputSize(1) inputSize(2)]);
    masks224 = false(inputSize(1), inputSize(2), 4);
    for t = 1:4
        masks224(:,:,t) = imresize(masks(:,:,t), [inputSize(1) inputSize(2)], 'nearest') > 0.5;
    end

    scores = predict(net, img224);
    scores = scores(:)';
    [~, predIdx] = max(scores);
    predClass = classNames{predIdx};

    if useGradCAM
        cmap = gradCAM(net, img224, predIdx, 'FeatureLayer', featLayer);
    else
        % Fallback: gradient-based saliency (shouldn't be reached here)
        cmap = gradFallback(net, img224, predIdx);
    end
    sal = double(mat2gray(cmap));
    sal = max(sal - min(sal(:)), 0);
    if sum(sal(:)) <= 0
        error('Zero saliency map for %s', fname);
    end

    % Background confound: fraction of saliency mass inside the retina disk
    [retMask, ~] = createRetinalMask(img224);
    retMask = retMask > 0.5;
    anyMask = any(masks224, 3);
    rec = struct();
    rec.file = fname;
    rec.fold = char(allFolds{i});
    rec.predClass = predClass;
    rec.predIdx = predIdx;
    rec.predScore = scores(predIdx);
    rec.hasLesion = sum(anyMask(:)) > 0;
    rec.massIn = zeros(4,1); rec.point = zeros(4,1);
    rec.dice = zeros(4,1); rec.jacc = zeros(4,1);
    rec.nPixMask = zeros(4,1);
    for t = 1:4
        mask = masks224(:,:,t);
        rec.nPixMask(t) = sum(mask(:));
        [rec.massIn(t), rec.point(t), rec.dice(t), rec.jacc(t)] = ...
            typeMetrics(sal, mask, topFrac);
    end
    [rec.massInAll, rec.pointAll, rec.diceAll, rec.jaccAll] = typeMetrics(sal, anyMask, topFrac);
    rec.massInRetina = sum(sal(retMask(:))) / sum(sal(:));
    rec.massInLesionGivenRetina = sum(sal(anyMask(:) & retMask(:))) / (sum(sal(retMask(:))) + eps);
    rec.maxSal = max(sal(:));
    rec.salSum = sum(sal(:));
    perImage{i} = rec;

    if mod(i, 10) == 0 || i == nImg
        fprintf('  [%d/%d] %s pred=%s (%.3f) anyLesion=%d massInAll=%.3f pointAll=%d\n', ...
            i, nImg, fname, predClass, rec.predScore, rec.hasLesion, rec.massInAll, rec.pointAll);
    end
end
fprintf('\n[RUN] All %d images scored (%.1f s)\n', nImg, toc(tStart));

%% 4. Aggregate tables
lesionNames = {'MA', 'HE', 'EX', 'SE', 'All'};
agg = struct();
for ti = 1:5
    if ti <= 4
        hasType = @(r) r.nPixMask(ti) > 0;
        getMass = @(r) r.massIn(ti);
        getPoi  = @(r) r.point(ti);
        getDice = @(r) r.dice(ti);
        getJacc = @(r) r.jacc(ti);
    else
        hasType = @(r) r.hasLesion;
        getMass = @(r) r.massInAll;
        getPoi  = @(r) r.pointAll;
        getDice = @(r) r.diceAll;
        getJacc = @(r) r.jaccAll;
    end
    sel = cellfun(hasType, perImage);
    n = nnz(sel);
    if n == 0
        agg(ti).type = lesionNames{ti}; agg(ti).n = 0;
        continue;
    end
    massVals = cellfun(getMass, perImage(sel));
    poiVals  = cellfun(getPoi,  perImage(sel));
    diceVals = cellfun(getDice, perImage(sel));
    jaccVals = cellfun(getJacc, perImage(sel));
    agg(ti).type = lesionNames{ti};
    agg(ti).n    = n;
    agg(ti).massInMean = mean(massVals);
    agg(ti).massInMed  = median(massVals);
    agg(ti).pointing   = mean(poiVals);
    agg(ti).diceMean   = mean(diceVals);
    agg(ti).jaccMean   = mean(jaccVals);
    fprintf('%-4s n=%3d massIn=%.3f point=%.3f dice=%.3f jacc=%.3f\n', ...
        lesionNames{ti}, n, agg(ti).massInMean, agg(ti).pointing, agg(ti).diceMean, agg(ti).jaccMean);
end

%% 4b. Background confound diagnostics
retMass = cellfun(@(r) r.massInRetina, perImage);
retLes  = cellfun(@(r) r.massInLesionGivenRetina, perImage);
fprintf('\n[CONFOUND] saliency mass inside retina disk: mean=%.3f median=%.3f\n', mean(retMass), median(retMass));
fprintf('[CONFOUND] lesion mass within retina: mean=%.3f median=%.3f\n', mean(retLes), median(retLes));

%% 5. Correct-vs-error: report blocked item honestly
blocked = struct();
blocked.metric = 'correct-vs-error saliency-mass comparison';
blocked.status = 'BLOCKED';
blocked.reason = ['IDRiD segmentation images (A. Segmentation, IDRiD_01..IDRiD_81) are a ' ...
    'distinct image set from IDRiD Disease Grading (B. Disease Grading, IDRiD_001..IDRiD_413/103). ' ...
    'The champion\\''s 5 APTOS classes (NoDR..Proliferative) require those grading labels, which do ' ...
    'not exist for the segmentation images. Therefore no correct/incorrect labels can be computed ' ...
    'for IDRiD; the 733 APTOS-val split (correct/error) has no lesion masks, so saliency-mass-in-' ...
    'lesion cannot be computed on it. No class-consistent correct-vs-error split is obtainable.'];
% Quantify what we CAN: champion class distribution on IDRiD images
predCounts = zeros(5,1);
for i = 1:nImg
    predCounts(perImage{i}.predIdx) = predCounts(perImage{i}.predIdx) + 1;
end
blocked.championPredClassCountOnIDRiD = predCounts;
blocked.championPredClassNames = classNames;

fprintf('\n===== CORRECT-vs-ERROR =====\n');
fprintf('STATUS: %s\n', blocked.status);
fprintf('%s\n', blocked.reason);
fprintf('Champion predicted-class distribution on the %d IDRiD images:\n', nImg);
for c = 1:5
    fprintf('  %-14s %d\n', classNames{c}, predCounts(c));
end

%% 6. Save + report
perImage = vertcat(perImage{:});
outFile = fullfile(outDir, 'gradcam_T6.mat');
save(outFile, 'perImage', 'agg', 'blocked', 'useGradCAM', 'featLayer', 'topFrac', ...
    'segImgSize', 'nImg', 'predCounts', 'classNames');
fprintf('\n[SAVE] %s\n', outFile);

fprintf('\n===== TASK 6 SUMMARY (measured) =====\n');
fprintf('Saliency: %s (5-class champion, feature layer %s), top-%d%% threshold\n', ...
    ternary(useGradCAM, 'built-in gradCAM', 'gradient fallback'), featLayer, round(topFrac*100));
fprintf('Images scored: %d total (segmentation set on disk)\n', nImg);
fprintf('%-8s %-4s %-8s %-8s %-8s\n', 'Type', 'n', 'MassIn', 'Point', 'Dice');
for ti = 1:5
    if agg(ti).n == 0, continue; end
    fprintf('%-8s %-4d %-8.3f %-8.3f %-8.3f\n', agg(ti).type, agg(ti).n, ...
        agg(ti).massInMean, agg(ti).pointing, agg(ti).diceMean);
end
fprintf('Total runtime: %.1f s\n', toc(tStart));
fprintf('=== TASK 6 COMPLETE ===\n');

function [massIn, point, dice, jacc] = typeMetrics(sal, mask, topFrac)
    sTot = sum(sal(:));
    if sTot <= 0
        massIn = NaN; point = NaN; dice = NaN; jacc = NaN;
        return;
    end
    massIn = sum(sal(mask(:))) / sTot;
    [~, idx] = max(sal(:));
    point = double(mask(idx) > 0);
    % Threshold: top-20% saliency mass (region where cumulative saliency reaches topFrac)
    salVec = sort(sal(:), 'descend');
    cumC = cumsum(salVec);
    cutIdx = find(cumC >= topFrac * sTot, 1);
    thr = salVec(cutIdx);
    binSal = sal >= thr;
    inter = sum(binSal(:) & mask(:));
    uni   = sum(binSal(:) | mask(:));
    jacc = inter / (uni + eps);
    dice = 2 * inter / (sum(binSal(:)) + sum(mask(:)) + eps);
end

function sal = gradFallback(net, img, classIdx)
    dlnet = dlnetwork(net);
    dlX = dlarray(im2double(img), 'SSCB');
    y = predict(dlnet, dlX);
    score = y(classIdx, 1, 1, 1);
    grad = dlgradient(score, dlX);
    sal = sum(abs(extractdata(grad)), 3);
    sal = extractdata(sal);
end

function out = ternary(cond, a, b)
    if cond, out = a; else, out = b; end
end