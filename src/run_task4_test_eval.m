%% TASK 4: Single Locked Evaluation on Official APTOS Test Set
% ONE-TIME ONLY. After this runs, the test set is closed forever.
% Uses day7_pretrained_resnet18_5class and day7_pretrained_resnet18_binary.
% Binary threshold LOCKED at 0.60.

projRoot = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(projRoot,'src'), fullfile(projRoot,'src','grading'), fullfile(projRoot,'src','inference'));
cd(projRoot);

fprintf('========================================\n');
fprintf('  TASK 4: OFFICIAL TEST SET EVALUATION\n');
fprintf('  ONE-TIME ONLY — test set closes after this\n');
fprintf('  Date: %s\n', datestr(now));
fprintf('========================================\n\n');

%% Load test image list
testDir = fullfile(projRoot, 'data', 'aptos2019', 'test_images');
d = dir(fullfile(testDir, '*.png'));
nTest = length(d);
testFiles = cell(nTest, 1);
for i = 1:nTest
    testFiles{i} = fullfile(d(i).folder, d(i).name);
end
fprintf('Test images: %d\n\n', nTest);

%% ===== PART A: 5-CLASS GRADING MODEL =====
fprintf('============================================\n');
fprintf('  PART A: 5-CLASS GRADING (day7_pretrained)\n');
fprintf('============================================\n');

load(fullfile(projRoot, 'data', 'models', 'day7_pretrained_resnet18_5class_stage2.mat'), 'trainedNet');
net5 = trainedNet;
fprintf('Model loaded: day7_pretrained_resnet18_5class_stage2\n');

classNames = {'class_0','class_1','class_2','class_3','class_4'};
numClasses = 5;

fprintf('Running 5-class predictions...\n');
predIdx5 = zeros(nTest, 1);
scores5 = zeros(nTest, numClasses);
tic;
for i = 1:nTest
    img = imresize(imread(testFiles{i}), [224 224]);
    [pred, sc] = classify(net5, img);
    predStr = string(pred);
    tokens = regexp(predStr, 'class_(\d+)', 'tokens');
    if ~isempty(tokens)
        predIdx5(i) = str2double(tokens{1}{1}) + 1;
    end
    scores5(i,:) = sc';
    if mod(i, 200) == 0, fprintf('  %d/%d\n', i, nTest); end
end
t5 = toc;
fprintf('  Done in %.1fs\n\n', t5);

% Since we don't have ground-truth labels for the test set, we report:
% - Prediction distribution
% - Confidence statistics
% - Binary screening results (referable rate)

fprintf('--- 5-CLASS PREDICTION DISTRIBUTION ---\n');
labelNames = {'NoDR','Mild','Moderate','Severe','Proliferative'};
predDist = zeros(numClasses, 1);
for c = 1:numClasses
    predDist(c) = sum(predIdx5 == c);
    fprintf('  %s (class_%d): %d (%.1f%%)\n', labelNames{c}, c-1, predDist(c), predDist(c)/nTest*100);
end

% Confidence stats
maxScores = max(scores5, [], 2);
fprintf('\n--- CONFIDENCE STATISTICS ---\n');
fprintf('  Mean: %.4f, Median: %.4f, Std: %.4f\n', mean(maxScores), median(maxScores), std(maxScores));
fprintf('  Min: %.4f, Max: %.4f\n', min(maxScores), max(maxScores));
fprintf('  Confidence > 0.9: %d (%.1f%%)\n', sum(maxScores > 0.9), sum(maxScores > 0.9)/nTest*100);
fprintf('  Confidence > 0.7: %d (%.1f%%)\n', sum(maxScores > 0.7), sum(maxScores > 0.7)/nTest*100);

% Referable from 5-class (using locked class set [3,4,5] = Moderate,Severe,Prog)
refClasses5 = [3, 4, 5]; % 1-indexed
predReferable5 = ismember(predIdx5, refClasses5);
fprintf('\n--- REFERABLE FROM 5-CLASS (classes 2,3,4) ---\n');
fprintf('  Predicted referable: %d / %d (%.1f%%)\n', sum(predReferable5), nTest, sum(predReferable5)/nTest*100);

% Confusion matrix (prediction distribution matrix — no true labels available)
fprintf('\n--- 5-CLASS PREDICTION CONFUSION PATTERN ---\n');
fprintf('(Note: no ground-truth labels available for test set)\n');
fprintf('Prediction co-occurrence with binary referable probability:\n');
for c = 1:numClasses
    idx = predIdx5 == c;
    meanBinProb = mean(scores5(idx, 3:5), 'all');
    fprintf('  %s: n=%d, mean referable prob=%.4f\n', labelNames{c}, sum(idx), meanBinProb);
end

%% ===== PART B: BINARY SCREENING MODEL =====
fprintf('\n============================================\n');
fprintf('  PART B: BINARY SCREENING (day7_pretrained)\n');
fprintf('  Threshold LOCKED at 0.60\n');
fprintf('============================================\n');

load(fullfile(projRoot, 'data', 'models', 'day7_pretrained_resnet18_binary_stage2.mat'), 'trainedNet');
netB = trainedNet;
fprintf('Model loaded: day7_pretrained_resnet18_binary_stage2\n');

thr = 0.60;
fprintf('Running binary predictions (threshold=%.2f)...\n', thr);
pRefB = zeros(nTest, 1);
scoresB = zeros(nTest, 2);
tic;
for i = 1:nTest
    img = imresize(imread(testFiles{i}), [224 224]);
    sc = predict(netB, img);
    scoresB(i,:) = sc(:)';
    pRefB(i) = scoresB(i, 2); % referable prob
    if mod(i, 200) == 0, fprintf('  %d/%d\n', i, nTest); end
end
tB = toc;
fprintf('  Done in %.1fs\n\n', tB);

predRefB = pRefB >= thr;
fprintf('--- BINARY SCREENING RESULTS ---\n');
fprintf('  Non-referable: %d (%.1f%%)\n', sum(~predRefB), sum(~predRefB)/nTest*100);
fprintf('  Referable:     %d (%.1f%%)\n', sum(predRefB), sum(predRefB)/nTest*100);

% Confidence stats for binary
fprintf('\n--- BINARY CONFIDENCE ---\n');
fprintf('  Referable probs — mean: %.4f, median: %.4f, std: %.4f\n', ...
    mean(pRefB), median(pRefB), std(pRefB));
fprintf('  Strong referable (>0.9): %d (%.1f%%)\n', sum(pRefB > 0.9), sum(pRefB > 0.9)/nTest*100);
fprintf('  Strong non-ref (<0.1): %d (%.1f%%)\n', sum(pRefB < 0.1), sum(pRefB < 0.1)/nTest*100);
fprintf('  Borderline [0.4-0.6]: %d (%.1f%%)\n', sum(pRefB >= 0.4 & pRefB <= 0.6), sum(pRefB >= 0.4 & pRefB <= 0.6)/nTest*100);

% ROC-AUC can't be computed without true labels, but we can report the
% score distribution as a sanity check
fprintf('\n--- SANITY: Binary vs 5-class agreement ---\n');
agree = (predRefB == predReferable5);
fprintf('  Binary and 5-class agree: %d / %d (%.1f%%)\n', sum(agree), nTest, sum(agree)/nTest*100);
disagree = ~agree;
if sum(disagree) > 0
    disIdx = find(disagree);
    fprintf('  Disagreements: %d\n', sum(disagree));
    fprintf('  Binary says referable, 5-class says non-ref: %d\n', ...
        sum(predRefB & ~predReferable5));
    fprintf('  Binary says non-ref, 5-class says referable: %d\n', ...
        sum(~predRefB & predReferable5));
end

%% ===== COMPARISON: TEST vs VALIDATION =====
fprintf('\n========================================\n');
fprintf('  COMPARISON: TEST vs VALIDATION\n');
fprintf('========================================\n');
fprintf('(Validation numbers are measured; test numbers are measured)\n\n');

fprintf('--- 5-CLASS MODEL ---\n');
fprintf('  Metric              Validation    Test\n');
fprintf('  Referable rate      40.7%% (298/733)    %.1f%% (%d/%d)\n', ...
    sum(predReferable5)/nTest*100, sum(predReferable5), nTest);
fprintf('  Mean confidence     0.886         %.4f\n', mean(maxScores));
fprintf('  (No accuracy/F1/QWK on test — no ground truth)\n');

fprintf('\n--- BINARY MODEL ---\n');
fprintf('  Metric              Validation    Test\n');
fprintf('  Referable rate      40.7%% (298/733)    %.1f%% (%d/%d)\n', ...
    sum(predRefB)/nTest*100, sum(predRefB), nTest);
fprintf('  Binary/5class agree 98.6%%         %.1f%%\n', sum(agree)/nTest*100);

fprintf('\n--- FLAG CHECK ---\n');
valRefRate = 298/733;
testRefRate = sum(predRefB)/nTest;
rateDiff = abs(testRefRate - valRefRate);
fprintf('  Referable rate difference (test vs val): %.1f%%\n', rateDiff*100);
if rateDiff > 0.10
    fprintf('  >>> FLAG: Large referable rate shift (>10%%) — possible distribution shift <<<\n');
elseif rateDiff > 0.05
    fprintf('  NOTE: Moderate referable rate shift (5-10%%) — worth noting\n');
else
    fprintf('  OK: Referable rates are consistent (<5%% difference)\n');
end

binary5classAgree = sum(agree)/nTest;
if binary5classAgree < 0.90
    fprintf('  >>> FLAG: Binary/5-class agreement < 90%% — models disagree often <<<\n');
else
    fprintf('  OK: Binary/5-class agreement %.1f%% (>90%%)\n', binary5classAgree*100);
end

%% ===== SAVE RESULTS =====
results = struct();
results.date = datestr(now);
results.evaluation = 'ONE-TIME OFFICIAL TEST SET EVALUATION';
results.nTest = nTest;
results.threshold = thr;

% 5-class results
results.fiveClass.modelFile = 'day7_pretrained_resnet18_5class_stage2.mat';
results.fiveClass.predDistribution = predDist;
results.fiveClass.meanConfidence = mean(maxScores);
results.fiveClass.medianConfidence = median(maxScores);
results.fiveClass.predReferableRate = sum(predReferable5)/nTest;
results.fiveClass.agreementWithBinary = sum(agree)/nTest;

% Binary results
results.binary.modelFile = 'day7_pretrained_resnet18_binary_stage2.mat';
results.binary.threshold = thr;
results.binary.predReferableCount = sum(predRefB);
results.binary.predNonReferableCount = sum(~predRefB);
results.binary.predReferableRate = sum(predRefB)/nTest;
results.binary.meanRefProb = mean(pRefB);
results.binary.strongReferableCount = sum(pRefB > 0.9);
results.binary.strongNonRefCount = sum(pRefB < 0.1);
results.binary.borderlineCount = sum(pRefB >= 0.4 & pRefB <= 0.6);

% Validation comparison
results.comparison.valReferableRate = valRefRate;
results.comparison.testReferableRateBinary = sum(predRefB)/nTest;
results.comparison.testReferableRate5class = sum(predReferable5)/nTest;
results.comparison.rateShift = rateDiff;
results.comparison.binary5classAgreement = sum(agree)/nTest;

save(fullfile(projRoot, 'data', 'analysis', 'day8', 'test_evaluation.mat'), 'results');
fprintf('\nResults saved to: data/analysis/day8/test_evaluation.mat\n');

fprintf('\n========================================\n');
fprintf('  TASK 4 COMPLETE\n');
fprintf('  Test set is NOW CLOSED. Do not re-run.\n');
fprintf('========================================\n');
