function evaluate_task9b_ab()
% EVALUATE_TASK9B_AB Evaluate both Task 9B A/B variants on 733-val
%   evaluate_task9b_ab()
%
%   Loads both stage-2 models, evaluates on 733-val with matching
%   preprocessing. Reports acc, macro-F1, QWK, per-class recall,
%   confusion matrices, and cross-condition diagnostics.

    fprintf('=== Task 9B A/B Evaluation ===\n');
    fprintf('Date: %s\n', datestr(now));

    projectRoot = pwd;
    addpath(genpath(fullfile(projectRoot, 'src')));

    modelDir = fullfile(projectRoot, 'data', 'models');
    rawModelPath = fullfile(modelDir, 'day9_5class_raw_stage2.mat');
    enhModelPath = fullfile(modelDir, 'day9_5class_enh_stage2.mat');

    if ~exist(rawModelPath, 'file')
        error('Raw model not found: %s', rawModelPath);
    end
    if ~exist(enhModelPath, 'file')
        error('Enhanced model not found: %s', enhModelPath);
    end

    S1 = load(rawModelPath, 'trainedNet', 'info', 'trainingTime');
    S2 = load(enhModelPath, 'trainedNet', 'info', 'trainingTime');
    netRaw = S1.trainedNet;
    netEnh = S2.trainedNet;
    infoRaw = S1.info;
    infoEnh = S2.info;
    timeRaw = S1.trainingTime;
    timeEnh = S2.trainingTime;

    fprintf('Raw model: %s, %d epochs stage2\n', class(netRaw), length(infoRaw.TrainingLoss));
    fprintf('Enh model: %s, %d epochs stage2\n', class(netEnh), length(infoEnh.TrainingLoss));

    valDirRaw = fullfile(projectRoot, 'data', 'splits', 'val');
    valDirEnh = fullfile(projectRoot, 'data', 'splits_enhanced', 'val');

    classNames = {'NoDR', 'Mild', 'Moderate', 'Severe', 'Proliferative'};
    numClasses = 5;
    classNamesMap = containers.Map({'class_0','class_1','class_2','class_3','class_4'}, ...
        1:5);

    function [yTrue, yPred, scores] = evalNet(net, valDir, doEnhance)
        ds = imageDatastore(valDir, 'IncludeSubfolders', true, 'LabelSource', 'foldernames');
        ds.Files = sort(ds.Files);
        n = numel(ds.Files);
        yTrue = zeros(n, 1);
        yPred = zeros(n, 1);
        scores = zeros(n, numClasses);
        fprintf('Evaluating %d images (enhance=%d)...\n', n, doEnhance);
        for i = 1:n
            img = imread(ds.Files{i});
            if doEnhance
                img = enhanceImage(img);
            end
            img = imresize(img, [224 224]);
            pathParts = strrep(strrep(ds.Files{i}, '/', '\'), '\', '/');
            tokens = regexp(pathParts, 'class_(\d+)', 'tokens');
            yTrue(i) = str2double(tokens{end}{1}) + 1;
            sc = predict(net, img);
            sc = sc(:)';
            scores(i, :) = sc;
            [~, yPred(i)] = max(sc);
            if mod(i, 200) == 0
                fprintf('  %d/%d\n', i, n);
            end
        end
    end

    function m = computeMetrics(yTrue, yPred, scores, numC)
        n = numel(yTrue);
        conf = zeros(numC);
        for i = 1:n
            conf(yTrue(i), yPred(i)) = conf(yTrue(i), yPred(i)) + 1;
        end
        prec = zeros(numC, 1);
        rec = zeros(numC, 1);
        f1v = zeros(numC, 1);
        for c = 1:numC
            tp = conf(c, c);
            fp = sum(conf(:, c)) - tp;
            fn = sum(conf(c, :)) - tp;
            prec(c) = tp / (tp + fp + eps);
            rec(c) = tp / (tp + fn + eps);
            f1v(c) = 2 * prec(c) * rec(c) / (prec(c) + rec(c) + eps);
        end
        macroF1 = mean(f1v);
        acc = sum(yPred == yTrue) / n;
        W = zeros(numC);
        for i = 1:numC
            for j = 1:numC
                W(i, j) = (i - j)^2 / (numC - 1)^2;
            end
        end
        O = zeros(numC);
        for i = 1:n
            O(yTrue(i), yPred(i)) = O(yTrue(i), yPred(i)) + 1;
        end
        rowS = sum(O, 2);
        colS = sum(O, 1);
        E = zeros(numC);
        for i = 1:numC
            for j = 1:numC
                E(i, j) = rowS(i) * colS(j) / n;
            end
        end
        numer = sum(W(:) .* O(:));
        denom = sum(W(:) .* E(:));
        qwk = 1 - numer / (denom + eps);
        m = struct();
        m.accuracy = acc;
        m.macroF1 = macroF1;
        m.qwk = qwk;
        m.precision = prec;
        m.recall = rec;
        m.f1 = f1v;
        m.confusionMatrix = conf;
        m.n = n;
    end

    fprintf('\n--- Variant A: netRaw on raw val ---\n');
    tic;
    [yTrueA, yPredA, scoresA] = evalNet(netRaw, valDirRaw, false);
    tA = toc;
    mPrimaryA = computeMetrics(yTrueA, yPredA, scoresA, numClasses);

    fprintf('\n--- Variant B: netEnh on enhanced val ---\n');
    tic;
    [yTrueB, yPredB, scoresB] = evalNet(netEnh, valDirEnh, true);
    tB = toc;
    mPrimaryB = computeMetrics(yTrueB, yPredB, scoresB, numClasses);

    fprintf('\n--- Cross-condition: netRaw on enhanced val ---\n');
    tic;
    [yTrueCR, yPredCR, scoresCR] = evalNet(netRaw, valDirEnh, true);
    tCR = toc;
    mCrossRaw = computeMetrics(yTrueCR, yPredCR, scoresCR, numClasses);

    fprintf('\n--- Cross-condition: netEnh on raw val ---\n');
    tic;
    [yTrueCE, yPredCE, scoresCE] = evalNet(netEnh, valDirRaw, false);
    tCE = toc;
    mCrossEnh = computeMetrics(yTrueCE, yPredCE, scoresCE, numClasses);

    fprintf('\n============================================================\n');
    fprintf('  TASK 9B A/B RESULTS (5-class only)\n');
    fprintf('============================================================\n');
    fprintf('%-20s %10s %10s %10s\n', 'Metric', 'A (raw)', 'B (enh)', 'Delta');
    fprintf('%-20s %10s %10s %10s\n', '------', '-------', '--------', '-----');
    fprintf('%-20s %10.4f %10.4f %+10.4f\n', 'Accuracy', mPrimaryA.accuracy, mPrimaryB.accuracy, mPrimaryB.accuracy - mPrimaryA.accuracy);
    fprintf('%-20s %10.4f %10.4f %+10.4f\n', 'Macro-F1', mPrimaryA.macroF1, mPrimaryB.macroF1, mPrimaryB.macroF1 - mPrimaryA.macroF1);
    fprintf('%-20s %10.4f %10.4f %+10.4f\n', 'QWK', mPrimaryA.qwk, mPrimaryB.qwk, mPrimaryB.qwk - mPrimaryA.qwk);

    fprintf('\nPer-class recall:\n');
    fprintf('%-20s %10s %10s %10s\n', 'Class', 'A (raw)', 'B (enh)', 'Delta');
    for c = 1:numClasses
        fprintf('%-20s %10.4f %10.4f %+10.4f\n', classNames{c}, ...
            mPrimaryA.recall(c), mPrimaryB.recall(c), mPrimaryB.recall(c) - mPrimaryA.recall(c));
    end

    fprintf('\nChampion reference (raw): acc=0.8281 macroF1=0.6805 QWK=0.8914\n');
    fprintf('  recall=[0.9834 0.6081 0.7850 0.4872 0.5254]\n');

    fprintf('\n--- Cross-condition diagnostics ---\n');
    fprintf('%-30s %10s %10s %10s\n', 'Condition', 'Acc', 'MacroF1', 'QWK');
    fprintf('%-30s %10.4f %10.4f %10.4f\n', 'netRaw on raw val', mPrimaryA.accuracy, mPrimaryA.macroF1, mPrimaryA.qwk);
    fprintf('%-30s %10.4f %10.4f %10.4f\n', 'netRaw on enh val', mCrossRaw.accuracy, mCrossRaw.macroF1, mCrossRaw.qwk);
    fprintf('%-30s %10.4f %10.4f %10.4f\n', 'netEnh on raw val', mCrossEnh.accuracy, mCrossEnh.macroF1, mCrossEnh.qwk);
    fprintf('%-30s %10.4f %10.4f %10.4f\n', 'netEnh on enh val', mPrimaryB.accuracy, mPrimaryB.macroF1, mPrimaryB.qwk);

    results = struct();
    results.date = datestr(now);
    results.variantNames = {'day9_5class_raw', 'day9_5class_enh'};
    results.primary.raw = mPrimaryA;
    results.primary.enhanced = mPrimaryB;
    results.primary.raw.evalTimeSeconds = tA;
    results.primary.enhanced.evalTimeSeconds = tB;
    results.crossCondition.netRawOnEnhanced = mCrossRaw;
    results.crossCondition.netRawOnEnhanced.evalTimeSeconds = tCR;
    results.crossCondition.netEnhancedOnRaw = mCrossEnh;
    results.crossCondition.netEnhancedOnRaw.evalTimeSeconds = tCE;
    results.championReference.accuracy = 0.8281;
    results.championReference.macroF1 = 0.6805;
    results.championReference.qwk = 0.8914;
    results.championReference.recall = [0.9834 0.6081 0.7850 0.4872 0.5254];
    results.championReference.label = 'reference-on-raw';
    results.rawModel.trainingTimeStage2 = timeRaw;
    results.enhModel.trainingTimeStage2 = timeEnh;
    results.rawModel.epochsStage2 = length(infoRaw.TrainingLoss);
    results.enhModel.epochsStage2 = length(infoEnh.TrainingLoss);
    results.valUsed = '733 images from data/splits/val and data/splits_enhanced/val';
    results.classNames = classNames;

    analysisDir = fullfile(projectRoot, 'data', 'analysis', 'day9');
    if ~exist(analysisDir, 'dir')
        mkdir(analysisDir);
    end
    save(fullfile(analysisDir, 'task9b_ab_eval.mat'), 'results');
    fprintf('\nSaved %s\n', fullfile(analysisDir, 'task9b_ab_eval.mat'));
end
