base = 'C:\projects\DrishtiCare\data\analysis';

files = { ...
    'day7','eval_fixed_day5_resnet18_baseline_stage2.mat','day5 baseline (scratch, no balance)'; ...
    'day7','eval_fixed_day6_resnet18_balanced_stage2.mat','day6 balanced (scratch, balanced)'; ...
    'day7','eval_fixed_day7_pretrained_resnet18_5class_stage2.mat','day7 pretrained (champion)'; ...
};

fprintf('%-45s | %-8s | %-8s | %-8s | %-8s | %-8s | %-8s\n', ...
    'Configuration','Acc','macroF1','QWK','Sens>=2','Spec>=2','n');
fprintf('%s\n', repmat('-',1,130));

for i = 1:size(files,1)
    fpath = fullfile(base, files{i,1}, files{i,2});
    S = load(fpath);
    m = S.m;
    CM = m.confusionMatrix;
    % binary referable: referable = classes 2..5 (index 2,3,4,5), non-ref = class 1
    tp = sum(diag(CM(2:5,2:5)));
    fp = sum(sum(CM(1,2:5)));
    fn = sum(sum(CM(2:5,1)));
    tn = CM(1,1);
    sens = tp/(tp+fn);
    spec = tn/(tn+fp);
    fprintf('%-45s | %8.4f | %8.4f | %8.4f | %8.4f | %8.4f | %d\n', ...
        files{i,3}, m.accuracy, m.macroF1, m.qwk, sens, spec, m.totalSamples);
end

fprintf('\nPer-class recall:\n');
for i = 1:size(files,1)
    S = load(fullfile(base, files{i,1}, files{i,2}));
    m = S.m;
    fprintf('%-45s recall = %s\n', files{i,3}, mat2str(m.recall', 4));
end

fprintf('\nDay8 test_evaluation fiveClass & binary fields:\n');
d8 = load(fullfile(base,'day8','test_evaluation.mat'));
rs = d8.results;
fn5 = fieldnames(rs.fiveClass);
b5 = fieldnames(rs.binary);
for k = 1:length(fn5)
    v = rs.fiveClass.(fn5{k});
    if isnumeric(v), fprintf('  fiveClass.%s = %s\n', fn5{k}, mat2str(v,5));
    else, fprintf('  fiveClass.%s = %s\n', fn5{k}, class(v)); end
end
for k = 1:length(b5)
    v = rs.binary.(b5{k});
    if isnumeric(v), fprintf('  binary.%s = %s\n', b5{k}, mat2str(v,5));
    else, fprintf('  binary.%s = %s\n', b5{k}, class(v)); end
end
fprintf('  results.nTest = %d\n', rs.nTest);
fprintf('  results.threshold = %g\n', rs.threshold);
fprintf('  agreement (binary vs 5class) = %g\n', rs.comparison.binary5classAgreement);
