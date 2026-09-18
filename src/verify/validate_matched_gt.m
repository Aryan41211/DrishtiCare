%% VALIDATE (clean): matched-filter MA/HE detector vs GT, detector-scale frame
%  Mirrors the working probe: resized GT to the detector's downscaled size
%  via imresize (not crude decimation), match in downscaled frame.

projRoot = 'C:\projects\DrishtiCare';
cd(projRoot);
addpath(fullfile(projRoot,'src','lesions'), fullfile(projRoot,'src','quality'));

origDir = fullfile(projRoot,'data','idrid','A. Segmentation','1. Original Images','a. Training Set');
gtRoot = fullfile(projRoot,'data','idrid','A. Segmentation','2. All Segmentation Groundtruths','a. Training Set');
outDir = fullfile(projRoot,'data','analysis','day8','lesion_gt_validation');
s = 2; tolDS = 6;   % 6px tolerant in downscaled frame (12px orig)

nImages = 10; imgFiles = dir(fullfile(origDir,'*.jpg'));
types = {'MA','HE'};
gtFolders = {'1. Microaneurysms','2. Haemorrhages'};
suf = {'_MA.tif','_HE.tif'};
R = zeros(nImages,2); P = zeros(nImages,2); nGT = zeros(nImages,2); nC = zeros(nImages,2);
for i=1:nImages
    numStr = regexp(imgFiles(i).name,'IDRiD_(\d+)\.jpg','tokens','once');
    num2 = str2double(numStr{1}); id3 = sprintf('IDRiD_%03d',num2);
    imgPath = fullfile(origDir,imgFiles(i).name);
    I = im2double(imread(imgPath)); [H,W,~]=size(I);
    out = detectRedLesions(imgPath, struct('verbose',false));
    for t=1:2
        gtm = imresize(imread(fullfile(gtRoot,gtFolders{t},sprintf('IDRiD_%02d%s',num2,suf{t})))>0,[H/s W/s])>0.3;
        cc = bwconncomp(gtm); nGT(i,t)=cc.NumObjects;
        gtC = zeros(cc.NumObjects,2);
        for b=1:cc.NumObjects
            [yy,xx]=ind2sub(size(gtm),cc.PixelIdxList{b}); gtC(b,:)=[mean(xx) mean(yy)];
        end
        if t==1, cx=out.microaneurysms.centroidX; cy=out.microaneurysms.centroidY;
        else,    cx=out.haemorrhages.centroidX;   cy=out.haemorrhages.centroidY; end
        cx = cx/s; cy = cy/s;   % detector stores ORIG coords; divide by s
        nC(i,t)=numel(cx);
        hitG=false(1,cc.NumObjects); hitC=0;
        for c=1:numel(cx)
            d = sqrt((gtC(:,1)-cx(c)).^2 + (gtC(:,2)-cy(c)).^2);
            [md,bi]=min(d); if md<=tolDS, hitC=hitC+1; hitG(bi)=true; end
        end
        R(i,t)=mean(hitG); P(i,t)=hitC/max(nC(i,t),1);
    end
    fprintf('%s  MA[R=%.2f P=%.4f nGT=%d nC=%d] HE[R=%.2f P=%.4f nGT=%d nC=%d]\n', ...
        id3, R(i,1),P(i,1),nGT(i,1),nC(i,1), R(i,2),P(i,2),nGT(i,2),nC(i,2));
end
fprintf('\n===== MATCHED-FILTER MEAN (n=%d) =====\n', nImages);
for t=1:2
    fprintf('%-4s recall=%.3f  precision=%.3f\n', types{t}, mean(R(:,t)), mean(P(:,t)));
end
save(fullfile(outDir,'matched_filter_validation.mat'),'R','P','nGT','nC','types');