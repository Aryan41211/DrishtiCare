function result = tuneReferableThreshold(trainedNet, valDSraw, varargin)
% TUNEREFERABLETHRESHOLD Sweep P(referable) threshold on validation only
%   result = tuneReferableThreshold(trainedNet, valDSraw, 'Config', config)
%
%   P(referable) = P(class_2) + P(class_3) + P(class_4)
%   Uses ONLY validation data. Never touch the official test set.
%
%   Saves sweep table + plot under data/analysis/day5/.

    p = inputParser;
    addParameter(p, 'Config', [], @(x) isstruct(x));
    parse(p, varargin{:});
    config = p.Results.Config;
    if isempty(config)
        config = defaultTrainingConfig();
    end

    fileCount = length(valDSraw.Files);
    fprintf('Computing validation probabilities for %d files...\n', fileCount);

    PRef = zeros(fileCount, 1);
    YTrueRef = false(fileCount, 1);
    referableIdx = [3, 4, 5];  % class_2, class_3, class_4 (1-indexed)

    for i = 1:fileCount
        img = imread(valDSraw.Files{i});
        img = imresize(img, config.input.imageSize(1:2));
        scores = predict(trainedNet, img);  % 1x5 scores in network class order
        scores = scores(:)';
        PRef(i) = sum(scores(referableIdx));

        folderPath = fileparts(valDSraw.Files{i});
        [~, folderName] = fileparts(folderPath);
        tokens = regexp(folderName, 'class_(\d+)', 'tokens');
        trueClass = str2double(tokens{1}{1}) + 1;
        YTrueRef(i) = ismember(trueClass, config.classes.referable);
        if mod(i, 100) == 0
            fprintf('  %d/%d\n', i, fileCount);
        end
    end

    thresholds = 0.10:0.05:0.90;
    n = length(thresholds);
    sens = zeros(n,1); spec = zeros(n,1);
    ppv = zeros(n,1); f1 = zeros(n,1);
    for k = 1:n
        YPredRef = PRef >= thresholds(k);
        tp = sum(YTrueRef & YPredRef);
        fp = sum(~YTrueRef & YPredRef);
        fn = sum(YTrueRef & ~YPredRef);
        tn = sum(~YTrueRef & ~YPredRef);
        sens(k) = tp / (tp + fn + eps);
        spec(k) = tn / (tn + fp + eps);
        ppv(k) = tp / (tp + fp + eps);
        f1(k) = 2 * ppv(k) * sens(k) / (ppv(k) + sens(k) + eps);
    end

    [~, bestIdx] = max(f1);
    result = struct();
    result.thresholds = thresholds(:);
    result.sensitivity = sens;
    result.specificity = spec;
    result.ppv = ppv;
    result.f1 = f1;
    result.bestThreshold = thresholds(bestIdx);
    result.bestSensitivity = sens(bestIdx);
    result.bestSpecificity = spec(bestIdx);
    result.bestF1 = f1(bestIdx);
    result.date = datestr(now);
    result.note = 'Validation-derived threshold, not clinically validated';

    fprintf('\n=== Referable Threshold Sweep (validation only) ===\n');
    fprintf('%-8s %-8s %-8s %-8s %-8s\n', 'Thr', 'Sens', 'Spec', 'PPV', 'F1');
    for k = 1:n
        fprintf('%-8.2f %-8.4f %-8.4f %-8.4f %-8.4f\n', ...
            thresholds(k), sens(k), spec(k), ppv(k), f1(k));
    end
    fprintf('Best: thr=%.2f sens=%.4f spec=%.4f F1=%.4f\n', ...
        result.bestThreshold, result.bestSensitivity, ...
        result.bestSpecificity, result.bestF1);

    outPath = fullfile(config.dataset.analysisDir, ...
        [config.experimentId '_referable_threshold.mat']);
    save(outPath, 'result');
    fprintf('Saved: %s\n', outPath);

    fig = figure('Visible', 'off');
    plot(thresholds, sens, 'b-o', thresholds, spec, 'r-s', ...
         thresholds, f1, 'g-^', 'LineWidth', 1.5);
    xlabel('P(referable) threshold');
    ylabel('Score');
    title('Referable Threshold Sweep (validation)');
    legend('Sensitivity', 'Specificity', 'F1', 'Location', 'best');
    grid on;
    plotPath = fullfile(config.dataset.analysisDir, ...
        [config.experimentId '_referable_threshold.png']);
    saveas(fig, plotPath);
    close(fig);
    fprintf('Saved: %s\n', plotPath);
end