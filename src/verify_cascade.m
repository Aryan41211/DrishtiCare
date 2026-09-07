%% VERIFY cascade_router -- synthetic + real-image demonstration
%  Runs the router on representative synthetic cases to verify the band
%  logic, then optionally on a handful of real APTOS training images.

projRoot = fileparts(fileparts(mfilename('fullpath')));
addpath(genpath(fullfile(projRoot, 'src')));
cd(projRoot);

fprintf('=== Cascade Router Verification ===\n\n');

%% ----- Part 1: Synthetic test cases -----
% Construct s5 vectors and pRef values that exercise each routing path.
% Labels: [NoDR Mild Moderate Severe Proliferative]

cases = {
%  name                              grade  s5                          pRef
    'Confident NoDR (healthy)'        0    [0.90 0.06 0.03 0.01 0.00]   0.10
    'Confident Severe'                3    [0.01 0.02 0.03 0.88 0.06]   0.85
    'Confident Proliferative'         4    [0.00 0.01 0.02 0.05 0.92]   0.95
    'Low confidence (uniform-ish)'    2    [0.22 0.20 0.24 0.19 0.15]   0.50
    'Moderate/Severe ambiguous'       2    [0.03 0.05 0.45 0.43 0.04]   0.70
    'pRef near 0.60 threshold'        1    [0.15 0.55 0.18 0.08 0.04]   0.59
    'Screen/grade disagree (g=0,pR=0.8)' 0  [0.60 0.25 0.10 0.03 0.02] 0.80
    'Moderate confidence, wide margin' 2   [0.05 0.05 0.70 0.15 0.05]   0.70
    'Mild borderline review'          1    [0.10 0.55 0.25 0.07 0.03]   0.55
};

fprintf('%-38s %4s %9s %7s  %s  %s\n', ...
    'Case', 'Grd', 'Conf', 'Margin', 'Route', 'Reason');
fprintf('%s\n', repmat('-', 1, 110));

for i = 1:size(cases, 1)
    name  = cases{i, 1};
    grade = cases{i, 2};
    s5    = cases{i, 3};
    pRef  = cases{i, 4};

    [route, d] = cascade_router(grade, s5, pRef);

    reason = '';
    if ~isempty(d.abstainReason)
        reason = ['ABSTAIN: ' d.abstainReason];
    elseif ~isempty(d.reviewReason)
        reason = ['REVIEW: ' d.reviewReason];
    else
        reason = 'All clear -- confident, wide margin, models agree';
    end

    fprintf('%-38s %4d %9.3f %7.3f  %-7s  %s\n', ...
        name, grade, d.confidence, d.margin, route, reason);
end

%% ----- Part 2: Verify detail struct fields -----
fprintf('\n--- Detail struct fields for first case ---\n');
[~, d] = cascade_router(0, [0.90 0.06 0.03 0.01 0.00], 0.10);
fnames = fieldnames(d);
for i = 1:numel(fnames)
    v = d.(fnames{i});
    if isnumeric(v)
        fprintf('  %-28s = %g\n', fnames{i}, v);
    elseif islogical(v)
        fprintf('  %-28s = %d\n', fnames{i}, v);
    else
        fprintf('  %-28s = "%s"\n', fnames{i}, v);
    end
end

%% ----- Part 3: Real APTOS training images (optional, ~20 images) -----
fprintf('\n=== Real-image demonstration (APTOS train, first 20 images) ===\n');

imgDir  = fullfile(projRoot, 'data', 'aptos2019', 'train_images');
csvPath = fullfile(projRoot, 'data', 'aptos2019', 'train.csv');

if exist(imgDir, 'dir') && exist(csvPath, 'file')
    T = readtable(csvPath);
    nShow = min(20, height(T));

    % Load models once
    modelDir = fullfile(projRoot, 'data', 'models');
    binPath   = fullfile(modelDir, 'day7_pretrained_resnet18_binary_stage2.mat');
    gradePath = fullfile(modelDir, 'day7_pretrained_resnet18_5class_stage2.mat');

    if exist(binPath, 'file') && exist(gradePath, 'file')
        SB = load(binPath, 'trainedNet');
        S5 = load(gradePath, 'trainedNet');
        netB = SB.trainedNet;
        net5 = S5.trainedNet;

        counts = struct('CLEAR', 0, 'REVIEW', 0, 'ABSTAIN', 0);
        results = cell(nShow, 6);  % img, gt, grade, conf, pRef, route

        for i = 1:nShow
            imgName = T.id_code{i};
            gt = T.diagnosis(i);
            ext = '.png';
            imgPath = fullfile(imgDir, [imgName ext]);
            if ~exist(imgPath, 'file'), continue; end

            raw = imread(imgPath);
            if size(raw, 3) == 1, raw = repmat(raw, 1, 1, 3); end
            modelInput = imresize(raw, [224 224]);

            sB = predict(netB, modelInput); sB = sB(:)';
            pRef = sB(2);

            [~, s5] = classify(net5, modelInput);
            s5 = s5(:)';
            [conf, gradeIdx] = max(s5);
            grade = gradeIdx - 1;

            [route, d] = cascade_router(grade, s5, pRef);
            counts.(route) = counts.(route) + 1;
            results{i, 1} = imgName; results{i, 2} = gt;
            results{i, 3} = grade;   results{i, 4} = conf;
            results{i, 5} = pRef;    results{i, 6} = route;
        end

        fprintf('%-16s %3s %5s %6s %6s  %-7s\n', ...
            'Image', 'GT', 'Grd', 'Conf', 'pRef', 'Route');
        fprintf('%s\n', repmat('-', 1, 62));
        for i = 1:nShow
            if isempty(results{i,1}), continue; end
            fprintf('%-16s %3d %5d %6.2f %6.2f  %-7s\n', ...
                results{i,1}, results{i,2}, results{i,3}, ...
                results{i,4}, results{i,5}, results{i,6});
        end
        fprintf('\nRoute tallies (n=%d):  CLEAR=%d  REVIEW=%d  ABSTAIN=%d\n', ...
            nShow, counts.CLEAR, counts.REVIEW, counts.ABSTAIN);
    else
        fprintf('Models not found at %s -- skipping real-image demo.\n', modelDir);
    end
else
    fprintf('APTOS data not found at %s -- skipping.\n', imgDir);
end

fprintf('\n=== Cascade Router Verification Complete ===\n');
