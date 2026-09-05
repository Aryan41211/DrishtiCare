function metrics = evaluateBinaryClassifier(trainedNet, valDSraw, varargin)
% EVALUATEBINARYCLASSIFIER Evaluate 2-class referable model (validation only)
%   Network classes: 'nonreferable' (idx 1), 'referable' (idx 2)
%   Saves ROC data + threshold sweep. Test set untouched.

    p = inputParser;
    addParameter(p, 'Config', [], @(x) isstruct(x));
    addParameter(p, 'ExperimentId', 'day6_binary_referable_v1', @ischar);
    parse(p, varargin{:});
    config = p.Results.Config;
    experimentId = p.Results.ExperimentId;
    if isempty(config)
        config = defaultTrainingConfig();
    end

    fileCount = length(valDSraw.Files);
    fprintf('Evaluating binary model on %d validation files...\n', fileCount);

    YTrue = false(fileCount, 1);
    PRef = zeros(fileCount, 1);
    for i = 1:fileCount
        img = imresize(imread(valDSraw.Files{i}), config.input.imageSize(1:2));
        scores = predict(trainedNet, img);
        scores = scores(:)';
        % Network class order is alphabetical: nonreferable, referable
        PRef(i) = scores(2);

        [~, folderName] = fileparts(fileparts(valDSraw.Files{i}));
        YTrue(i) = strcmp(folderName, 'referable');
        if mod(i, 100) == 0, fprintf('  %d/%d\n', i, fileCount); end
    end

    % Default 0.5 operating point
    YPred = PRef >= 0.5;
    tp = sum(YTrue & YPred); fp = sum(~YTrue & YPred);
    fn = sum(YTrue & ~YPred); tn = sum(~YTrue & ~YPred);
    sens = tp/(tp+fn+eps); spec = tn/(tn+fp+eps);
    ppv = tp/(tp+fp+eps);
    f1 = 2*ppv*sens/(ppv+sens+eps);
    acc = (tp+tn)/fileCount;

    % ROC-AUC and PR-AUC
    [~, ~, ~, auc] = perfcurve(YTrue, PRef, true);
    [rec, prec, ~, auprc] = perfcurve(YTrue, PRef, true, ...
        'XCrit', 'reca', 'YCrit', 'prec');

    % Threshold sweep 0.05..0.95
    thresholds = 0.05:0.05:0.95;
    n = length(thresholds);
    sSens = zeros(n,1); sSpec = zeros(n,1); sPPV = zeros(n,1); sF1 = zeros(n,1);
    for k = 1:n
        Yp = PRef >= thresholds(k);
        tpk = sum(YTrue & Yp); fpk = sum(~YTrue & Yp);
        fnk = sum(YTrue & ~Yp); tnk = sum(~YTrue & ~Yp);
        sSens(k) = tpk/(tpk+fnk+eps);
        sSpec(k) = tnk/(tnk+fpk+eps);
        sPPV(k) = tpk/(tpk+fpk+eps);
        sF1(k) = 2*sPPV(k)*sSens(k)/(sPPV(k)+sSens(k)+eps);
    end
    okIdx = find(sSens >= 0.90, 1, 'last');
    if isempty(okIdx)
        [~, okIdx] = max(sF1);
        fprintf('NOTE: no threshold reaches 90%% sensitivity. Reporting max-F1.\n');
    end

    metrics = struct();
    metrics.date = datestr(now);
    metrics.accuracy = acc; metrics.sensitivity = sens;
    metrics.specificity = spec; metrics.ppv = ppv; metrics.f1 = f1;
    metrics.auc = auc; metrics.auprc = auprc;
    metrics.rocRecall = rec; metrics.rocPrecision = prec;
    metrics.tp = tp; metrics.fp = fp; metrics.fn = fn; metrics.tn = tn;
    metrics.thresholds = thresholds(:);
    metrics.thrSens = sSens; metrics.thrSpec = sSpec;
    metrics.thrPPV = sPPV; metrics.thrF1 = sF1;
    metrics.chosenThreshold = thresholds(okIdx);
    metrics.chosenSens = sSens(okIdx);
    metrics.chosenSpec = sSpec(okIdx);
    metrics.note = 'Validation-only. Official test set untouched.';

    fprintf('\n=== Binary Referable Results (thr=0.50) ===\n');
    fprintf('Accuracy: %.2f%%  Sens: %.4f  Spec: %.4f\n', acc*100, sens, spec);
    fprintf('PPV: %.4f  F1: %.4f  ROC-AUC: %.4f  PR-AUC: %.4f\n', ppv, f1, auc, auprc);
    fprintf('TP=%d FP=%d FN=%d TN=%d\n', tp, fp, fn, tn);
    fprintf('Chosen: thr=%.2f sens=%.4f spec=%.4f\n', ...
        metrics.chosenThreshold, metrics.chosenSens, metrics.chosenSpec);

    outDir = fullfile(config.dataset.projectRoot, 'data', 'analysis', 'day6', 'binary');
    if ~exist(outDir, 'dir'), mkdir(outDir); end
    save(fullfile(outDir, [experimentId '_metrics.mat']), 'metrics');
    fprintf('Saved: %s\n', fullfile(outDir, [experimentId '_metrics.mat']));
end