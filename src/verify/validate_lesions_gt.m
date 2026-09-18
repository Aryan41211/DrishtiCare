%% TASK: lesion candidate DETECTION validation vs IDRiD GT (blob-level)
%  Proper metric for a candidate-count pipeline: match candidate centroids
%  (ORIGINAL coords) to GT connected components within a tolerance radius.
%    - detection recall  = fraction of GT blobs that have >=1 candidate
%    - detection precision = fraction of candidates that hit a GT blob
%  Pixel-IoU was the wrong bar for MA/HE (we emit centroid markers, not
%  segmentations); EX is kept as mask so both are reported.

projRoot = 'C:\projects\DrishtiCare';
cd(projRoot);
addpath(fullfile(projRoot,'src','lesions'), fullfile(projRoot,'src','quality'));

origDir = fullfile(projRoot,'data','idrid','A. Segmentation','1. Original Images','a. Training Set');
gtRoot = fullfile(projRoot,'data','idrid','A. Segmentation','2. All Segmentation Groundtruths','a. Training Set');
outDir = fullfile(projRoot,'data','analysis','day8','lesion_gt_validation');

tol = 20;      % px, tolerance radius for a centroid->blob match (original px)

nImages = 10;
imgFiles = dir(fullfile(origDir,'*.jpg'));
types = {'MA','HE','EX'};
D = struct();
D.recall = zeros(nImages,3); D.precision = zeros(nImages,3);
D.nGT = zeros(nImages,3); D.nCand = zeros(nImages,3);
D.imgId = cell(nImages,1);
D.gtFolders = {'1. Microaneurysms','2. Haemorrhages','3. Hard Exudates'};
D.suffix = {'_MA.tif','_HE.tif','_EX.tif'};

for i = 1:nImages
    imgFile = imgFiles(i).name;
    numStr = regexp(imgFile,'IDRiD_(\d+)\.jpg','tokens','once');
    num2 = str2double(numStr{1});
    id3 = sprintf('IDRiD_%03d', num2);
    D.imgId{i} = id3;

    odc = []; odr = 0;
    odMaskFile = fullfile(gtRoot,'5. Optic Disc', sprintf('IDRiD_%02d_OD.tif', num2));
    if exist(odMaskFile,'file')
        odm = imread(odMaskFile)>0; st = regionprops(odm,'Centroid');
        if ~isempty(st), odc = st(1).Centroid; end
        odr = sqrt(sum(odm(:))/pi);
    end
    opts = struct('scale',4,'odCenter',odc,'odRadius',odr,'fovea',[],'verbose',false);
    feat = extractLesionCandidates(fullfile(origDir,imgFile), opts);

    for t = 1:3
        gtMask = imread(fullfile(gtRoot,D.gtFolders{t},sprintf('IDRiD_%02d%s',num2,D.suffix{t}))) > 0;
        cc = bwconncomp(gtMask);
        gtCent = zeros(cc.NumObjects, 2);
        for b = 1:cc.NumObjects
            [yy,xx] = ind2sub(size(gtMask), cc.PixelIdxList{b});
            gtCent(b,:) = [mean(xx) mean(yy)];
        end
        switch t
            case 1, candX = feat.microaneurysms.centroidX; candY = feat.microaneurysms.centroidY;
            case 2, candX = feat.haemorrhages.centroidX;   candY = feat.haemorrhages.centroidY;
            case 3, candX = feat.exudates.centroidX;       candY = feat.exudates.centroidY;
        end
        nC = numel(candX);
        hitGT = false(1,cc.NumObjects);
        for c = 1:nC
            d = sqrt((gtCent(:,1)-candX(c)).^2 + (gtCent(:,2)-candY(c)).^2);
            [md,bi] = min(d);
            if md <= tol, hitGT(bi) = true; end
        end
        recall = sum(hitGT)/max(cc.NumObjects,1);
        hitCand = 0;
        for c = 1:nC
            d = sqrt((gtCent(:,1)-candX(c)).^2 + (gtCent(:,2)-candY(c)).^2);
            if min(d) <= tol, hitCand = hitCand + 1; end
        end
        precision = hitCand/max(nC,1);
        D.recall(i,t)=recall; D.precision(i,t)=precision;
        D.nGT(i,t)=cc.NumObjects; D.nCand(i,t)=nC;
    end
    fprintf('%s  MA[nGT=%-3d nC=%-3d R=%.2f P=%.2f] HE[%-3d %-3d R=%.2f P=%.2f] EX[%-3d %-3d R=%.2f P=%.2f]\n', ...
        id3, D.nGT(i,1), D.nCand(i,1), D.recall(i,1), D.precision(i,1), ...
        D.nGT(i,2), D.nCand(i,2), D.recall(i,2), D.precision(i,2), ...
        D.nGT(i,3), D.nCand(i,3), D.recall(i,3), D.precision(i,3));
end

fprintf('\n===== DETECTION-LEVEL MEAN (tol=%dpx) over %d images =====\n', tol, nImages);
for t = 1:3
    fprintf('%-10s recall=%.3f  precision=%.3f\n', types{t}, ...
        mean(D.recall(:,t)), mean(D.precision(:,t)));
end
save(fullfile(outDir,'gt_detection_validation.mat'), 'D','types','tol');
fprintf('Saved: %s\n', fullfile(outDir,'gt_detection_validation.mat'));