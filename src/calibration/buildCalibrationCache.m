% BUILD_CALIBRATION_CACHE
% One sequential pass over all APTOS train images (3662) computing the
% exact inference features used by predictSingleFundus:
%   - pRef   : P(referable) from the binary pretrained net (sB(2))
%   - s5     : 1x5 class probabilities from the 5-class pretrained net
%   - grade  : ground-truth grade 0-4 from train.csv
%   - isVal  : logical, membership in the day7 stratified held-out split
% Saves data/analysis/day8/calibration/aptos_train_cache.mat consumed by
% the three calibration strategy analyses. Engineering analytics only.

projectRoot = 'C:\projects\DrishtiCare';
cd(projectRoot);
addpath(genpath('src'));

modelDir = fullfile(projectRoot, 'data', 'models');
binPath = fullfile(modelDir, 'day7_pretrained_resnet18_binary_stage2.mat');
gradePath = fullfile(modelDir, 'day7_pretrained_resnet18_5class_stage2.mat');
SB = load(binPath, 'trainedNet');
S5 = load(gradePath, 'trainedNet');
netB = SB.trainedNet;
net5 = S5.trainedNet;

% ---- labels ----
T = readtable(fullfile(projectRoot, 'data', 'aptos2019', 'train.csv'));
ids = T.id_code;
labels = T.diagnosis;   % 0..4 (matching 5-class class_0..class_4)
n = numel(ids);

% ---- split membership from data/splits/val/class_X/*.png ----
valIds = strings(0);
for c = 0:4
    fd = fullfile(projectRoot, 'data', 'splits', 'val', sprintf('class_%d', c));
    if ~isdir(fd), continue; end
    f = dir(fullfile(fd, '*.png'));
    for k = 1:numel(f)
        base = regexprep(char(f(k).name), '\.png$', '');
        valIds(end+1) = string(base); %#ok<AGROW>
    end
end
valSet = containers.Map(valIds, ones(numel(valIds),1));

pRef = zeros(n,1);
s5 = zeros(n,5);
grade = zeros(n,1);
isVal = false(n,1);

fprintf('Computing predictions on %d images...\n', n);
tic;
for i = 1:n
    imgPath = fullfile(projectRoot, 'data', 'aptos2019', 'train_images', [char(ids{i}) '.png']);
    raw = imread(imgPath);
    if size(raw,3) == 1, raw = repmat(raw,1,1,3); end
    modelInput = imresize(raw, [224 224]);
    sB = predict(netB, modelInput);  sB = sB(:)';
    pRef(i) = sB(2);
    [~, sc] = classify(net5, modelInput);  sc = sc(:)';
    s5(i,:) = sc;
    grade(i) = labels(i);
    ky = char(ids{i});
    isVal(i) = isKey(valSet, ky);
    if mod(i, 250) == 0
        fprintf('  %d/%d  (%.0fs)\n', i, n, toc);
    end
end
fprintf('Done. %.0f s total.\n', toc);

outDir = fullfile(projectRoot, 'data', 'analysis', 'day8', 'calibration');
if ~isdir(outDir), mkdir(outDir); end
save(fullfile(outDir, 'aptos_train_cache.mat'), 'pRef', 's5', 'grade', 'isVal', 'ids');
fprintf('Cache saved: %s\n', fullfile(outDir, 'aptos_train_cache.mat'));