function runQualityAssessment(mode)
% RUNQUALITYASSESSMENT Batch evaluation of quality assessment on APTOS dataset
%   runQualityAssessment()       - Full mode (all 3662 images)
%   runQualityAssessment('full') - Full mode (all 3662 images)
%   runQualityAssessment('fast') - Fast mode (500 images)
%
%   Runs the quality assessment module on all images in the APTOS dataset
%   and saves results to data/analysis/day3/.
%
%   Output:
%       - quality_assessment_results.csv (per-image results)
%       - quality_assessment_summary.mat (summary statistics)
%       - Console report with pass/fail statistics
%       - Representative quality-gate review examples
%
%   This script does NOT train models or perform clinical validation.
%   Thresholds are engineering prototypes only.

    % Default mode
    if nargin < 1
        mode = 'full';
    end

    %% Setup
    script_dir = fileparts(mfilename('fullpath'));
    project_root = fileparts(fileparts(script_dir));
    cd(project_root);

    addpath(fullfile(project_root, 'src', 'quality'));
    addpath(fullfile(project_root, 'src', 'data_loaders'));

    fprintf('============================================\n');
    fprintf('   DrishtiCare - Day 3 Quality Assessment   \n');
    fprintf('         BATCH EVALUATION                   \n');
    fprintf('============================================\n\n');

    fprintf('Project root: %s\n', project_root);
    fprintf('Mode: %s\n\n', upper(mode));

    %% Load dataset
    dataRoot = fullfile(project_root, 'data', 'aptos2019');
    trainCsv = fullfile(dataRoot, 'train.csv');
    trainDir = fullfile(dataRoot, 'train_images');

    try
        data = readtable(trainCsv);
        allFiles = dir(fullfile(trainDir, '*.png'));
        fprintf('Loaded dataset: %d images\n', length(allFiles));
    catch e
        fprintf('[ERROR] Failed to load dataset: %s\n', e.message);
        return;
    end

    %% Determine sample size
    rng(42);  % Reproducible

    if strcmpi(mode, 'full')
        numSamples = length(allFiles);
        fprintf('Mode: FULL (%d images)\n', numSamples);
    else
        numSamples = min(500, length(allFiles));
        fprintf('Mode: FAST (%d images)\n', numSamples);
    end

    % Stratified sampling
    fprintf('Performing stratified sampling...\n');
    classFiles = cell(5, 1);
    for i = 1:length(allFiles)
        [~, idx] = ismember(allFiles(i).name(1:end-4), data.id_code);
        if idx > 0
            classIdx = data.diagnosis(idx) + 1;
            classFiles{classIdx} = [classFiles{classIdx}; i];
        end
    end

    selectedIndices = [];
    classCounts = zeros(5, 1);
    classNames = {'0-NoDR', '1-Mild', '2-Moderate', '3-Severe', '4-Prolif'};

    for c = 1:5
        classCount = length(classFiles{c});
        if strcmpi(mode, 'full')
            sampleCount = classCount;
        else
            proportion = classCount / length(allFiles);
            sampleCount = max(1, round(numSamples * proportion));
            sampleCount = min(sampleCount, classCount);
        end

        if classCount > 0
            perm = randperm(classCount);
            selectedIndices = [selectedIndices; classFiles{c}(perm(1:sampleCount))];
            classCounts(c) = sampleCount;
        end
    end

    selectedIndices = selectedIndices(randperm(length(selectedIndices)));
    numSelected = length(selectedIndices);

    fprintf('Selected %d images for analysis\n', numSelected);
    fprintf('Class distribution:\n');
    for c = 1:5
        fprintf('  %s: %d\n', classNames{c}, classCounts(c));
    end

    %% Load quality config
    config = defaultQualityConfig();
    fprintf('\nLoaded quality config v%s\n', config.version);
    fprintf('Thresholds derived from: %s\n', config.derivedFrom);

    %% Process images
    fprintf('\n--- Processing Images ---\n');

    % Preallocate results
    id_codes = cell(numSelected, 1);
    diagnoses = zeros(numSelected, 1);
    overall_status = cell(numSelected, 1);
    quality_scores = zeros(numSelected, 1);
    num_pass = zeros(numSelected, 1);
    num_warn = zeros(numSelected, 1);
    num_fail = zeros(numSelected, 1);
    failure_reasons = cell(numSelected, 1);
    feedback_msgs = cell(numSelected, 1);
    brightness_vals = zeros(numSelected, 1);
    contrast_vals = zeros(numSelected, 1);
    focus_vals = zeros(numSelected, 1);
    fg_frac = zeros(numSelected, 1);
    illum_vals = nan(numSelected, 1);
    mask_valid = false(numSelected, 1);

    startTime = tic;

    for i = 1:numSelected
        fileIdx = selectedIndices(i);
        imgName = allFiles(fileIdx).name;
        imgPath = fullfile(trainDir, imgName);

        % Get diagnosis
        [~, dataIdx] = ismember(imgName(1:end-4), data.id_code);
        if dataIdx > 0
            diagnoses(i) = data.diagnosis(dataIdx);
        end

        id_codes{i} = imgName(1:end-4);

        % Read and assess
        try
            img = imread(imgPath);
            [result, metrics] = assessImageQuality(img, 'Config', config);

            overall_status{i} = result.overall;
            quality_scores(i) = result.qualityScore;
            num_pass(i) = result.numPass;
            num_warn(i) = result.numWarning;
            num_fail(i) = result.numFail;
            failure_reasons{i} = strjoin(result.failureReasons, '; ');
            feedback_msgs{i} = result.recaptureAdvice;

            brightness_vals(i) = metrics.brightness;
            contrast_vals(i) = metrics.contrast;
            focus_vals(i) = metrics.focusScore;
            fg_frac(i) = metrics.foregroundFrac;
            illum_vals(i) = metrics.illumination;
            mask_valid(i) = metrics.maskValid;

        catch e
            overall_status{i} = 'ERROR';
            quality_scores(i) = 0.0;
            num_pass(i) = 0;
            num_warn(i) = 0;
            num_fail(i) = 1;
            failure_reasons{i} = sprintf('Processing error: %s', e.message);
            feedback_msgs{i} = 'Image could not be processed.';

            brightness_vals(i) = NaN;
            contrast_vals(i) = NaN;
            focus_vals(i) = NaN;
            fg_frac(i) = NaN;
            illum_vals(i) = NaN;
            mask_valid(i) = false;
        end

        % Progress update
        if mod(i, 100) == 0 || i == numSelected
            elapsed = toc(startTime);
            eta = elapsed / i * (numSelected - i);
            fprintf('  Processed %d/%d (%.1f%%) [ETA: %.0fs]\n', ...
                i, numSelected, i/numSelected*100, eta);
        end
    end

    totalTime = toc(startTime);
    fprintf('\nProcessing complete: %.1f seconds\n', totalTime);
    fprintf('Rate: %.1f images/second\n', numSelected/totalTime);

    %% Build results table
    resultsTable = table(id_codes, diagnoses, overall_status, quality_scores, ...
        num_pass, num_warn, num_fail, failure_reasons, feedback_msgs, ...
        brightness_vals, contrast_vals, focus_vals, ...
        fg_frac, illum_vals, mask_valid, ...
        'VariableNames', {'id_code', 'diagnosis', 'quality_status', 'quality_score', ...
            'num_pass', 'num_warn', 'num_fail', 'failure_reason', 'feedback', ...
            'brightness', 'contrast', 'focus_score', ...
            'foreground_fraction', 'illumination_metric', 'mask_valid'});

    %% Save results
    outputDir = fullfile(project_root, 'data', 'analysis', 'day3');
    if ~exist(outputDir, 'dir')
        mkdir(outputDir);
    end

    % Save CSV
    csvPath = fullfile(outputDir, 'quality_assessment_results.csv');
    writetable(resultsTable, csvPath);
    fprintf('\nSaved CSV: %s\n', csvPath);

    % Save MAT
    summary = struct();
    summary.mode = mode;
    summary.numAnalyzed = numSelected;
    summary.classCounts = classCounts;
    summary.classNames = classNames;
    summary.config = config;
    summary.totalTime = totalTime;
    summary.resultsTable = resultsTable;

    matPath = fullfile(outputDir, 'quality_assessment_summary.mat');
    save(matPath, 'summary');
    fprintf('Saved MAT: %s\n', matPath);

    %% Print summary report
    fprintf('\n============================================\n');
    fprintf('         QUALITY ASSESSMENT RESULTS         \n');
    fprintf('============================================\n\n');

    % Overall statistics
    passCount = sum(strcmp(overall_status, 'PASS'));
    warnCount = sum(strcmp(overall_status, 'WARNING'));
    failCount = sum(strcmp(overall_status, 'FAIL'));
    errorCount = sum(strcmp(overall_status, 'ERROR'));

    fprintf('Overall Quality Status:\n');
    fprintf('  PASS:    %4d (%5.1f%%)\n', passCount, passCount/numSelected*100);
    fprintf('  WARNING: %4d (%5.1f%%)\n', warnCount, warnCount/numSelected*100);
    fprintf('  FAIL:    %4d (%5.1f%%)\n', failCount, failCount/numSelected*100);
    if errorCount > 0
        fprintf('  ERROR:   %4d (%5.1f%%)\n', errorCount, errorCount/numSelected*100);
    end
    fprintf('  TOTAL:   %4d\n', numSelected);

    % Failure reason breakdown
    fprintf('\nFailure Reasons:\n');
    allFailures = failure_reasons(~cellfun(@isempty, failure_reasons));
    if ~isempty(allFailures)
        uniqueReasons = unique(allFailures);
        for i = 1:length(uniqueReasons)
            count = sum(strcmp(allFailures, uniqueReasons{i}));
            fprintf('  [%3d] %s\n', count, uniqueReasons{i});
        end
    else
        fprintf('  None\n');
    end

    % Per-diagnosis breakdown
    fprintf('\nResults by Diagnosis:\n');
    for d = 0:4
        diagMask = diagnoses == d;
        diagStatus = overall_status(diagMask);
        diagPass = sum(strcmp(diagStatus, 'PASS'));
        diagTotal = sum(diagMask);
        if diagTotal > 0
            fprintf('  %s: %d/%d PASS (%.1f%%)\n', ...
                classNames{d+1}, diagPass, diagTotal, diagPass/diagTotal*100);
        end
    end

    % Metric statistics
    fprintf('\nMetric Statistics (across %d images):\n', numSelected);
    fprintf('  Brightness:    mean=%.4f, std=%.4f, range=[%.4f, %.4f]\n', ...
        nanmean(brightness_vals), nanstd(brightness_vals), ...
        nanmin(brightness_vals), nanmax(brightness_vals));
    fprintf('  Contrast:      mean=%.4f, std=%.4f, range=[%.4f, %.4f]\n', ...
        nanmean(contrast_vals), nanstd(contrast_vals), ...
        nanmin(contrast_vals), nanmax(contrast_vals));
    fprintf('  Focus Score:   mean=%.6e, std=%.6e, range=[%.6e, %.6e]\n', ...
        nanmean(focus_vals), nanstd(focus_vals), ...
        nanmin(focus_vals), nanmax(focus_vals));
    fprintf('  Foreground:    mean=%.4f, std=%.4f, range=[%.4f, %.4f]\n', ...
        nanmean(fg_frac), nanstd(fg_frac), ...
        nanmin(fg_frac), nanmax(fg_frac));

    % Threshold comparison
    fprintf('\nThreshold Comparison:\n');
    fprintf('  Brightness PASS range: [%.2f, %.2f]\n', ...
        config.thresholds.brightness.lowerFail, ...
        config.thresholds.brightness.upperFail);
    fprintf('  Contrast PASS range:   [%.2f, %.2f]\n', ...
        config.thresholds.contrast.lowerFail, ...
        config.thresholds.contrast.upperFail);
    fprintf('  Focus PASS range:      [%.2e, %.2e]\n', ...
        config.thresholds.focus.lowerFail, ...
        config.thresholds.focus.upperFail);
    fprintf('  Foreground PASS range: [%.2f, %.2f]\n', ...
        config.thresholds.foreground.lowerFail, ...
        config.thresholds.foreground.upperFail);

    %% Representative Quality-Gate Review
    fprintf('\n============================================\n');
    fprintf('      REPRESENTATIVE QUALITY-GATE REVIEW    \n');
    fprintf('============================================\n\n');

    % Find representative examples
    passIdx = find(strcmp(overall_status, 'PASS'));
    warnIdx = find(strcmp(overall_status, 'WARNING'));
    failIdx = find(strcmp(overall_status, 'FAIL'));

    % Select examples (best, worst, median quality score)
    examples = struct();

    % PASS example (highest quality score)
    if ~isempty(passIdx)
        [~, bestPassLocal] = max(quality_scores(passIdx));
        bestPassIdx = passIdx(bestPassLocal);
        examples.pass = struct(...
            'id_code', id_codes{bestPassIdx}, ...
            'diagnosis', diagnoses(bestPassIdx), ...
            'quality_status', overall_status{bestPassIdx}, ...
            'quality_score', quality_scores(bestPassIdx), ...
            'brightness', brightness_vals(bestPassIdx), ...
            'contrast', contrast_vals(bestPassIdx), ...
            'focus_score', focus_vals(bestPassIdx), ...
            'foreground_fraction', fg_frac(bestPassIdx), ...
            'illumination_metric', illum_vals(bestPassIdx), ...
            'failure_reason', failure_reasons{bestPassIdx}, ...
            'feedback', feedback_msgs{bestPassIdx}, ...
            'image_path', fullfile(trainDir, [id_codes{bestPassIdx}, '.png']));
    end

    % WARNING example (lowest quality score among warnings)
    if ~isempty(warnIdx)
        [~, worstWarnLocal] = min(quality_scores(warnIdx));
        worstWarnIdx = warnIdx(worstWarnLocal);
        examples.warning = struct(...
            'id_code', id_codes{worstWarnIdx}, ...
            'diagnosis', diagnoses(worstWarnIdx), ...
            'quality_status', overall_status{worstWarnIdx}, ...
            'quality_score', quality_scores(worstWarnIdx), ...
            'brightness', brightness_vals(worstWarnIdx), ...
            'contrast', contrast_vals(worstWarnIdx), ...
            'focus_score', focus_vals(worstWarnIdx), ...
            'foreground_fraction', fg_frac(worstWarnIdx), ...
            'illumination_metric', illum_vals(worstWarnIdx), ...
            'failure_reason', failure_reasons{worstWarnIdx}, ...
            'feedback', feedback_msgs{worstWarnIdx}, ...
            'image_path', fullfile(trainDir, [id_codes{worstWarnIdx}, '.png']));
    end

    % FAIL example (lowest quality score)
    if ~isempty(failIdx)
        [~, worstFailLocal] = min(quality_scores(failIdx));
        worstFailIdx = failIdx(worstFailLocal);
        examples.fail = struct(...
            'id_code', id_codes{worstFailIdx}, ...
            'diagnosis', diagnoses(worstFailIdx), ...
            'quality_status', overall_status{worstFailIdx}, ...
            'quality_score', quality_scores(worstFailIdx), ...
            'brightness', brightness_vals(worstFailIdx), ...
            'contrast', contrast_vals(worstFailIdx), ...
            'focus_score', focus_vals(worstFailIdx), ...
            'foreground_fraction', fg_frac(worstFailIdx), ...
            'illumination_metric', illum_vals(worstFailIdx), ...
            'failure_reason', failure_reasons{worstFailIdx}, ...
            'feedback', feedback_msgs{worstFailIdx}, ...
            'image_path', fullfile(trainDir, [id_codes{worstFailIdx}, '.png']));
    end

    % Print examples
    fprintf('--- PASS Example (Highest Quality) ---\n');
    if isfield(examples, 'pass')
        printExample(examples.pass, config);
    end

    fprintf('\n--- WARNING Example (Lowest Quality Among Warnings) ---\n');
    if isfield(examples, 'warning')
        printExample(examples.warning, config);
    end

    fprintf('\n--- FAIL Example (Lowest Quality) ---\n');
    if isfield(examples, 'fail')
        printExample(examples.fail, config);
    end

    %% Important notes
    fprintf('\n--- IMPORTANT NOTES ---\n');
    fprintf('- These are ENGINEERING PROTOTYPE thresholds, NOT clinical standards\n');
    fprintf('- Thresholds derived from Day 2 statistical analysis of APTOS dataset\n');
    fprintf('- Clinical validation requires ophthalmologist review\n');
    fprintf('- Single dataset only (APTOS 2019), not multi-site validated\n');
    fprintf('- Quality gate is a pre-processing filter, not a diagnostic tool\n');

    fprintf('\n=== Day 3 Quality Assessment Complete ===\n');
end

function printExample(ex, config)
    fprintf('  Image:          %s\n', ex.id_code);
    fprintf('  Diagnosis:      %d\n', ex.diagnosis);
    fprintf('  Quality Status: %s\n', ex.quality_status);
    fprintf('  Quality Score:  %.2f\n', ex.quality_score);
    fprintf('  Metrics:\n');
    fprintf('    Brightness:    %.4f\n', ex.brightness);
    fprintf('    Contrast:      %.4f\n', ex.contrast);
    fprintf('    Focus Score:   %.6e\n', ex.focus_score);
    fprintf('    Foreground:    %.4f\n', ex.foreground_fraction);
    fprintf('    Illumination:  %.4f\n', ex.illumination_metric);
    fprintf('  Failure Reason: %s\n', ex.failure_reason);
    fprintf('  Feedback:       %s\n', ex.feedback);

    % Threshold comparison
    fprintf('  Thresholds:\n');
    fprintf('    Brightness: [%.2f, %.2f] PASS\n', ...
        config.thresholds.brightness.lowerFail, ...
        config.thresholds.brightness.upperFail);
    fprintf('    Contrast:   [%.2f, %.2f] PASS\n', ...
        config.thresholds.contrast.lowerFail, ...
        config.thresholds.contrast.upperFail);
    fprintf('    Focus:      [%.2e, %.2e] PASS\n', ...
        config.thresholds.focus.lowerFail, ...
        config.thresholds.focus.upperFail);
    fprintf('    Foreground: [%.2f, %.2f] PASS\n', ...
        config.thresholds.foreground.lowerFail, ...
        config.thresholds.foreground.upperFail);
end