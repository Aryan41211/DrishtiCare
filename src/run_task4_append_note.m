%% Append ground-truth-availability note to Task 4 results (honesty check)
% The official APTOS test set has NO ground-truth labels in this local copy.
% test.csv contains only id_code (no diagnosis column).
% Therefore accuracy/F1/QWK/sens/spec/AUC/PR-AUC CANNOT be computed on test.

projRoot = fileparts(fileparts(mfilename('fullpath')));
resFile = fullfile(projRoot, 'data', 'analysis', 'day8', 'test_evaluation.mat');
d = load(resFile, 'results');
results = d.results;

results.groundTruthAvailability = struct();
results.groundTruthAvailability.testCsvColumns = 'id_code only (no diagnosis)';
results.groundTruthAvailability.sampleSubmission = 'all-zero placeholders, not ground truth';
results.groundTruthAvailability.hasLabels = false;
results.groundTruthAvailability.computableMetrics = ...
    {'predDistribution','confidenceStats','referableRate','binary5classAgreement'};
results.groundTruthAvailability.notComputable = ...
    {'accuracy','macroF1','qwk','perClassRecall','sensitivity','specificity','rocAUC','prAUC','confusionMatrix'};
results.groundTruthAvailability.note = ...
    'NO ground truth for APTOS official test set. Metric values for accuracy/F1/QWK/etc. CANNOT be reported. Only distribution/rate/agreement metrics are measured.';

save(resFile, 'results');
fprintf('Updated test_evaluation.mat with ground-truth availability note.\n');
fprintf('CONFIRMED: Test set has no labels. Accuracy/F1/QWK/AUC etc. NOT computable.\n');
