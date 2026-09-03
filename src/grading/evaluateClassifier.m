function results = evaluateClassifier(modelPath, dataRoot)
% EVALUATECLASSIFIER Evaluate trained classifier with detailed metrics
%   results = evaluateClassifier(modelPath, dataRoot)
%
%   Inputs:
%       modelPath - Path to saved model (.mat file)
%       dataRoot  - Path to aptos2019 folder
%
%   Outputs:
%       results - Struct with all evaluation metrics

    %% Setup
    if nargin < 1
        script_dir = fileparts(mfilename('fullpath'));
        project_root = fileparts(fileparts(script_dir));
        modelPath = fullfile(project_root, 'models', 'dr_classifier_resnet18.mat');
    end
    if nargin < 2
        script_dir = fileparts(mfilename('fullpath'));
        project_root = fileparts(fileparts(script_dir));
        dataRoot = fullfile(project_root, 'data', 'aptos2019');
    end

    fprintf('=== DrishtiCare Model Evaluation ===\n\n');

    %% Load model
    fprintf('--- Loading Model ---\n');
    if ~exist(modelPath, 'file')
        error('Model not found: %s', modelPath);
    end
    loaded = load(modelPath);
    net = loaded.net;
    fprintf('[OK] Model loaded from: %s\n\n', modelPath);

    %% Load test data
    fprintf('--- Loading Test Data ---\n');
    trainCsv = fullfile(dataRoot, 'train.csv');
    trainDir = fullfile(dataRoot, 'train_images');

    data = readtable(trainCsv);
    imgPaths = fullfile(trainDir, strcat(data.id_code, '.png'));
    labels = categorical(data.diagnosis);

    imds = imageDatastore(imgPaths, 'Labels', labels);

    % Use last 20% as test set (same split as training)
    [~, testDS] = splitEachLabel(imds, 0.8, 'randomized');

    fprintf('Test images: %d\n\n', numel(testDS.Files));

    %% Create augmented datastore
    inputSize = net.Layers(1).InputSize;
    augmentedTestDS = augmentedImageDatastore(inputSize, testDS);

    %% Classify
    fprintf('--- Running Classification ---\n');
    tic;
    [predLabels, scores] = classify(net, augmentedTestDS);
    inferenceTime = toc;
    trueLabels = testDS.Labels;

    fprintf('Inference time: %.2f seconds (%.1f ms/image)\n', ...
        inferenceTime, inferenceTime/numel(testDS.Files)*1000);

    %% Calculate metrics
    fprintf('\n--- Calculating Metrics ---\n');

    % Overall accuracy
    accuracy = sum(predLabels == trueLabels) / numel(trueLabels);
    fprintf('Overall Accuracy: %.2f%%\n', accuracy * 100);

    % Confusion matrix
    [confMat, order] = confusionmat(trueLabels, predLabels);

    % Per-class metrics
    numClasses = 5;
    classNames = {'No DR', 'Mild', 'Moderate', 'Severe', 'Proliferative'};

    precision = zeros(numClasses, 1);
    recall = zeros(numClasses, 1);
    f1Score = zeros(numClasses, 1);
    support = zeros(numClasses, 1);

    for i = 1:numClasses
        tp = confMat(i, i);
        fp = sum(confMat(:, i)) - tp;
        fn = sum(confMat(i, :)) - tp;
        support(i) = sum(confMat(i, :));

        if (tp + fp) > 0
            precision(i) = tp / (tp + fp);
        end
        if (tp + fn) > 0
            recall(i) = tp / (tp + fn);
        end
        if (precision(i) + recall(i)) > 0
            f1Score(i) = 2 * precision(i) * recall(i) / (precision(i) + recall(i));
        end
    end

    % Macro averages
    macroPrecision = mean(precision);
    macroRecall = mean(recall);
    macroF1 = mean(f1Score);

    % Weighted averages
    weightedPrecision = sum(precision .* support) / sum(support);
    weightedRecall = sum(recall .* support) / sum(support);
    weightedF1 = sum(f1Score .* support) / sum(support);

    %% Display results
    fprintf('\n=== DETAILED RESULTS ===\n');

    fprintf('\nPer-Class Metrics:\n');
    fprintf('%-15s  Precision  Recall  F1-Score  Support\n', 'Class');
    fprintf('%-15s  ---------  ------  --------  -------\n', '-----');
    for i = 1:numClasses
        fprintf('%-15s  %.4f    %.4f  %.4f     %d\n', ...
            classNames{i}, precision(i), recall(i), f1Score(i), support(i));
    end

    fprintf('\nMacro Averages:\n');
    fprintf('  Precision: %.4f\n', macroPrecision);
    fprintf('  Recall:    %.4f\n', macroRecall);
    fprintf('  F1-Score:  %.4f\n', macroF1);

    fprintf('\nWeighted Averages:\n');
    fprintf('  Precision: %.4f\n', weightedPrecision);
    fprintf('  Recall:    %.4f\n', weightedRecall);
    fprintf('  F1-Score:  %.4f\n', weightedF1);

    %% Sensitivity/Specificity for DR detection (binary: DR vs No DR)
    fprintf('\n--- Binary DR Detection ---\n');
    noDRIdx = (trueLabels == categorical(0));
    drIdx = ~noDRIdx;

    % Predicted labels
    predNoDR = (predLabels == categorical(0));
    predDR = ~predNoDR;

    tp = sum(drIdx & predDR);
    tn = sum(noDRIdx & predNoDR);
    fp = sum(noDRIdx & predDR);
    fn = sum(drIdx & predNoDR);

    sensitivity = tp / (tp + fn);
    specificity = tn / (tn + fp);
   ppv = tp / (tp + fp);
    npv = tn / (tn + fn);

    fprintf('Sensitivity (DR detection): %.2f%%\n', sensitivity * 100);
    fprintf('Specificity (No DR):        %.2f%%\n', specificity * 100);
    fprintf('PPV (Precision):            %.2f%%\n', ppv * 100);
    fprintf('NPV (Negative Predictive):  %.2f%%\n', npv * 100);

    %% Visualizations
    fprintf('\n--- Creating Visualizations ---\n');

    % Figure 1: Confusion Matrix
    figure('Name', 'Evaluation Results', 'NumberTitle', 'off', ...
           'Position', [50, 50, 1400, 600]);

    subplot(1,3,1);
    confusionchart(trueLabels, predLabels, ...
        'RowSummary', 'row-normalized', ...
        'ColumnSummary', 'column-normalized');
    title('Normalized Confusion Matrix');

    % Figure 2: Per-class bar chart
    subplot(1,3,2);
    bar_data = [precision, recall, f1Score];
    bar(bar_data);
    set(gca, 'XTickLabel', classNames);
    xtickangle(45);
    ylabel('Score');
    title('Per-Class Metrics');
    legend('Precision', 'Recall', 'F1-Score', 'Location', 'best');
    ylim([0 1]);
    grid on;

    % Figure 3: ROC-like visualization (confidence distribution)
    subplot(1,3,3);
    maxScores = max(scores, [], 2);
    histogram(maxScores, 30, 'FaceColor', [0.2 0.6 0.8]);
    xlabel('Max Confidence Score');
    ylabel('Count');
    title('Prediction Confidence Distribution');
    grid on;

    sgtitle(sprintf('Model Evaluation - Accuracy: %.2f%%', accuracy*100), ...
        'FontSize', 14, 'FontWeight', 'bold');

    %% Sample predictions
    fprintf('\n--- Sample Predictions ---\n');
    numShow = min(10, numel(testDS.Files));
    figure('Name', 'Sample Predictions', 'NumberTitle', 'off', ...
           'Position', [50, 50, 1400, 400]);

    for i = 1:numShow
        img = readimage(testDS, i);
        subplot(2, 5, i);
        imshow(img);

        trueClass = char(trueLabels(i));
        predClass = char(predLabels(i));
        conf = max(scores(i, :)) * 100;

        if predLabels(i) == trueLabels(i)
            color = 'g';
        else
            color = 'r';
        end

        title(sprintf('True: %s\nPred: %s (%.0f%%)', ...
            trueClass, predClass, conf), ...
            'Color', color, 'FontSize', 9);
    end
    sgtitle('Sample Predictions (Green=Correct, Red=Wrong)', ...
        'FontSize', 12, 'FontWeight', 'bold');

    %% Save results
    results.accuracy = accuracy;
    results.precision = precision;
    results.recall = recall;
    results.f1Score = f1Score;
    results.macroPrecision = macroPrecision;
    results.macroRecall = macroRecall;
    results.macroF1 = macroF1;
    results.weightedPrecision = weightedPrecision;
    results.weightedRecall = weightedRecall;
    results.weightedF1 = weightedF1;
    results.sensitivity = sensitivity;
    results.specificity = specificity;
    results.confMat = confMat;
    results.predLabels = predLabels;
    results.trueLabels = trueLabels;
    results.scores = scores;

    % Save results
    script_dir = fileparts(mfilename('fullpath'));
    project_root = fileparts(fileparts(script_dir));
    resultsPath = fullfile(project_root, 'models', 'evaluation_results.mat');
    save(resultsPath, 'results');
    fprintf('\n[OK] Results saved to: %s\n', resultsPath);

    %% Summary
    fprintf('\n=== EVALUATION SUMMARY ===\n');
    fprintf('Overall Accuracy: %.2f%%\n', accuracy * 100);
    fprintf('Sensitivity:      %.2f%%\n', sensitivity * 100);
    fprintf('Specificity:      %.2f%%\n', specificity * 100);
    fprintf('Macro F1:         %.4f\n', macroF1);
    fprintf('Weighted F1:      %.4f\n', weightedF1);

    fprintf('\n--- Training Recommendations ---\n');
    if accuracy < 0.7
        fprintf('[!] Accuracy is low. Consider:\n');
        fprintf('    - More epochs (current: check options.MaxEpochs)\n');
        fprintf('    - Larger network (try resnet50 or efficientnetb0)\n');
        fprintf('    - More aggressive augmentation\n');
        fprintf('    - Learning rate scheduling\n');
    elseif accuracy < 0.85
        fprintf('[*] Accuracy is decent. Consider:\n');
        fprintf('    - Fine-tuning hyperparameters\n');
        fprintf('    - Adding more epochs\n');
        fprintf('    - Ensemble methods\n');
    else
        fprintf('[+] Accuracy is good! Consider:\n');
        fprintf('    - Testing on external dataset (IDRiD)\n');
        fprintf('    - Optimizing for inference speed\n');
        fprintf('    - Preparing for deployment\n');
    end

    fprintf('\n=== End Evaluation ===\n');
end
