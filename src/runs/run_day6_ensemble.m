function run_day6_ensemble()
% RUN_DAY6_ENSEMBLE Probability ensemble of baseline + balanced models
%   Uses ONLY validation data. Official test set untouched.
%
%   Saves everything under data/analysis/day6/ensemble/
%   Never overwrites day5_resnet18_baseline_stage2.mat

    project_root = pwd;
    addpath(fullfile(project_root, 'src', 'setup'));
    addpath(fullfile(project_root, 'src', 'quality'));
    addpath(fullfile(project_root, 'src', 'enhancement'));
    addpath(fullfile(project_root, 'src', 'grading'));

    fprintf('============================================\n');
    fprintf('   DrishtiCare - Day 6 Ensemble (val only)   \n');
    fprintf('============================================\n\n');

    config = defaultTrainingConfig();
    outDir = fullfile(project_root, 'data', 'analysis', 'day6', 'ensemble');
    if ~exist(outDir, 'dir')
        mkdir(outDir);
    end

    %% Load both models (read-only, never overwrite)
    basePath = fullfile(config.dataset.modelDir, 'day5_resnet18_baseline_stage2.mat');
    balPath = fullfile(config.dataset.modelDir, 'day6_resnet18_balanced_stage2.mat');
    assert(exist(basePath, 'file') == 2, 'Baseline model missing: %s', basePath);
    assert(exist(balPath, 'file') == 2, 'Balanced model missing: %s', balPath);

    B = load(basePath, 'trainedNet');
    L = load(balPath, 'trainedNet');
    netBase = B.trainedNet;
    netBal = L.trainedNet;
    fprintf('[PASS] Both models loaded (champion untouched)\n');

    %% Fixed ordered file list (same for both models)
    valDir = fullfile(config.dataset.splitDir, 'val');
    valDSraw = imageDatastore(valDir, 'IncludeSubfolders', true, ...
        'LabelSource', 'foldernames');
    valDSraw.Files = sort(valDSraw.Files);
    % Re-derive labels in sorted order
    fileCount = length(valDSraw.Files);
    YTrue = zeros(fileCount, 1);
    for i = 1:fileCount
        [~, folderName] = fileparts(fileparts(valDSraw.Files{i}));
        tokens = regexp(folderName, 'class_(\d+)', 'tokens');
        YTrue(i) = str2double(tokens{1}{1}) + 1;
    end
    fprintf('[PASS] Validation set: %d files, fixed order\n', fileCount);

    %% Collect probabilities from both models
    PBase = zeros(fileCount, 5);
    PBal = zeros(fileCount, 5);
    fprintf('Collecting baseline probabilities...\n');
    for i = 1:fileCount
        img = imresize(imread(valDSraw.Files{i}), config.input.imageSize(1:2));
        s = predict(netBase, img);
        PBase(i, :) = s(:)';
        if mod(i, 200) == 0, fprintf('  %d/%d\n', i, fileCount); end
    end
    fprintf('Collecting balanced probabilities...\n');
    for i = 1:fileCount
        img = imresize(imread(valDSraw.Files{i}), config.input.imageSize(1:2));
        s = predict(netBal, img);
        PBal(i, :) = s(:)';
        if mod(i, 200) == 0, fprintf('  %d/%d\n', i, fileCount); end
    end

    % Verify both are valid probability distributions in same class order
    assert(all(abs(sum(PBase, 2) - 1) < 1e-3), 'Baseline scores not probabilities');
    assert(all(abs(sum(PBal, 2) - 1) < 1e-3), 'Balanced scores not probabilities');
    fprintf('[PASS] Both outputs are 5-class distributions, order class_0..class_4\n');

    save(fullfile(outDir, 'day6_ensemble_v1_probs.mat'), ...
        'PBase', 'PBal', 'YTrue', '-v7.3');
    fprintf('Saved probabilities: %s\n', fullfile(outDir, 'day6_ensemble_v1_probs.mat'));

    %% Weight search
    weights = 0.0:0.1:1.0;  % weight_baseline; weight_balanced = 1 - w
    nW = length(weights);
    acc = zeros(nW,1); mf1 = zeros(nW,1); qwk = zeros(nW,1);
    sens = zeros(nW,1); spec = zeros(nW,1); f1r = zeros(nW,1);

    fprintf('\n=== Ensemble Weight Search (validation) ===\n');
    fprintf('%-8s %-8s %-8s %-8s %-8s %-8s %-8s\n', ...
        'w_base', 'Acc', 'MacroF1', 'QWK', 'Sens', 'Spec', 'RefF1');
    for k = 1:nW
        w = weights(k);
        P = w * PBase + (1 - w) * PBal;
        [~, YPred] = max(P, [], 2);
        m = fiveClassMetrics(YTrue, YPred, config);
        acc(k) = m.accuracy; mf1(k) = m.macroF1; qwk(k) = m.qwk;
        sens(k) = m.sens; spec(k) = m.spec; f1r(k) = m.refF1;
        fprintf('%-8.1f %-8.2f %-8.4f %-8.4f %-8.4f %-8.4f %-8.4f\n', ...
            w, acc(k)*100, mf1(k), qwk(k), sens(k), spec(k), f1r(k));
    end

    % Select winner: prefer high sens, spec near/above 0.85, strong macroF1/QWK
    % Score = sens + spec + macroF1 + qwk (balanced, no single-metric overfit)
    score = sens + spec + mf1 + qwk;
    [~, bestIdx] = max(score);
    wBest = weights(bestIdx);
    fprintf('\nBest weight: w_baseline=%.1f (score=%.4f)\n', wBest, score(bestIdx));

    %% Threshold sweep on best ensemble
    PBest = wBest * PBase + (1 - wBest) * PBal;
    PRef = sum(PBest(:, 3:5), 2);  % P(Moderate)+P(Severe)+P(Proliferative)
    YTrueRef = ismember(YTrue, config.classes.referable);
    thresholds = 0.05:0.05:0.95;
    [thrSens, thrSpec, thrPPV, thrF1] = sweepThresholds(YTrueRef, PRef, thresholds);

    fprintf('\n=== Best-ensemble Threshold Sweep (validation) ===\n');
    fprintf('%-6s %-8s %-8s %-8s %-8s\n', 'Thr', 'Sens', 'Spec', 'PPV', 'F1');
    for k = 1:length(thresholds)
        fprintf('%-6.2f %-8.4f %-8.4f %-8.4f %-8.4f\n', ...
            thresholds(k), thrSens(k), thrSpec(k), thrPPV(k), thrF1(k));
    end

    % Operating point: first threshold reaching sens >= 0.90, else max F1
    okIdx = find(thrSens >= 0.90, 1, 'last');  % last = highest spec among those
    if isempty(okIdx)
        [~, okIdx] = max(thrF1);
        fprintf('NOTE: no threshold reaches 90%% sensitivity. Reporting max-F1 point.\n');
    end
    fprintf('Chosen: thr=%.2f sens=%.4f spec=%.4f F1=%.4f\n', ...
        thresholds(okIdx), thrSens(okIdx), thrSpec(okIdx), thrF1(okIdx));

    %% Save all
    ensemble = struct();
    ensemble.date = datestr(now);
    ensemble.weights = weights(:);
    ensemble.accuracy = acc; ensemble.macroF1 = mf1; ensemble.qwk = qwk;
    ensemble.sens = sens; ensemble.spec = spec; ensemble.refF1 = f1r;
    ensemble.bestWeight = wBest;
    ensemble.thresholds = thresholds(:);
    ensemble.thrSens = thrSens; ensemble.thrSpec = thrSpec;
    ensemble.thrPPV = thrPPV; ensemble.thrF1 = thrF1;
    ensemble.chosenThreshold = thresholds(okIdx);
    ensemble.chosenSens = thrSens(okIdx);
    ensemble.chosenSpec = thrSpec(okIdx);
    ensemble.note = 'Validation-only. Official test set untouched.';
    save(fullfile(outDir, 'day6_ensemble_v1_results.mat'), 'ensemble');
    fprintf('\nSaved: %s\n', fullfile(outDir, 'day6_ensemble_v1_results.mat'));

    %% Plots
    fig = figure('Visible', 'off');
    plot(weights, sens, 'b-o', weights, spec, 'r-s', weights, mf1, 'g-^');
    xlabel('Baseline weight'); ylabel('Score');
    title('Ensemble Weight Search (validation)');
    legend('Ref Sens', 'Ref Spec', 'Macro F1', 'Location', 'best'); grid on;
    saveas(fig, fullfile(outDir, 'day6_ensemble_v1_weights.png')); close(fig);

    fig = figure('Visible', 'off');
    plot(thresholds, thrSens, 'b-o', thresholds, thrSpec, 'r-s', thresholds, thrF1, 'g-^');
    xlabel('P(referable) threshold'); ylabel('Score');
    title('Best-ensemble Threshold Sweep (validation)');
    legend('Sensitivity', 'Specificity', 'F1', 'Location', 'best'); grid on;
    saveas(fig, fullfile(outDir, 'day6_ensemble_v1_threshold.png')); close(fig);
    fprintf('Saved plots.\n');

    fprintf('\nDone. Champion preserved. Test set untouched.\n');
end

function m = fiveClassMetrics(YTrue, YPred, config)
    numClasses = 5;
    confMat = zeros(numClasses);
    for i = 1:length(YTrue)
        confMat(YTrue(i), YPred(i)) = confMat(YTrue(i), YPred(i)) + 1;
    end
    prec = zeros(5,1); rec = zeros(5,1); f1 = zeros(5,1);
    for c = 1:5
        tp = confMat(c,c);
        fp = sum(confMat(:,c)) - tp;
        fn = sum(confMat(c,:)) - tp;
        prec(c) = tp/(tp+fp+eps);
        rec(c) = tp/(tp+fn+eps);
        f1(c) = 2*prec(c)*rec(c)/(prec(c)+rec(c)+eps);
    end
    m.accuracy = sum(YPred == YTrue)/length(YTrue);
    m.macroF1 = mean(f1);
    m.qwk = qwkScore(YTrue, YPred, numClasses);
    Yt = ismember(YTrue, config.classes.referable);
    Yp = ismember(YPred, config.classes.referable);
    tp = sum(Yt & Yp); fp = sum(~Yt & Yp);
    fn = sum(Yt & ~Yp); tn = sum(~Yt & ~Yp);
    m.sens = tp/(tp+fn+eps);
    m.spec = tn/(tn+fp+eps);
    ppv = tp/(tp+fp+eps);
    m.refF1 = 2*ppv*m.sens/(ppv+m.sens+eps);
    m.confMat = confMat;
end

function q = qwkScore(yTrue, yPred, numClasses)
    n = length(yTrue);
    W = zeros(numClasses);
    for i = 1:numClasses
        for j = 1:numClasses
            W(i,j) = (i-j)^2/(numClasses-1)^2;
        end
    end
    O = zeros(numClasses);
    for i = 1:n
        O(yTrue(i), yPred(i)) = O(yTrue(i), yPred(i)) + 1;
    end
    rs = sum(O,2); cs = sum(O,1);
    E = (rs * cs) / n;
    q = 1 - sum(W(:).*O(:)) / (sum(W(:).*E(:)) + eps);
end

function [sens, spec, ppv, f1] = sweepThresholds(YTrueRef, PRef, thresholds)
    n = length(thresholds);
    sens = zeros(n,1); spec = zeros(n,1); ppv = zeros(n,1); f1 = zeros(n,1);
    for k = 1:n
        Yp = PRef >= thresholds(k);
        tp = sum(YTrueRef & Yp); fp = sum(~YTrueRef & Yp);
        fn = sum(YTrueRef & ~Yp); tn = sum(~YTrueRef & ~Yp);
        sens(k) = tp/(tp+fn+eps);
        spec(k) = tn/(tn+fp+eps);
        ppv(k) = tp/(tp+fp+eps);
        f1(k) = 2*ppv(k)*sens(k)/(ppv(k)+sens(k)+eps);
    end
end