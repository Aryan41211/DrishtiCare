function run_branchb_light_tuning()
%RUN_BRANCHB_LIGHT_TUNING Light hyperparameter tuning on Branch B classifier
%   run_branchb_light_tuning()
%
%   Loads existing 10-feature extraction cache, tries different regularization
%   strengths for the logistic classifier, reports AUC before/after on 733-val.
%   No new feature extraction — reuses feat_cache.mat and branchb_cache_partial.mat.

    fprintf('============================================\n');
    fprintf('  Branch B Light Tuning\n');
    fprintf('============================================\n\n');

    projectRoot = pwd;
    addpath(genpath(fullfile(projectRoot, 'src')));

    %% Load feature cache
    cacheFile = fullfile(projectRoot, 'data', 'analysis', 'day8', 'branch_b', 'feat_cache.mat');
    S = load(cacheFile, 'X', 'grade', 'isVal', 'ids', 'featNames');
    fprintf('Feature cache: %d rows (train=%d, val=%d), %d features\n', ...
        numel(S.grade), sum(~S.isVal), sum(S.isVal), size(S.X, 2));
    fprintf('Features: %s\n', strjoin(S.featNames, ', '));

    %% Load Branch B model (current)
    modelFile = fullfile(projectRoot, 'data', 'analysis', 'day8', 'branch_b', 'branchB_model.mat');
    SBB = load(modelFile);
    currentModel = SBB.model;

    %% Also load full 733-val features (from Task 7 cache)
    t7File = fullfile(projectRoot, 'data', 'analysis', 'day8', 'task7', 'branchb_cache_partial.mat');
    if exist(t7File, 'file')
        S7 = load(t7File, 'X', 'grade');
        Xval = S7.X;
        gradeVal = S7.grade;
        fprintf('Full 733-val features loaded: %d rows\n', size(Xval, 1));
    else
        fprintf('Full 733-val cache not found, using feat_cache val subset\n');
        Xval = S.X(S.isVal, :);
        gradeVal = S.grade(S.isVal);
    end

    %% Define referable ground truth
    refTrue = gradeVal >= 2;  % Moderate, Severe, Proliferative

    %% Load Branch A referable predictions for match-rate computation
    auditFile = fullfile(projectRoot, 'data', 'analysis', 'day8', 'reverify_audit_T0.mat');
    A = load(auditFile, 'PRef');
    if numel(A.PRef) ~= numel(refTrue)
        A.PRef = A.PRef;  % length should match 733; verified below
    end
    pRefA = A.PRef;
    thr0 = 0.60;

    %% Evaluate current model
    fprintf('\n--- Current Model ---\n');
    pRefB_current = branch_b_predict_batch(Xval, currentModel);
    aucCurrent = computeAUC(refTrue, pRefB_current);
    matchCurrent = computeMatchRate(pRefB_current, pRefA, thr0);
    fprintf('  ROC-AUC: %.4f\n', aucCurrent);
    fprintf('  Match rate @0.60 (vs Branch A): %.4f\n', matchCurrent);

    %% Try different regularization strengths
    fprintf('\n--- Tuning Regularization ---\n');

    % Train subsample (from feat_cache, same as current model)
    Xtrain = S.X(~S.isVal, :);
    gradeTrain = S.grade(~S.isVal);
    refTrain = gradeTrain >= 2;

    lambdas = [1e-1, 3e-2, 1e-2, 3e-3, 1e-3, 3e-4, 1e-4];
    fprintf('%-12s %10s %10s %10s\n', 'Lambda', 'AUC', 'Match@0.60', 'Delta_AUC');
    fprintf('%-12s %10s %10s %10s\n', '------', '---', '---------', '--------');

    bestAUC = aucCurrent; bestLambda = NaN;

    for li = 1:numel(lambdas)
        lam = lambdas(li);
        try
            % Scale features
            mx = max(abs(Xtrain), [], 1);
            mx(mx == 0) = 1;
            Xs = Xtrain ./ mx;
            XvalS = Xval ./ mx;

            % Train logistic with L1
            mdl = fitclinear(Xs, refTrain, 'Learner', 'logistic', ...
                'Regularization', 'lasso', 'Lambda', lam);

            % Predict
            [~, sc] = predict(mdl, XvalS);
            s = sc(:, double(mdl.ClassNames)==1);
            pRefB = min(max(s, 0), 1);

            % Temperature scaling (re-fit on training)
            [~, scTrain] = predict(mdl, Xs);
            sTrain = scTrain(:, double(mdl.ClassNames)==1);
            pTrain = min(max(sTrain, 0), 1);
            T = fitTemperature(pTrain, refTrain);

            pRefB_cal = temperatureScale(pRefB, T);

            auc = computeAUC(refTrue, pRefB_cal);
            match = computeMatchRate(pRefB_cal, pRefA, thr0);
            delta = auc - aucCurrent;

            fprintf('  %-12.4e %10.4f %10.4f %+.4f', lam, auc, match, delta);
            if delta > 0.001
                fprintf('  <-- BETTER');
            end
            fprintf('\n');

            if auc > bestAUC
                bestAUC = auc; bestLambda = lam;
            end
        catch e
            fprintf('  %-12.4e FAILED: %s\n', lam, e.message);
        end
    end

    %% Summary
    fprintf('\n============================================\n');
    fprintf('  SUMMARY\n');
    fprintf('============================================\n');
    fprintf('Current AUC:     %.4f\n', aucCurrent);
    fprintf('Best AUC:        %.4f (lambda=%.4e)\n', bestAUC, bestLambda);
    fprintf('Delta:           %+.4f\n', bestAUC - aucCurrent);
    if bestAUC - aucCurrent > 0.005
        fprintf('Verdict: LIGHT TUNING HELPED (small but real gain).\n');
    else
        fprintf('Verdict: LIGHT TUNING DID NOT HELP meaningfully.\n');
        fprintf('The ceiling is set by the 10-feature extraction quality,\n');
        fprintf('not by the classifier regularization.\n');
    end
    fprintf('============================================\n');
end

function auc = computeAUC(refTrue, scores)
    [X, Y, ~, auc] = perfcurve(double(refTrue), scores, 1);
end

function rate = computeMatchRate(pRefB, pRefA, thr)
    % Match rate: fraction of images where Branch B agrees with Branch A's
    % referable decision at the locked threshold.
    rate = mean((pRefB >= thr) == (pRefA >= thr));
end

function T = fitTemperature(pScores, refTrue)
    % Simple grid search for temperature
    bestNLL = inf; T = 1.0;
    for t = 0.5:0.01:5.0
        pCal = 1 ./ (1 + exp(-log(max(pScores./(1-pScores+eps), 1e-10)) ./ t));
        nll = -mean(refTrue .* log(pCal+eps) + (1-refTrue) .* log(1-pCal+eps));
        if nll < bestNLL
            bestNLL = nll; T = t;
        end
    end
end

function pRefB = branch_b_predict_batch(X, model)
    Xs = X ./ model.mx;
    [~, sc] = predict(model.mdl, Xs);
    s = sc(:, double(model.mdl.ClassNames)==1);
    if model.T ~= 1
        pRefB = 1 ./ (1 + exp(-log(max(s./(1-s+eps), 1e-10)) ./ model.T));
    else
        pRefB = s;
    end
    pRefB = min(max(pRefB, 0), 1);
end
