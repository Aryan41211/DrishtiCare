function eval_segmenter_drive()
%EVAL_SEGMENTER_DRIVE Evaluate the vessel segmenter on the 20 DRIVE test images.
%   Runs segmentVesselsCnn at full native resolution (584x565, the same res the
%   CNN was trained on) and scores Dice + IoU vs the two manual segmentations
%   (1st_manual = official benchmark GT, 2nd_manual = independent observer),
%   restricted to the DRIVE FOV mask. Also reports human-vs-human (2nd vs 1st)
%   Dice as context. Test set = the open DRIVE benchmark, NOT the closed APTOS
%   test set.
%
%   Saves data/analysis/day8/task8/drive_test_dice.mat.
%   NOTE: DRIVE test manual GIFs were added to data/drive/DRIVE/test/{1st,2nd}
%   _manual; {test/1st_manual files} are the official grand-challenge GT.

projRoot = 'C:\projects\DrishtiCare';
testRoot = fullfile(projRoot,'data','drive','DRIVE','test');
outDir   = fullfile(projRoot,'data','analysis','day8','task8');
if ~exist(outDir,'dir'), mkdir(outDir); end

f = dir(fullfile(testRoot,'images','*.tif'));
f = sort({f.name});
n = numel(f);
assert(n == 20, 'DRIVE test expected 20 images, found %d', n);

dice1 = zeros(n,1); iou1 = zeros(n,1);
dice2 = zeros(n,1); iou2 = zeros(n,1);
humanDice = zeros(n,1); pixelAuc = zeros(n,1);
for i = 1:n
    numImg = i;
    I = imread(fullfile(testRoot,'images',f{i}));
    F = imread(fullfile(testRoot,'mask',sprintf('%02d_test_mask.gif',numImg))) > 0;
    G1 = imread(fullfile(testRoot,'1st_manual',sprintf('%02d_manual1.gif',numImg))) > 0;
    G2 = imread(fullfile(testRoot,'2nd_manual',sprintf('%02d_manual2.gif',numImg))) > 0;
    G1 = G1 & F; G2 = G2 & F;

    out = segmentVesselsCnn(I, struct('targetLongEdge', 584, 'STRIDE', 4));
    M = out.mask & F;
    [~,~,~,pa] = perfcurve(G1(F(:)), out.map(F(:)), true);

    [d1, u1] = diceIou(G1, M);
    [d2, u2] = diceIou(G2, M);
    dice1(i) = d1; iou1(i) = u1;
    dice2(i) = d2; iou2(i) = u2;
    humanDice(i) = diceIou(G1, G2);
    pixelAuc(i) = pa;
    fprintf('%02d  Dice(1st)=%.4f IoU=%.4f  Dice(2nd)=%.4f IoU=%.4f  human=%.4f  pxAUC=%.4f\n', ...
        numImg, d1, u1, d2, u2, humanDice(i), pa);
end

fprintf('\nDRIVE TEST (n=20, FOV-masked):\n');
fprintf('  vs 1st_manual : mean Dice=%.4f  IoU=%.4f  (median %.4f/%.4f)\n', ...
    mean(dice1), mean(iou1), median(dice1), median(iou1));
fprintf('  vs 2nd_manual : mean Dice=%.4f  IoU=%.4f\n', mean(dice2), mean(iou2));
fprintf('  human(2nd vs 1st) inter-observer Dice=%.4f\n', mean(humanDice));
fprintf('  pixel-level ROC-AUC (map vs 1st_manual) mean=%.4f\n', mean(pixelAuc));

save(fullfile(outDir,'drive_test_dice.mat'), 'dice1','iou1','dice2','iou2','humanDice','pixelAuc','-v7.3');
fprintf('Saved %s\n', fullfile(outDir,'drive_test_dice.mat'));
end

function [d, u] = diceIou(A, B)
    inter = sum(A(:) & B(:));
    d = 2*inter / (sum(A(:)) + sum(B(:)));
    u = inter / (sum(A(:) | B(:)));
end