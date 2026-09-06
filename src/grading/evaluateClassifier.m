function metrics = evaluateClassifier(trainedNet, valDSraw, varargin)
% EVALUATECLASSIFIER Evaluate trained DR classifier on validation set
%   metrics = evaluateClassifier(trainedNet, valDSraw)
%   metrics = evaluateClassifier(trainedNet, valDSraw, 'Config', config)
%
%   Inputs:
%       trainedNet - Trained network (DAGNetwork or SeriesNetwork)
%       valDSraw   - Raw imageDatastore (NOT augmented) for evaluation
%
%   Optional Parameters:
%       'Config' - Training config struct (default: defaultTrainingConfig())
%
%   IMPORTANT: These are ENGINEERING metrics, NOT clinical performance claims.

    %% Parse arguments
    p = inputParser;
    addParameter(p, 'Config', [], @(x) isstruct(x));
    parse(p, varargin{:});
    config = p.Results.Config;

    if isempty(config)
        config = defaultTrainingConfig();
    end

    classNames = config.classes.names;  % {'NoDR', 'Mild', 'Moderate', 'Severe', 'Proliferative'}
    numClasses = config.classes.numClasses;

    %% Get file list and labels from folder structure
    fprintf('Loading validation files...\n');
    fileCount = length(valDSraw.Files);
    fprintf('  Total validation files: %d\n', fileCount);

    %% Get class order from the trained network
    % The network's categorical output uses folder names: class_0, class_1, etc.
    % We need to map these to our config class indices
    netClasses = categories(valDSraw.Labels);
    fprintf('  Network classes: %s\n', strjoin(netClasses, ', '));

    %% Run predictions
    fprintf('Running predictions...\n');
    tic;

    YPred = zeros(fileCount, 1);
    YTrue = zeros(fileCount, 1);

    for i = 1:fileCount
        % Read and resize image (same as training preprocessing)
        img = imread(valDSraw.Files{i});
        imgResized = imresize(img, config.input.imageSize(1:2));

        % Get true label from folder name
        folderPath = fileparts(valDSraw.Files{i});
        [~, folderName] = fileparts(folderPath);
        tokens = regexp(folderName, 'class_(\d+)', 'tokens');
        if ~isempty(tokens)
            YTrue(i) = str2double(tokens{1}{1}) + 1; % 1-indexed
        else
            YTrue(i) = 1;
        end

        % Predict
        pred = classify(trainedNet, imgResized);
        if iscell(pred)
            pred = pred{1};
        end

        % Get predicted class index from categorical
        % The model outputs categorical with names like 'class_0', 'class_1', etc.
        predStr = string(pred);
        % Extract class number from 'class_X' pattern
        predTokens = regexp(predStr, 'class_(\d+)', 'tokens');
        if ~isempty(predTokens)
            YPred(i) = str2double(predTokens{1}{1}) + 1; % 1-indexed
        else
            % Fallback: try to match against config class names
            idx = find(strcmp(predStr, classNames));
            if ~isempty(idx)
                YPred(i) = idx;
            else
                YPred(i) = 1; % Default to first class
            end
        end

        if mod(i, 100) == 0
            fprintf('  Processed %d/%d\n', i, fileCount);
        end
    end

    predTime = toc;
    fprintf('  Predictions completed in %.1f seconds\n', predTime);

    %% Confusion matrix
    fprintf('Computing confusion matrix...\n');
    confMat = zeros(numClasses);
    for i = 1:fileCount
        confMat(YTrue(i), YPred(i)) = confMat(YTrue(i), YPred(i)) + 1;
    end

    %% Per-class metrics
    fprintf('Computing per-class metrics...\n');
    precision = zeros(numClasses, 1);
    recall = zeros(numClasses, 1);
    f1 = zeros(numClasses, 1);
    support = zeros(numClasses, 1);

    for c = 1:numClasses
        tp = confMat(c, c);
        fp = sum(confMat(:, c)) - tp;
        fn = sum(confMat(c, :)) - tp;

        precision(c) = tp / (tp + fp + eps);
        recall(c) = tp / (tp + fn + eps);
        f1(c) = 2 * precision(c) * recall(c) / (precision(c) + recall(c) + eps);
        support(c) = sum(YTrue == c);
    end

    %% Macro F1
    macroF1 = mean(f1);

    %% Overall accuracy
    accuracy = sum(YPred == YTrue) / fileCount;

    %% Quadratic Weighted Kappa (QWK)
    fprintf('Computing QWK...\n');
    qwk = computeQWK(YTrue, YPred, numClasses);

    %% Referable DR metrics
    fprintf('Computing referable DR metrics...\n');
    referableClasses = config.classes.referable; % 1-indexed: [3,4,5]

    % Binary: referable vs non-referable
    YTrueReferable = ismember(YTrue, referableClasses);
    YPredReferable = ismember(YPred, referableClasses);

    tpRef = sum(YTrueReferable & YPredReferable);
    fpRef = sum(~YTrueReferable & YPredReferable);
    fnRef = sum(YTrueReferable & ~YPredReferable);
    tnRef = sum(~YTrueReferable & ~YPredReferable);

    sensitivity = tpRef / (tpRef + fnRef + eps);
    specificity = tnRef / (tnRef + fpRef + eps);
    ppv = tpRef / (tpRef + fpRef + eps);
    npv = tnRef / (tnRef + fnRef + eps);

    %% Predicted class distribution
    predDist = zeros(numClasses, 1);
    for c = 1:numClasses
        predDist(c) = sum(YPred == c);
    end

    %% Compile metrics
    metrics = struct();
    metrics.date = datestr(now);
    metrics.numClasses = numClasses;
    metrics.classNames = classNames;
    metrics.confusionMatrix = confMat;
    metrics.precision = precision;
    metrics.recall = recall;
    metrics.f1 = f1;
    metrics.support = support;
    metrics.macroF1 = macroF1;
    metrics.accuracy = accuracy;
    metrics.qwk = qwk;
    metrics.referable.sensitivity = sensitivity;
    metrics.referable.specificity = specificity;
    metrics.referable.ppv = ppv;
    metrics.referable.npv = npv;
    metrics.referable.tp = tpRef;
    metrics.referable.fp = fpRef;
    metrics.referable.fn = fnRef;
    metrics.referable.tn = tnRef;
    metrics.predictionTime = predTime;
    metrics.totalSamples = fileCount;
    metrics.YTrue = YTrue;
    metrics.YPred = YPred;
    metrics.predictedDistribution = predDist;

    %% Print results
    fprintf('\n=== Evaluation Results ===\n');
    fprintf('Overall Accuracy: %.2f%%\n', accuracy * 100);
    fprintf('Macro F1: %.4f\n', macroF1);
    fprintf('QWK: %.4f\n', qwk);

    fprintf('\nPredicted class distribution:\n');
    for c = 1:numClasses
        fprintf('  %s: %d (%.1f%%)\n', classNames{c}, predDist(c), predDist(c)/fileCount*100);
    end

    fprintf('\nTrue class distribution:\n');
    for c = 1:numClasses
        fprintf('  %s: %d (%.1f%%)\n', classNames{c}, support(c), support(c)/fileCount*100);
    end

    fprintf('\nPer-class metrics:\n');
    fprintf('%-15s %8s %8s %8s %8s\n', 'Class', 'Prec', 'Recall', 'F1', 'Support');
    fprintf('%-15s %8s %8s %8s %8s\n', '-----', '----', '------', '--', '-------');
    for c = 1:numClasses
        fprintf('%-15s %8.4f %8.4f %8.4f %8d\n', ...
            classNames{c}, precision(c), recall(c), f1(c), support(c));
    end

    fprintf('\nReferable DR:\n');
    fprintf('  Sensitivity: %.4f\n', sensitivity);
    fprintf('  Specificity: %.4f\n', specificity);
    fprintf('  PPV: %.4f\n', ppv);
    fprintf('  NPV: %.4f\n', npv);
    fprintf('  TP: %d, FP: %d, FN: %d, TN: %d\n', tpRef, fpRef, fnRef, tnRef);
    fprintf('========================\n\n');
end

function qwk = computeQWK(yTrue, yPred, numClasses)
    n = length(yTrue);

    % Build weight matrix
    W = zeros(numClasses);
    for i = 1:numClasses
        for j = 1:numClasses
            W(i,j) = (i - j)^2 / (numClasses - 1)^2;
        end
    end

    % Build confusion matrix
    O = zeros(numClasses);
    for i = 1:n
        O(yTrue(i), yPred(i)) = O(yTrue(i), yPred(i)) + 1;
    end

    % Expected confusion matrix (by chance)
    E = zeros(numClasses);
    rowSums = sum(O, 2);
    colSums = sum(O, 1);
    for i = 1:numClasses
        for j = 1:numClasses
            E(i,j) = rowSums(i) * colSums(j) / n;
        end
    end

    % Compute QWK
    numer = sum(W(:) .* O(:));
    denom = sum(W(:) .* E(:));
    qwk = 1 - numer / (denom + eps);
end