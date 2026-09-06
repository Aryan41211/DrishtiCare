%% TASK 3: PR-AUC Regression Investigation
% Compares old scratch binary vs new pretrained binary on validation set
% Plots overlaid PR curves, reports precision at locked threshold 0.60

projRoot = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(projRoot,'src'), fullfile(projRoot,'src','grading'), fullfile(projRoot,'src','inference'));
cd(projRoot);
fprintf('=== TASK 3: PR-AUC REGRESSION INVESTIGATION ===\n\n');

%% Load old scratch binary metrics (pre-computed PR curve)
oldM = load(fullfile(projRoot,'data','analysis','day6','binary','day6_binary_referable_v1_metrics.mat'),'metrics');
old = oldM.metrics;
fprintf('OLD scratch binary (pre-computed):\n');
fprintf('  ROC-AUC: %.4f, PR-AUC: %.4f\n', old.auc, old.auprc);

%% Load new pretrained binary model
load(fullfile(projRoot,'data','models','day7_pretrained_resnet18_binary_stage2.mat'),'trainedNet');
newNet = trainedNet;

%% Load validation binary data
valFolders = {fullfile(projRoot,'data','splits_binary','val','nonreferable'), ...
              fullfile(projRoot,'data','splits_binary','val','referable')};
allFiles = {};
allTrue = [];
for c = 1:2
    d = dir(fullfile(valFolders{c}, '*.png'));
    for i = 1:length(d)
        allFiles{end+1} = fullfile(d(i).folder, d(i).name);
        allTrue(end+1) = c - 1;
    end
end
nVal = length(allFiles);
nNonRef = sum(allTrue == 0);
nRef = sum(allTrue == 1);
fprintf('\nValidation: %d images (nonref=%d, ref=%d)\n', nVal, nNonRef, nRef);

%% Get referable probability from NEW pretrained binary
fprintf('\nScoring new pretrained binary...\n');
newPRef = zeros(nVal, 1);
tic;
for i = 1:nVal
    img = imresize(imread(allFiles{i}), [224 224]);
    scores = predict(newNet, img);
    scores = scores(:)';
    newPRef(i) = scores(2);
    if mod(i, 200) == 0, fprintf('  %d/%d\n', i, nVal); end
end
tNew = toc;
fprintf('  Done in %.1fs\n', tNew);

%% Get referable probability from OLD scratch binary
fprintf('Scoring old scratch binary...\n');
load(fullfile(projRoot,'data','models','day6_binary_referable_v1_stage2.mat'),'trainedNet');
oldNet = trainedNet;
oldPRef = zeros(nVal, 1);
tic;
for i = 1:nVal
    img = imresize(imread(allFiles{i}), [224 224]);
    scores = predict(oldNet, img);
    scores = scores(:)';
    oldPRef(i) = scores(2);
    if mod(i, 200) == 0, fprintf('  %d/%d\n', i, nVal); end
end
tOld = toc;
fprintf('  Done in %.1fs\n', tOld);

%% ROC-AUC for both (computed fresh for fair comparison)
[~,~,~,oldAUC] = perfcurve(allTrue', oldPRef, 1);
[~,~,~,newAUC] = perfcurve(allTrue', newPRef, 1);
fprintf('\n--- ROC-AUC (fresh computation) ---\n');
fprintf('  Old scratch: %.4f\n', oldAUC);
fprintf('  New pretrained: %.4f\n', newAUC);

%% PR curves for both (fresh computation)
[oldRec, oldPrec, ~, oldPRAUC] = perfcurve(allTrue', oldPRef, 1, 'XCrit','reca','YCrit','prec');
[newRec, newPrec, ~, newPRAUC] = perfcurve(allTrue', newPRef, 1, 'XCrit','reca','YCrit','prec');
fprintf('\n--- PR-AUC (fresh computation) ---\n');
fprintf('  Old scratch: %.4f\n', oldPRAUC);
fprintf('  New pretrained: %.4f\n', newPRAUC);
fprintf('  Delta: %.4f\n', newPRAUC - oldPRAUC);

%% Precision at locked threshold 0.60
thr = 0.60;
oldTP = sum(allTrue'==1 & oldPRef>=thr);
oldFP = sum(allTrue'==0 & oldPRef>=thr);
oldFN = sum(allTrue'==1 & oldPRef<thr);
oldTN = sum(allTrue'==0 & oldPRef<thr);
oldPrecAt = oldTP / max(oldTP+oldFP, 1);
oldSensAt = oldTP / max(oldTP+oldFN, 1);
oldSpecAt = oldTN / max(oldTN+oldFP, 1);

newTP = sum(allTrue'==1 & newPRef>=thr);
newFP = sum(allTrue'==0 & newPRef>=thr);
newFN = sum(allTrue'==1 & newPRef<thr);
newTN = sum(allTrue'==0 & newPRef<thr);
newPrecAt = newTP / max(newTP+newFP, 1);
newSensAt = newTP / max(newTP+newFN, 1);
newSpecAt = newTN / max(newTN+newFP, 1);

fprintf('\n--- AT LOCKED THRESHOLD 0.60 ---\n');
fprintf('  Old scratch:    prec=%.4f  sens=%.4f  spec=%.4f  (TP=%d FP=%d FN=%d TN=%d)\n', ...
    oldPrecAt, oldSensAt, oldSpecAt, oldTP, oldFP, oldFN, oldTN);
fprintf('  New pretrained: prec=%.4f  sens=%.4f  spec=%.4f  (TP=%d FP=%d FN=%d TN=%d)\n', ...
    newPrecAt, newSensAt, newSpecAt, newTP, newFP, newFN, newTN);
fprintf('  Precision delta: %.4f\n', newPrecAt - oldPrecAt);

if newPrecAt < oldPrecAt
    fprintf('  >>> FLAG: New model has LOWER precision at thr=0.60 — more false positives <<<\n');
end

%% Score distribution analysis
refIdx = (allTrue' == 1);
nonrefIdx = (allTrue' == 0);
fprintf('\n--- SCORE DISTRIBUTIONS ---\n');
fprintf('  OLD ref:    mean=%.4f std=%.4f median=%.4f\n', mean(oldPRef(refIdx)), std(oldPRef(refIdx)), median(oldPRef(refIdx)));
fprintf('  OLD nonref: mean=%.4f std=%.4f median=%.4f\n', mean(oldPRef(nonrefIdx)), std(oldPRef(nonrefIdx)), median(oldPRef(nonrefIdx)));
fprintf('  NEW ref:    mean=%.4f std=%.4f median=%.4f\n', mean(newPRef(refIdx)), std(newPRef(refIdx)), median(newPRef(refIdx)));
fprintf('  NEW nonref: mean=%.4f std=%.4f median=%.4f\n', mean(newPRef(nonrefIdx)), std(newPRef(nonrefIdx)), median(newPRef(nonrefIdx)));

% How many nonref images are in the "danger zone" (0.3-0.7)?
oldDanger = sum(oldPRef(nonrefIdx) >= 0.3 & oldPRef(nonrefIdx) <= 0.7);
newDanger = sum(newPRef(nonrefIdx) >= 0.3 & newPRef(nonrefIdx) <= 0.7);
fprintf('  Nonref in danger zone [0.3,0.7]: old=%d (%.1f%%) new=%d (%.1f%%)\n', ...
    oldDanger, oldDanger/nNonRef*100, newDanger, newDanger/nNonRef*100);

%% Plot overlaid PR curves
fig = figure('Visible','off','Position',[100 100 900 700]);
plot(oldRec, oldPrec, 'b-', 'LineWidth', 2.5); hold on;
plot(newRec, newPrec, 'r-', 'LineWidth', 2.5);
xline(thr, 'k--', 'LineWidth', 1.5);
xlabel('Recall (Sensitivity)', 'FontSize', 12);
ylabel('Precision (PPV)', 'FontSize', 12);
title(sprintf('PR Curves: Scratch vs Pretrained Binary (val n=%d)', nVal), 'FontSize', 14);
legend({sprintf('Scratch binary (PR-AUC=%.4f)', oldPRAUC), ...
        sprintf('Pretrained binary (PR-AUC=%.4f)', newPRAUC), ...
        sprintf('Locked threshold=%.2f', thr)}, ...
       'Location', 'southwest', 'FontSize', 11);
grid on; set(gca, 'FontSize', 11);
saveas(fig, fullfile(projRoot,'data','analysis','day7','figures','pr_curve_comparison.png'));
fprintf('\nPR curve plot saved: data/analysis/day7/figures/pr_curve_comparison.png\n');

%% Save results
result = struct();
result.date = datestr(now);
result.nVal = nVal;
result.oldROC_AUC = oldAUC;
result.newROC_AUC = newAUC;
result.oldPR_AUC = oldPRAUC;
result.newPR_AUC = newPRAUC;
result.oldPrecAt060 = oldPrecAt;
result.newPrecAt060 = newPrecAt;
result.oldSensAt060 = oldSensAt;
result.newSensAt060 = newSensAt;
result.oldSpecAt060 = oldSpecAt;
result.newSpecAt060 = newSpecAt;
result.status = 'DIAGNOSTIC_ONLY';
save(fullfile(projRoot,'data','analysis','day7','pr_auc_investigation.mat'), 'result');
fprintf('Results saved: data/analysis/day7/pr_auc_investigation.mat\n');

fprintf('\n=== TASK 3 COMPLETE ===\n');
