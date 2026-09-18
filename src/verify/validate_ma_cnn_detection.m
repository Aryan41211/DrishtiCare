function validateMaCnnDetection()
%VALIDATEMACNNDETECTION Detection-level PR of CNN-MA detector vs IDRiD GT
%   Runs detectMaCnn on held-out IDRiD_01..10, matches detections to GT MA
%   blob centroids (tol=12px full-res), sweeps the CNN score threshold, and
%   reports recall/precision/operating point. Compare with the classical
%   matched-filter result (recall~0.10, precision~0.003).

projRoot = 'C:\projects\DrishtiCare'; cd(projRoot);
addpath(fullfile(projRoot,'src','lesions'));
origDir = fullfile(projRoot,'data','idrid','A. Segmentation','1. Original Images','a. Training Set');
gtRoot  = fullfile(projRoot,'data','idrid','A. Segmentation','2. All Segmentation Groundtruths','a. Training Set');
outDir  = fullfile(projRoot,'data','analysis','day8','ma_cnn');
tol = 12;   % full-res match tolerance (px)

nVal = 10;
imgFiles = dir(fullfile(origDir,'*.jpg'));
allSc = []; allLbl = []; imgIds = [];
for i = 1:nVal
    numStr = regexp(imgFiles(i).name,'IDRiD_(\d+)\.jpg','tokens','once');
    num2 = str2double(numStr{1});
    out = detectMaCnn(fullfile(origDir,imgFiles(i).name), struct('verbose',true,'ensemble',true));
    gm = imread(fullfile(gtRoot,'1. Microaneurysms',sprintf('IDRiD_%02d_MA.tif',num2)))>0;
    gg = bwconncomp(gm); gtC = zeros(gg.NumObjects,2);
    for b=1:gg.NumObjects
        [yy,xx]=ind2sub(size(gm),gg.PixelIdxList{b}); gtC(b,:)=[mean(xx) mean(yy)];
    end
    cx = out.centroidX; cy = out.centroidY; sc = out.score;
    n = numel(cx);
    fprintf('IDRiD_%02d: nGT=%d  nCand=%d\n', num2, gg.NumObjects, n);
    % greedy matching: sort by score desc, match each candidate to nearest
    % UNMATCHED GT within tol (candidate order = score-sorted, so threshold
    % sweeps keep a monotone TP/FP curve)
    [~,ord] = sort(sc,'descend');
    matchedGT = false(gg.NumObjects,1);
    for c = ord(:)'
        d = sqrt((gtC(:,1)-cx(c)).^2 + (gtC(:,2)-cy(c)).^2);
        [md,bi] = min(d);
        if md<=tol && ~matchedGT(bi)
            matchedGT(bi) = true;
            allSc(end+1) = sc(c); allLbl(end+1) = 1; %#ok<SAGROW>
        else
            allSc(end+1) = sc(c); allLbl(end+1) = 0; %#ok<SAGROW>
        end
        imgIds(end+1) = num2; %#ok<SAGROW>
    end
    fprintf('      matched %d/%d GT blobs\n', sum(matchedGT), gg.NumObjects);
end

% ---- PR sweep ----
thrs = [0.5 0.6 0.7 0.8 0.9 0.95 0.99];
fprintf('\n%-8s %8s %8s %8s\n','thr','recall','precision','F1');
best = [0 0]; 
for t=1:numel(thrs)
    sel = allSc>=thrs(t);
    tp = sum(sel & allLbl);
    fp = sum(sel & ~allLbl);
    fn = sum(~sel & allLbl);
    rec = tp/(tp+fn); prec = tp/(tp+fp); f1 = 2*rec*prec/max(rec+prec,1e-9);
    fprintf('%-8.2f %8.3f %8.3f %8.3f\n', thrs(t), rec, prec, f1);
end
fprintf('\nnGT total=%d  candidates total=%d\n', sum(allLbl), numel(allSc));

% classic matched-filter comparison (stored mean)
try
    v = load(fullfile(projRoot,'data','analysis','day8','lesion_gt_validation','matched_filter_validation.mat'));
    fprintf('\nClassical matched-filter (previous) mean MA: recall=%.3f precision=%.3f\n', mean(v.R(:,1)), mean(v.P(:,1)));
catch
    fprintf('\n(no matched_filter_validation.mat to compare)\n');
end
save(fullfile(outDir,'ma_cnn_detection.mat'),'allSc','allLbl','imgIds','thrs','tol');
fprintf('Saved %s\n', fullfile(outDir,'ma_cnn_detection.mat'));
end