% build_aptos_feature_cache.m
% Build Branch B feature cache on a stratified subsample of APTOS train.
% Columns (featNames):
%   1 MA_count     2 HE_count       3 EX_count
%   4 q1HE         5 q2HE           6 q3HE           7 q4HE     (quadrant hemorrhage)
%   8 odLocated    9 exNearDisc    10 meanExDistToDisc
% referable label = grade>=2. Split = data/splits/{train,val}/class_*.
%
% OD callback: locateOpticDiscCnn(I); if unavailable (P<0.90) -> odLocated=0.
%
% NOTE: run() changes the current folder to the script's folder, so cd to the
% project root and use absolute paths (this script was written for MATLAB -batch).

projectRoot = 'C:\projects\DrishtiCare';
cd(projectRoot);
addpath(genpath(fullfile(projectRoot, 'src')));
outDir = fullfile(projectRoot, 'data', 'analysis', 'day8', 'branch_b');
if ~exist(outDir, 'dir'), mkdir(outDir); end

rng(42);  % replicate
% Full 70/class train is ~50 min of CPU extraction; use the sanctioned
% reduced subsample: 50/class train + 10/class val (OD locate ~1-9 s/img).
N_PER_CLASS_TRAIN = 50;   % 5 classes x 50 = 250 train subsample
N_VAL_PER_CLASS    = 10;  % 5 classes x 10 = 50 val slice
grades = 0:4;
ids = strings(0); grade = zeros(0,1); isVal = false(0,1);
for g = grades
    dTr = dir(fullfile(projectRoot, 'data', 'splits', 'train', sprintf('class_%d',g), '*.png'));
    selTr = datasample(dTr, min(N_PER_CLASS_TRAIN, numel(dTr)), 'Replace', false);
    for i = 1:numel(selTr)
        ids(end+1) = string(selTr(i).name); %#ok<SAGROW>
        grade(end+1) = g; %#ok<SAGROW>
        isVal(end+1) = false; %#ok<SAGROW>
    end
end
isVal = isVal(:);

% ~50 balanced val images (10 per grade)
idsVal = strings(0); gradeVal = zeros(0,1);
for g = grades
    dV = dir(fullfile(projectRoot, 'data', 'splits', 'val', sprintf('class_%d',g), '*.png'));
    selV = datasample(dV, min(N_VAL_PER_CLASS, numel(dV)), 'Replace', false);
    for i = 1:numel(selV)
        idsVal(end+1) = string(selV(i).name); %#ok<SAGROW>
        gradeVal(end+1) = g; %#ok<SAGROW>
    end
end
ids = [ids idsVal]; grade = [grade(:); gradeVal(:)];
isVal = [isVal; true(numel(gradeVal),1)];

featNames = {'MA_count','HE_count','EX_count','q1HE','q2HE','q3HE','q4HE', ...
             'odLocated','exNearDisc','meanExDistToDisc'};
X = zeros(numel(ids), numel(featNames));
nOd = 0;
for i = 1:numel(ids)
    imgPath = fullfile(projectRoot, 'data', 'aptos2019', 'train_images', char(ids(i)));
    % ---- OD callback (locateOpticDiscCnn returns cx=[] when P<0.90) ----
    odOk = false; odc = []; odr = 0;
    try
        [cx, cy, r, ~] = locateOpticDiscCnn(imread(imgPath));
        odOk = ~isempty(cx) && numel(cx)==1 && cx > 0;
        if odOk, odc = [cx cy]; odr = r; end
    catch
        odOk = false;
    end
    f = extractLesionCandidates(imgPath, struct('returnVisual', false, 'verbose', false, ...
                                                'odCenter', odc, 'odRadius', odr));
    q = f.quadrantHemorrhage; if isempty(q), q = zeros(1,4); end
    X(i,1) = f.microaneurysms.count;
    X(i,2) = f.haemorrhages.count;
    X(i,3) = f.exudates.count;
    X(i,4:7) = q;
    X(i,8) = double(odOk);
    % exNearDisc = exudate centroids within ~1.5 x OD radius of disc centre
    ed = f.exudates.centroidX; ey = f.exudates.centroidY;
    if odOk && ~isempty(ed)
        if isempty(odr) || odr <= 0, odr = 0; end
        thr = 1.5 * max(odr, 50);
        d = sqrt(sum(([ed; ey] - [odc(1); odc(2)]).^2, 1));
        X(i,9) = double(sum(d <= thr));
        X(i,10) = mean(d);
    end
    if odOk, nOd = nOd + 1; end
    if mod(i,25)==0, fprintf('%d/%d\n', i, numel(ids)); end
end

save(fullfile(outDir, 'feat_cache.mat'), 'X', 'grade', 'isVal', 'ids', 'featNames', 'N_PER_CLASS_TRAIN', 'N_VAL_PER_CLASS');
fprintf('Saved feat_cache.mat: %d rows (train=%d val=%d), odLocated=%d/%d\n', ...
    numel(ids), sum(~isVal), sum(isVal), nOd, numel(ids));