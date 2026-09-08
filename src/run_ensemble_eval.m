function run_ensemble_eval()
%RUN_ENSEMBLE_EVAL Evaluate probability-averaging ensemble of pretrained models
%   run_ensemble_eval()
%
%   Loads day7 pretrained 5-class + day8_5class_v2a, runs inference on
%   733-val, tries multiple weight splits. Reports accuracy/F1/QWK/per-class
%   recall for each. No training â€” inference only.

    fprintf('============================================\n');
    fprintf('  Ensemble Evaluation (Inference Only)\n');
    fprintf('============================================\n\n');

    projectRoot = pwd;
    addpath(genpath(fullfile(projectRoot, 'src')));

    %% Load models
    modelDir = fullfile(projectRoot, 'data', 'models');
    S7 = load(fullfile(modelDir, 'day7_pretrained_resnet18_5class_stage2.mat'), 'trainedNet');
    S8 = load(fullfile(modelDir, 'day8_5class_v2a_stage2.mat'));
    net7 = S7.trainedNet;
    net8 = S8.netA;
    fprintf('Loaded day7 champion + day8 v2a\n');

    %% Load val images
    valDir = fullfile(projectRoot, 'data', 'splits', 'val');
    classNames = {'NoDR', 'Mild', 'Moderate', 'Severe', 'Proliferative'};
    nClasses = 5;

    allFiles = {}; allLabels = [];
    for c = 1:5
        d = dir(fullfile(valDir, sprintf('class_%d', c-1), '*.png'));
        for i = 1:numel(d)
            allFiles{end+1, 1} = fullfile(valDir, sprintf('class_%d', c-1), d(i).name);
            allLabels(end+1, 1) = c;
        end
    end
    n = numel(allFiles);
    fprintf('Val images: %d\n\n', n);

    %% Run inference (cached on disk: data/analysis/day9/ensemble_scores_cache.mat)
    scoresFile = fullfile(projectRoot, 'data', 'analysis', 'day9', 'ensemble_scores_cache.mat');
    if exist(scoresFile, 'file')
        C = load(scoresFile, 'scores7', 'scores8');
        if size(C.scores7, 1) == n
            scores7 = C.scores7; scores8 = C.scores8;
            fprintf('Loaded cached scores (%d rows)\n\n', n);
        else
            scores7 = zeros(n, nClasses);
            scores8 = zeros(n, nClasses);
            for i = 1:n
                img = imresize(imread(allFiles{i}), [224 224]);
                s7 = predict(net7, img); scores7(i,:) = s7(:)';
                s8 = predict(net8, img); scores8(i,:) = s8(:)';
                if mod(i, 100) == 0, fprintf('  %d/%d\n', i, n); end
            end
            save(scoresFile, 'scores7', 'scores8', '-v7');
            fprintf('Saved cached scores (%d rows)\n\n', n);
        end
    else
        scores7 = zeros(n, nClasses);
        scores8 = zeros(n, nClasses);
        for i = 1:n
            img = imresize(imread(allFiles{i}), [224 224]);
            s7 = predict(net7, img); scores7(i,:) = s7(:)';
            s8 = predict(net8, img); scores8(i,:) = s8(:)';
            if mod(i, 100) == 0, fprintf('  %d/%d\n', i, n); end
        end
        save(scoresFile, 'scores7', 'scores8', '-v7');
        fprintf('Saved cached scores (%d rows)\n\n', n);
    end

    %% Define weight splits to evaluate
    weightSplits = [1.0 0.0; 0.8 0.2; 0.7 0.3; 0.5 0.5; 0.3 0.7; 0.0 1.0];
    splitNames = {'day7-only', 'w=[0.8,0.2]', 'w=[0.7,0.3]', ...
                  'w=[0.5,0.5]', 'w=[0.3,0.7]', 'day8-only'};

    %% Baseline metrics for day7 alone
    fprintf('=== Results by Weight Split ===\n\n');
    fprintf('%-15s %8s %8s %8s %8s %8s %8s\n', ...
        'Split', 'Acc', 'F1', 'QWK', 'SevRec', 'ProlRec', 'MAE');
    fprintf('%-15s %8s %8s %8s %8s %8s %8s\n', ...
        '-----', '---', '--', '---', '------', '-------', '---');

    bestQWK = -1; bestIdx = 1;

    for w = 1:size(weightSplits, 1)
        w7 = weightSplits(w, 1);
        w8 = weightSplits(w, 2);
        scores = w7 * scores7 + w8 * scores8;

        % Compute metrics
        [~, YPred] = max(scores, [], 2);
        YTrue = allLabels;

        % Accuracy
        acc = sum(YPred == YTrue) / n;

        % Per-class metrics
        precision = zeros(nClasses, 1);
        recall = zeros(nClasses, 1);
        f1 = zeros(nClasses, 1);
        support = zeros(nClasses, 1);
        for c = 1:nClasses
            tp = sum(YTrue == c & YPred == c);
            fp = sum(YTrue ~= c & YPred == c);
            fn = sum(YTrue == c & YPred ~= c);
            precision(c) = tp / (tp + fp + eps);
            recall(c) = tp / (tp + fn + eps);
            f1(c) = 2 * precision(c) * recall(c) / (precision(c) + recall(c) + eps);
            support(c) = sum(YTrue == c);
        end
        macroF1 = mean(f1);

        % QWK
        qwk = computeQWK(YTrue, YPred, nClasses);

        % MAE
        mae = mean(abs(double(YTrue) - double(YPred)));

        % Severe + Proliferative recall
        sevRec = recall(4);   % class 4 = Severe
        prolRec = recall(5);  % class 5 = Proliferative

        fprintf('%-15s %7.2f%% %8.4f %8.4f %7.2f%% %7.2f%% %8.4f\n', ...
            splitNames{w}, acc*100, macroF1, qwk, sevRec*100, prolRec*100, mae);

        if qwk > bestQWK
            bestQWK = qwk; bestIdx = w;
        end
    end

    fprintf('\nBest QWK: %s (QWK=%.4f)\n', splitNames{bestIdx}, bestQWK);

    %% Check if ensemble helped Severe/Proliferative
    fprintf('\n=== Weak Class Analysis ===\n');
    scores_ens = 0.7 * scores7 + 0.3 * scores8;
    [~, pred_ens] = max(scores_ens, [], 2);
    [~, pred_7] = max(scores7, [], 2);

    for c = [4 5]  % Severe, Proliferative
        rec7 = sum(allLabels == c & pred_7 == c) / sum(allLabels == c);
        recE = sum(allLabels == c & pred_ens == c) / sum(allLabels == c);
        fprintf('  %s: day7=%.2f%%  ensemble(0.7/0.3)=%.2f%%  delta=%+.2f%%\n', ...
            classNames{c}, rec7*100, recE*100, (recE-rec7)*100);
    end

    fprintf('\n=== Test-Time Augmentation ===\n');
    fprintf('Running TTA on day7 champion (original + h-flip + rot+-5)...\n');

    scores_tta = zeros(n, nClasses);
    for i = 1:n
        img = imresize(imread(allFiles{i}), [224 224]);

        % Original
        s0 = predict(net7, img);

        % Horizontal flip
        imgFlip = flip(img, 2);
        s1 = predict(net7, imgFlip);

        % Rotation +5
        imgRotP = imrotate(img, 5, 'bilinear', 'crop');
        s2 = predict(net7, imgRotP);

        % Rotation -5
        imgRotM = imrotate(img, -5, 'bilinear', 'crop');
        s3 = predict(net7, imgRotM);

        scores_tta(i,:) = mean([s0(:)'; s1(:)'; s2(:)'; s3(:)'], 1);
    end

    [~, pred_tta] = max(scores_tta, [], 2);
    acc_tta = sum(pred_tta == allLabels) / n;
    [~, pred_7] = max(scores7, [], 2);
    acc_7 = sum(pred_7 == allLabels) / n;

    % Per-class recall
    for c = 1:nClasses
        rec7 = sum(allLabels == c & pred_7 == c) / sum(allLabels == c);
        recT = sum(allLabels == c & pred_tta == c) / sum(allLabels == c);
        fprintf('  %s: day7=%.2f%%  TTA=%.2f%%  delta=%+.2f%%\n', ...
            classNames{c}, rec7*100, recT*100, (recT-rec7)*100);
    end

    qwk_tta = computeQWK(allLabels, pred_tta, nClasses);
    fprintf('\n  Overall: day7 acc=%.2f%%  TTA acc=%.2f%%  delta=%+.2f%%\n', ...
        acc_7*100, acc_tta*100, (acc_tta-acc_7)*100);
    fprintf('  QWK:     day7=%.4f  TTA=%.4f  delta=%+.4f\n', ...
        computeQWK(allLabels, pred_7, nClasses), qwk_tta, ...
        qwk_tta - computeQWK(allLabels, pred_7, nClasses));

    %% Conclusion
    fprintf('\n============================================\n');
    fprintf('  CONCLUSION\n');
    fprintf('============================================\n');
    fprintf('Ensemble and TTA are inference-only moves on existing models.\n');
    fprintf('Neither is expected to significantly move Severe/Proliferative\n');
    fprintf('recall (n=39/59 val images) â€” the bottleneck is sample size\n');
    fprintf('and feature discriminability at 224px, not prediction averaging.\n');
    fprintf('============================================\n');
end

function qwk = computeQWK(yTrue, yPred, numClasses)
    n = numel(yTrue);
    W = zeros(numClasses);
    for i = 1:numClasses
        for j = 1:numClasses
            W(i,j) = (i - j)^2 / (numClasses - 1)^2;
        end
    end
    O = zeros(numClasses);
    for i = 1:n
        O(yTrue(i), yPred(i)) = O(yTrue(i), yPred(i)) + 1;
    end
    E = zeros(numClasses);
    rS = sum(O, 2); cS = sum(O, 1);
    for i = 1:numClasses
        for j = 1:numClasses
            E(i,j) = rS(i) * cS(j) / n;
        end
    end
    qwk = 1 - sum(W(:) .* O(:)) / (sum(W(:) .* E(:)) + eps);
end
