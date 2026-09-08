function predict_vessel_features(scope, budgetSec)
%PREDICT_VESSEL_FEATURES Resumable per-image vessel-feature extraction.
%   predict_vessel_features(scope, budgetSec)
%   scope: 'val' -> the 733 validation images (same sorted listing / ids as
%                   data/analysis/day8/task7/branchb_cache_partial.mat),
%                   images read from data/splits/val/class_*.
%          'fit'  -> the 250-ish original Branch B training subsample images
%                   (names in data/analysis/day8/branch_b/feat_cache.mat rows
%                   1..250, files in data/aptos2019/train_images).
%   budgetSec: wall-clock seconds to process before saving and returning
%              (default 1500). Re-run to resume; done rows are skipped.
%
%   Each image: green channel -> segmentVesselsCnn (targetLongEdge 512,
%   STRIDE 8) -> vessel probability map; fundus FOV proxy via Otsu on green;
%   8 features per image, all region means / fractions of the map:
%     1 vesselDensity   mean map over FOV
%     2 densityInner    mean map over inner disk (r = 0.45*sqrt(FOV_area/pi))
%     3-6 densityQ1..Q4 quadrant means (split by FOV centroid)
%     7 topFrac         fraction of FOV pixels with map >= 0.7
%     8 densityVar      variance of map over FOV
%   Saves data/analysis/day8/task8/vessel_features_<scope>.mat
%
%   NOTE: no fileparts() (broken in this R2026a build); paths parsed by regexp.

projRoot = 'C:\projects\DrishtiCare';
addpath(genpath(fullfile(projRoot,'src')));
if nargin < 2, budgetSec = 1500; end

outDir = fullfile(projRoot,'data','analysis','day8','task8');
if ~exist(outDir,'dir'), mkdir(outDir); end

nFeat = 8;
featNames = {'vesselDensity','densityInner','densityQ1','densityQ2', ...
            'densityQ3','densityQ4','topFrac','densityVar'};

switch scope
    case 'val'
        valDS = imageDatastore(fullfile(projRoot,'data','splits','val'), 'IncludeSubfolders', true);
        valDS.Files = sort(valDS.Files);
        ids = valDS.Files;
        grade = zeros(numel(ids),1);
        for i = 1:numel(ids)
            parts = strsplit(ids{i}, filesep);
            gi = find(~cellfun(@isempty, regexp(parts, '^class_[0-4]$')), 1);
            grade(i) = str2double(strrep(parts{gi}, 'class_', ''));
        end
        assert(numel(ids) == 733, 'val scope: expected 733 images, got %d', numel(ids));
        cacheFile = fullfile(outDir,'vessel_features_val733.mat');
    case 'fit'
        FC = load(fullfile(projRoot,'data','analysis','day8','branch_b','feat_cache.mat'));
        nFit = sum(~FC.isVal);
        ids = cell(nFit,1);
        for i = 1:nFit
            ids{i} = fullfile(projRoot,'data','aptos2019','train_images',char(FC.ids(i)));
        end
        grade = double(FC.grade(1:nFit));
        assert(nFit == 250, 'fit scope: expected 250 fit images, got %d', nFit);
        cacheFile = fullfile(outDir,'vessel_features_train250.mat');
    otherwise
        error('predict_vessel_features: bad scope %s', scope);
end

n = numel(ids);
VF = zeros(n, nFeat); done = false(n,1); failed = false(n,1);
fundusFrac = zeros(n,1); imgTime = zeros(n,1);
if exist(cacheFile,'file')
    C = load(cacheFile, 'VF','done','failed','fundusFrac','imgTime','ids');
    if numel(C.done) == n
        VF = C.VF; done = C.done; failed = C.failed; ids = C.ids;
        if isfield(C,'fundusFrac'), fundusFrac = C.fundusFrac; end
        if isfield(C,'imgTime'), imgTime = C.imgTime; end
        fprintf('[%s] resume: %d/%d done\n', scope, sum(done), n);
    end
end

t0 = tic;
for i = 1:n
    if done(i), continue; end
    ti = tic;
    try
        I = imread(ids{i});
        g = im2uint8(I(:,:,2));
        F = fundusMask(g);
        out = segmentVesselsCnn(I, struct('targetLongEdge',512,'STRIDE',8));
        m = out.map; mp = m(F);
        fundusFrac(i) = mean(F(:));
        VF(i,1) = mean(mp);
        st = regionprops(F, 'Centroid','Area');
        cx = st.Centroid(1); cy = st.Centroid(2);
        R = sqrt(st.Area/pi);
        rIn = 0.45*R;
        [gy, gx] = ndgrid(1:size(F,1), 1:size(F,2));
        inner = F & ((gx-cx).^2 + (gy-cy).^2) <= rIn^2;
        VF(i,2) = mean(m(inner(:)));
        q = {F & gx>=cx & gy<cy, F & gx>=cx & gy>=cy, ...
             F & gx<cx & gy<cy, F & gx<cx & gy>=cy};
        for k = 1:4
            if sum(q{k}(:)) > 0
                VF(i,2+k) = mean(m(q{k}(:)));
            end
        end
        VF(i,7) = mean(mp >= 0.7);
        VF(i,8) = var(mp);
        failed(i) = false;
    catch me
        failed(i) = true;
        fprintf('  WARN row %d (%s): %s\n', i, ids{i}, me.message);
    end
    done(i) = true;
    imgTime(i) = toc(ti);
    if mod(i,10) == 0 || i == n || toc(t0) > budgetSec
        VV = VF; DD = done; FF = failed; FFr = fundusFrac; II = ids;
        save(cacheFile, 'VF','ids','done','failed','fundusFrac','imgTime', ...
             'grade','featNames','-v7.3');
        el = toc(t0);
        nd = sum(done);
        avg = sum(imgTime(done)) / max(nd,1);
        eta = avg * (n - nd);
        fprintf('[%s] %d/%d done (%.0f s elapsed, avg %.1f s/img, failed=%d, ETA ~%.0f min)\n', ...
            scope, nd, n, el, avg, sum(failed), eta/60);
        if toc(t0) > budgetSec, break; end
    end
end
nd = sum(done);
fprintf('[%s] rows done: %d/%d (failed=%d)\n', scope, nd, n, sum(failed));
end

function F = fundusMask(g)
    bw = g > max(graythresh(g), 0.10);
    bw = imfill(bwareafilt(bw, 1, 'largest'), 'holes');
    F = imclose(bw, strel('disk', 9));
end