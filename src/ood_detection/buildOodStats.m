function buildOodStats(varargin)
% BUILDODSTATS Fit Mahalanobis-distance OOD statistics on APTOS train set
%   buildOodStats()           — uses defaults (all 3610 train images)
%   buildOodStats('NumImages', N) — subsample N random images for speed
%
%   Extracts 512-d features from pool5 of the pretrained 5-class ResNet-18,
%   fits per-class mean vectors and a shared pooled covariance with diagonal
%   regularization, calibrates a 99th-percentile threshold, and saves to
%   data/analysis/day8/ood/ood_stats.mat.
%
%   Engineering demo — NOT a clinical device.

    p = inputParser;
    addParameter(p, 'NumImages', 0, @isnumeric);
    addParameter(p, 'Seed', 42, @isnumeric);
    parse(p, varargin{:});

    projectRoot = pwd;
    modelDir = fullfile(projectRoot, 'data', 'models');
    gradePath = fullfile(modelDir, 'day7_pretrained_resnet18_5class_stage2.mat');
    csvPath = fullfile(projectRoot, 'data', 'aptos2019', 'train.csv');
    imgDir = fullfile(projectRoot, 'data', 'aptos2019', 'train_images');
    outDir = fullfile(projectRoot, 'data', 'analysis', 'day8', 'ood');
    featureLayer = 'pool5';
    featDim = 512;
    imgSize = [224 224];

    if ~exist(outDir, 'dir'), mkdir(outDir); end

    %% Load model
    fprintf('Loading 5-class ResNet-18 model...\n');
    S = load(gradePath, 'trainedNet');
    net = S.trainedNet;

    %% Load labels
    T = readtable(csvPath);
    ids = string(T.id_code);
    labels = T.diagnosis;  % 0-4
    nTotal = height(T);
    fprintf('Total training images: %d\n', nTotal);

    %% Subsample if requested
    rng(p.Results.Seed);
    if p.Results.NumImages > 0 && p.Results.NumImages < nTotal
        idx = randperm(nTotal, p.Results.NumImages);
        fprintf('Subsampling %d images (seed=%d)\n', p.Results.NumImages, p.Results.Seed);
    else
        idx = (1:nTotal)';
        fprintf('Using all %d images\n', nTotal);
    end
    nImg = numel(idx);

    %% Extract features in batches
    fprintf('Extracting %d-d features from layer "%s" ...\n', featDim, featureLayer);
    features = zeros(nImg, featDim, 'single');
    labVec = zeros(nImg, 1);
    failed = 0;
    tic;
    for i = 1:nImg
        ii = idx(i);
        fname = char(ids(ii));
        fpath = fullfile(imgDir, [fname, '.png']);
        try
            raw = imread(fpath);
            if size(raw, 3) == 1, raw = repmat(raw, 1, 1, 3); end
            modelIn = imresize(raw, imgSize);
            feat = activations(net, modelIn, featureLayer, 'Output', 'channels');
            features(i, :) = reshape(feat, 1, []);
            labVec(i) = labels(ii);
        catch me
            warning('Failed image %s: %s', fname, me.message);
            failed = failed + 1;
        end
        if mod(i, 500) == 0 || i == nImg
            fprintf('  %d/%d (%.0f sec)\n', i, nImg, toc);
        end
    end
    elapsed = toc;
    fprintf('Feature extraction: %d images, %d failures, %.1f sec\n', nImg, failed, elapsed);

    % Remove any failed rows (all-zero features)
    keep = sum(abs(features), 2) > 0;
    features = features(keep, :);
    labVec = labVec(keep);
    nValid = size(features, 1);

    %% Fit per-class means and shared pooled covariance
    classIds = 0:4;
    nClasses = numel(classIds);
    mu = zeros(nClasses, featDim, 'single');
    classCounts = zeros(nClasses, 1);

    fprintf('Computing per-class means...\n');
    for c = 1:nClasses
        mask = (labVec == classIds(c));
        classCounts(c) = sum(mask);
        if classCounts(c) > 0
            mu(c, :) = mean(features(mask, :), 1);
        end
        fprintf('  class %d: %d images\n', classIds(c), classCounts(c));
    end

    % Shared pooled covariance: average of per-class scatter matrices
    fprintf('Computing pooled covariance (%d x %d)...\n', featDim, featDim);
    Sigma = zeros(featDim, featDim, 'single');
    for c = 1:nClasses
        mask = (labVec == classIds(c));
        if classCounts(c) > 1
            Xc = features(mask, :) - mu(c, :);
            Sigma = Sigma + (Xc' * Xc) / (classCounts(c) - 1);
        end
    end
    % Average over classes (pooled)
    validClasses = classCounts > 1;
    Sigma = Sigma / sum(validClasses);

    % Diagonal regularization for numerical stability
    regEps = 1e-4;
    Sigma = Sigma + regEps * eye(featDim, 'single');
    fprintf('Covariance regularized with eps = %.1e\n', regEps);

    %% Compute in-distribution Mahalanobis distances for threshold calibration
    fprintf('Computing in-distribution distances for threshold calibration...\n');
    SigmaInv = inv(Sigma);  % single precision inverse
    mDistAll = zeros(nValid, 1, 'single');
    nearestClass = zeros(nValid, 1);
    for i = 1:nValid
        dmin = inf;
        for c = 1:nClasses
            diff_c = features(i, :) - mu(c, :);
            d = diff_c * SigmaInv * diff_c';
            if d < dmin
                dmin = d;
                nearestClass(i) = c;
            end
        end
        mDistAll(i) = sqrt(dmin);
    end

    % Distance statistics
    p50 = prctile(mDistAll, 50);
    p90 = prctile(mDistAll, 90);
    p95 = prctile(mDistAll, 95);
    p99 = prctile(mDistAll, 99);
    fprintf('In-distribution Mahalanobis distance stats:\n');
    fprintf('  mean=%.3f  median=%.3f  p90=%.3f  p95=%.3f  p99=%.3f\n', ...
        mean(mDistAll), p50, p90, p95, p99);

    % Threshold: 99th percentile
    threshold = double(p99);
    falseOodRate = double(mean(mDistAll > threshold)) * 100;
    fprintf('Threshold (p99): %.4f\n', threshold);
    fprintf('In-distribution false-OOD rate: %.2f%%\n', falseOodRate);

    %% Save stats
    oodStats = struct();
    oodStats.mu = mu;
    oodStats.Sigma = Sigma;
    oodStats.SigmaInv = SigmaInv;
    oodStats.threshold = threshold;
    oodStats.featDim = featDim;
    oodStats.featureLayer = featureLayer;
    oodStats.imgSize = imgSize;
    oodStats.regEps = regEps;
    oodStats.classIds = classIds;
    oodStats.classCounts = classCounts;
    oodStats.nImagesFit = nValid;
    oodStats.distStats = struct('mean', mean(mDistAll), 'median', p50, ...
        'p90', p90, 'p95', p95, 'p99', p99, ...
        'falseOodRate', falseOodRate);
    oodStats.fitDate = datestr(now);
    oodStats.modelPath = gradePath;

    outPath = fullfile(outDir, 'ood_stats.mat');
    save(outPath, 'oodStats', 'mDistAll', 'labVec');
    fprintf('Saved OOD stats to: %s\n', outPath);
    fprintf('Done.\n');
end
