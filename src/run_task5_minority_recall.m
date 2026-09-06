%% TASK 5: Improve 5-class minority-class recall (Severe, Proliferative)
% One targeted change at a time: (a) class-weighting fix, (b) boost
% Severe/Proliferative beyond inverse-frequency, (c) targeted augmentation.
% Runs entirely on the VALIDATION set. Test set stays closed.
%
% HARD CONSTRAINT (no auto-chaining): variants (b) and (c) must NEVER start
% automatically after (a). They are gated behind the approval flags below —
% flip ONE flag to true manually, only with explicit user approval, and run
% that variant in its own session.
RUN_VARIANT_B = false;
RUN_VARIANT_C = false;

projRoot = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(projRoot,'src'), fullfile(projRoot,'src','grading'), fullfile(projRoot,'src','inference'));
cd(projRoot);

fprintf('========================================\n');
fprintf('  TASK 5: MINORITY-CLASS RECALL\n');
fprintf('========================================\n\n');

%% Baseline (already measured):
fprintf('BASELINE (day7_pretrained_resnet18_5class, val n=733):\n');
fprintf('  Severe recall       = 48.72%%\n');
fprintf('  Proliferative recall = 52.54%%\n');
fprintf('  Moderate recall      = 78.50%%\n');
fprintf('  Mild recall          = 60.81%%\n');
fprintf('  NoDR recall          = 98.34%%\n');
fprintf('  (From data/analysis/day7/bn_finalization_verification.mat, measured)\n\n');

%% Load base config + split
config = defaultPretrainedConfig('');
config.experimentId = 'day8_5class_v2a';  % artifact name day8_5class_v2a_stage2(.mat); checkpoint dir day8_5class_v2a_stage2
config.dataset.analysisDir = fullfile(projRoot, 'data', 'analysis', 'day5');

% Raw training (split only) and validation datastores
splitTrainDir = fullfile(config.dataset.splitDir, 'train');
splitValDir = fullfile(config.dataset.splitDir, 'val');
trainDSraw = imageDatastore(splitTrainDir, 'IncludeSubfolders', true, 'LabelSource', 'foldernames');
valDSraw = imageDatastore(splitValDir, 'IncludeSubfolders', true, 'LabelSource', 'foldernames');

% Validation counts (confirm no target-class starvation)
for c = 1:5
    n = sum(valDSraw.Labels == sprintf('class_%d', c-1));
    fprintf('  val class_%d: %d\n', c-1, n);
end

% Reuse day7 stage1 as frozen-head start (already trained with balanced data)
stage1Path = fullfile(config.dataset.modelDir, 'day7_pretrained_resnet18_5class_stage1.mat');

%% Helper to evaluate and record recall
evalRecallTab = @(net) evalAndRecord(net, valDSraw, config);

%% Run variant (a): class weighting fix
fprintf('\n===== VARIANT (a): CLASS WEIGHTING FIX =====\n');
[netA, infoA, balA] = trainClassifierDay8(trainDSraw, valDSraw, config, 'a', stage1Path);
metricsA = evalRecallTab(netA);
save(fullfile(projRoot,'data','models','day8_5class_v2a_stage2.mat'), 'netA', 'infoA', 'config', 'metricsA', 'balA');
fprintf('  Variant (a) done. Saved day8_5class_v2a_stage2.mat\n\n');

%% Run variant (b): boost Severe/Prolif beyond inverse-frequency
if RUN_VARIANT_B
    fprintf('\n===== VARIANT (b): BOOST SEVERE/PROLIF =====\n');
    [netB, infoB, balB] = trainClassifierDay8(trainDSraw, valDSraw, config, 'b', stage1Path);
    metricsB = evalRecallTab(netB);
    save(fullfile(projRoot,'data','models','day8_5class_v2b_stage2.mat'), 'netB', 'infoB', 'config', 'metricsB', 'balB');
    fprintf('  Variant (b) done. Saved day8_5class_v2b_stage2.mat\n\n');
else
    fprintf('\n  [SKIPPED] Variant (b): requires explicit user approval (RUN_VARIANT_B = false).\n');
end

%% Run variant (c): targeted augmentation for Severe/Prolif
if RUN_VARIANT_C
    fprintf('\n===== VARIANT (c): TARGETED AUGMENTATION =====\n');
    [netC, infoC, balC] = trainClassifierDay8(trainDSraw, valDSraw, config, 'c', stage1Path);
    metricsC = evalRecallTab(netC);
    save(fullfile(projRoot,'data','models','day8_5class_v2c_stage2.mat'), 'netC', 'infoC', 'config', 'metricsC', 'balC');
    fprintf('  Variant (c) done. Saved day8_5class_v2c_stage2.mat\n\n');
else
    fprintf('\n  [SKIPPED] Variant (c): requires explicit user approval (RUN_VARIANT_C = false).\n');
end

%% Running comparison table
fprintf('\n============================================\n');
fprintf('  RUNNING RECALL TABLE (per-class recall, %)\n');
fprintf('============================================\n');
rows = {'NoDR';'Mild';'Moderate';'Severe';'Proliferative'};
baseRecall = [0.9834 0.6081 0.7850 0.4872 0.5254];
recA = metricsA.recall;
haveB = exist('metricsB', 'var') == 1;
haveC = exist('metricsC', 'var') == 1;
if haveB, recB = metricsB.recall; end
if haveC, recC = metricsC.recall; end

if haveB && haveC
    fprintf('%-14s %8s %8s %8s %8s\n', 'Class', 'Baseline', 'V(a)', 'V(b)', 'V(c)');
    fprintf('%-14s\n', '----------');
    for r = 1:5
        fprintf('%-14s %8.2f %8.2f %8.2f %8.2f\n', rows{r}, ...
            baseRecall(r)*100, recA(r)*100, recB(r)*100, recC(r)*100);
    end
    fprintf('\nAccuracy:\n');
    fprintf('  Baseline: 82.81%%   V(a): %.2f%%   V(b): %.2f%%   V(c): %.2f%%\n', ...
        metricsA.accuracy*100, metricsB.accuracy*100, metricsC.accuracy*100);
elseif haveB
    fprintf('%-14s %8s %8s %8s\n', 'Class', 'Baseline', 'V(a)', 'V(b)');
    fprintf('%-14s\n', '----------');
    for r = 1:5
        fprintf('%-14s %8.2f %8.2f %8.2f\n', rows{r}, ...
            baseRecall(r)*100, recA(r)*100, recB(r)*100);
    end
    fprintf('\nAccuracy:\n');
    fprintf('  Baseline: 82.81%%   V(a): %.2f%%   V(b): %.2f%%\n', ...
        metricsA.accuracy*100, metricsB.accuracy*100);
elseif haveC
    fprintf('%-14s %8s %8s %8s\n', 'Class', 'Baseline', 'V(a)', 'V(c)');
    fprintf('%-14s\n', '----------');
    for r = 1:5
        fprintf('%-14s %8.2f %8.2f %8.2f\n', rows{r}, ...
            baseRecall(r)*100, recA(r)*100, recC(r)*100);
    end
    fprintf('\nAccuracy:\n');
    fprintf('  Baseline: 82.81%%   V(a): %.2f%%   V(c): %.2f%%\n', ...
        metricsA.accuracy*100, metricsC.accuracy*100);
else
    fprintf('%-14s %8s %8s\n', 'Class', 'Baseline', 'V(a)');
    fprintf('%-14s\n', '----------');
    for r = 1:5
        fprintf('%-14s %8.2f %8.2f\n', rows{r}, baseRecall(r)*100, recA(r)*100);
    end
    fprintf('\nAccuracy:\n');
    fprintf('  Baseline: 82.81%%   V(a): %.2f%%\n', metricsA.accuracy*100);
end

% Save comparison
compTable = struct();
compTable.baseline = baseRecall;
compTable.variantA = recA;
compTable.metricsA = metricsA;
compTable.balanceA = balA;
if haveB
    compTable.variantB = recB;
    compTable.metricsB = metricsB;
    compTable.balanceB = balB;
end
if haveC
    compTable.variantC = recC;
    compTable.metricsC = metricsC;
    compTable.balanceC = balC;
end
save(fullfile(projRoot,'data','analysis','day5','day8_minority_recall_comparison.mat'), 'compTable');
fprintf('\nComparison saved to data/analysis/day5/day8_minority_recall_comparison.mat\n');

fprintf('\n=== TASK 5 COMPLETE ===\n');

%% ----- helper -----
function metrics = evalAndRecord(net, valDSraw, config)
    fileCount = length(valDSraw.Files);
    numClasses = 5;
    YTrue = zeros(fileCount,1);
    YPred = zeros(fileCount,1);
    for i = 1:fileCount
        img = imread(valDSraw.Files{i});
        img = imresize(img, config.input.imageSize(1:2));
        [~, folderName] = fileparts(fileparts(valDSraw.Files{i}));
        tok = regexp(folderName, 'class_(\d+)', 'tokens');
        if ~isempty(tok), YTrue(i) = str2double(tok{1}{1}) + 1; end
        pred = classify(net, img);
        predStr = string(pred);
        pTok = regexp(predStr, 'class_(\d+)', 'tokens');
        if ~isempty(pTok), YPred(i) = str2double(pTok{1}{1}) + 1; end
        if mod(i,200)==0, fprintf('    eval %d/%d\n', i, fileCount); end
    end
    confMat = zeros(numClasses);
    for i = 1:fileCount, confMat(YTrue(i), YPred(i)) = confMat(YTrue(i), YPred(i)) + 1; end
    recall = zeros(numClasses,1);
    precision = zeros(numClasses,1);
    for c = 1:numClasses
        tp = confMat(c,c); fp = sum(confMat(:,c))-tp; fn = sum(confMat(c,:))-tp;
        precision(c) = tp/max(tp+fp,1);
        recall(c) = tp/max(tp+fn,1);
    end
    metrics = struct();
    metrics.recall = recall;
    metrics.precision = precision;
    metrics.accuracy = sum(YPred==YTrue)/fileCount;
    metrics.confusionMatrix = confMat;
    metrics.totalSamples = fileCount;
    metrics.YTrue = YTrue;
    metrics.YPred = YPred;
    metrics.macroF1 = mean(2.*precision.*recall./(precision+recall+eps));
end
