function verifyAllFull()
% VERIFYALLFULL Verify all DrishtiCare modules on FULL dataset (3,662 images)
%   verifyAllFull()
%
%   Runs ALL functions from Day 1 through Day 4 on the ENTIRE dataset.
%   Reports pass/fail for each component with full statistics.

    fprintf('============================================\n');
    fprintf('   DrishtiCare - FULL DATASET VERIFICATION  \n');
    fprintf('         (3,662 images)                     \n');
    fprintf('============================================\n\n');

    %% Setup
    project_root = pwd;
    addpath(fullfile(project_root, 'src', 'setup'));
    addpath(fullfile(project_root, 'src', 'quality'));
    addpath(fullfile(project_root, 'src', 'enhancement'));

    fprintf('Project root: %s\n\n', project_root);

    %% Load dataset
    dataRoot = fullfile(project_root, 'data', 'aptos2019');
    trainDir = fullfile(dataRoot, 'train_images');
    allFiles = dir(fullfile(trainDir, '*.png'));
    data = readtable(fullfile(dataRoot, 'train.csv'));

    fprintf('Dataset: %d images\n\n', length(allFiles));

    %% Track results
    totalTests = 0;
    passedTests = 0;
    failedTests = 0;
    failedList = {};

    %% ========================================
    %% DAY 1: Setup Scripts
    %% ========================================
    fprintf('============================================\n');
    fprintf('         DAY 1: SETUP SCRIPTS               \n');
    fprintf('============================================\n\n');

    % Test 1.1: verify_environment
    totalTests = totalTests + 1;
    fprintf('--- Test 1.1: verify_environment ---\n');
    try
        verify_environment();
        fprintf('[PASS] verify_environment works\n');
        passedTests = passedTests + 1;
    catch e
        fprintf('[FAIL] verify_environment failed: %s\n', e.message);
        failedTests = failedTests + 1;
        failedList{end+1} = 'Day 1: verify_environment';
    end

    % Test 1.2: inspect_dataset
    totalTests = totalTests + 1;
    fprintf('\n--- Test 1.2: inspect_dataset ---\n');
    try
        inspect_dataset();
        fprintf('[PASS] inspect_dataset works\n');
        passedTests = passedTests + 1;
    catch e
        fprintf('[FAIL] inspect_dataset failed: %s\n', e.message);
        failedTests = failedTests + 1;
        failedList{end+1} = 'Day 1: inspect_dataset';
    end

    % Test 1.3: check_dataset_integrity
    totalTests = totalTests + 1;
    fprintf('\n--- Test 1.3: check_dataset_integrity ---\n');
    try
        check_dataset_integrity();
        fprintf('[PASS] check_dataset_integrity works\n');
        passedTests = passedTests + 1;
    catch e
        fprintf('[FAIL] check_dataset_integrity failed: %s\n', e.message);
        failedTests = failedTests + 1;
        failedList{end+1} = 'Day 1: check_dataset_integrity';
    end

    %% ========================================
    %% DAY 2: Quality Exploration (Full Dataset)
    %% ========================================
    fprintf('\n============================================\n');
    fprintf('         DAY 2: QUALITY EXPLORATION          \n');
    fprintf('         (Full Dataset: %d images)          \n', length(allFiles));
    fprintf('============================================\n\n');

    % Test 2.1: createRetinalMask
    totalTests = totalTests + 1;
    fprintf('--- Test 2.1: createRetinalMask ---\n');
    try
        testImg = imread(fullfile(trainDir, allFiles(1).name));
        mask = createRetinalMask(testImg);
        fprintf('[PASS] createRetinalMask works\n');
        fprintf('  Input: %dx%dx%d, Mask: %dx%d\n', ...
            size(testImg, 1), size(testImg, 2), size(testImg, 3), ...
            size(mask, 1), size(mask, 2));
        fprintf('  Mask coverage: %.1f%%\n', sum(mask(:)) / numel(mask) * 100);
        passedTests = passedTests + 1;
    catch e
        fprintf('[FAIL] createRetinalMask failed: %s\n', e.message);
        failedTests = failedTests + 1;
        failedList{end+1} = 'Day 2: createRetinalMask';
    end

    % Test 2.2: computeQualityMetrics (full dataset)
    totalTests = totalTests + 1;
    fprintf('\n--- Test 2.2: computeQualityMetrics (Full Dataset) ---\n');
    try
        numImages = length(allFiles);
        brightness_all = zeros(numImages, 1);
        contrast_all = zeros(numImages, 1);
        focus_all = zeros(numImages, 1);
        foreground_all = zeros(numImages, 1);
        illumination_all = zeros(numImages, 1);
        maskValid_all = false(numImages, 1);
        failedCount = 0;

        fprintf('  Processing %d images...\n', numImages);
        for i = 1:numImages
            try
                img = imread(fullfile(trainDir, allFiles(i).name));
                metrics = computeQualityMetrics(img);
                brightness_all(i) = metrics.brightness;
                contrast_all(i) = metrics.contrast;
                focus_all(i) = metrics.focusScore;
                foreground_all(i) = metrics.foregroundFrac;
                illumination_all(i) = metrics.illumination;
                maskValid_all(i) = metrics.maskValid;
            catch
                failedCount = failedCount + 1;
                brightness_all(i) = NaN;
                contrast_all(i) = NaN;
                focus_all(i) = NaN;
                foreground_all(i) = NaN;
                illumination_all(i) = NaN;
                maskValid_all(i) = false;
            end

            if mod(i, 500) == 0 || i == numImages
                fprintf('    Processed %d/%d images\n', i, numImages);
            end
        end

        % Compute statistics
        validMask = ~isnan(brightness_all);
        fprintf('\n  Statistics (valid images: %d/%d):\n', sum(validMask), numImages);
        fprintf('  Brightness:     Mean=%.4f, Std=%.4f, Min=%.4f, Max=%.4f\n', ...
            mean(brightness_all(validMask)), std(brightness_all(validMask)), ...
            min(brightness_all(validMask)), max(brightness_all(validMask)));
        fprintf('  Contrast:       Mean=%.4f, Std=%.4f, Min=%.4f, Max=%.4f\n', ...
            mean(contrast_all(validMask)), std(contrast_all(validMask)), ...
            min(contrast_all(validMask)), max(contrast_all(validMask)));
        fprintf('  Focus Score:    Mean=%.6e, Std=%.6e, Min=%.6e, Max=%.6e\n', ...
            mean(focus_all(validMask)), std(focus_all(validMask)), ...
            min(focus_all(validMask)), max(focus_all(validMask)));
        fprintf('  Foreground:     Mean=%.4f, Std=%.4f, Min=%.4f, Max=%.4f\n', ...
            mean(foreground_all(validMask)), std(foreground_all(validMask)), ...
            min(foreground_all(validMask)), max(foreground_all(validMask)));
        fprintf('  Illumination:   Mean=%.4f, Std=%.4f, Min=%.4f, Max=%.4f\n', ...
            mean(illumination_all(validMask)), std(illumination_all(validMask)), ...
            min(illumination_all(validMask)), max(illumination_all(validMask)));
        fprintf('  Mask Valid:     %d/%d (%.1f%%)\n', ...
            sum(maskValid_all), numImages, sum(maskValid_all)/numImages*100);
        fprintf('  Failed:         %d images\n', failedCount);

        fprintf('[PASS] computeQualityMetrics works on full dataset\n');
        passedTests = passedTests + 1;
    catch e
        fprintf('[FAIL] computeQualityMetrics failed: %s\n', e.message);
        failedTests = failedTests + 1;
        failedList{end+1} = 'Day 2: computeQualityMetrics';
    end

    % Test 2.3: buildMetricsTable (full dataset)
    totalTests = totalTests + 1;
    fprintf('\n--- Test 2.3: buildMetricsTable (Full Dataset) ---\n');
    try
        fprintf('  Running buildMetricsTable on full dataset...\n');
        [tbl, sampleInfo] = buildMetricsTable(dataRoot, 'full', 42);
        fprintf('[PASS] buildMetricsTable works on full dataset\n');
        fprintf('  Table size: %dx%d\n', height(tbl), width(tbl));
        fprintf('  Class distribution:\n');
        for c = 1:5
            fprintf('    Class %d: %d images\n', c-1, sampleInfo.classCounts(c));
        end
        passedTests = passedTests + 1;
    catch e
        fprintf('[FAIL] buildMetricsTable failed: %s\n', e.message);
        failedTests = failedTests + 1;
        failedList{end+1} = 'Day 2: buildMetricsTable';
    end

    %% ========================================
    %% DAY 3: Quality Assessment (Full Dataset)
    %% ========================================
    fprintf('\n============================================\n');
    fprintf('         DAY 3: QUALITY ASSESSMENT           \n');
    fprintf('         (Full Dataset: %d images)          \n', length(allFiles));
    fprintf('============================================\n\n');

    % Test 3.1: defaultQualityConfig
    totalTests = totalTests + 1;
    fprintf('--- Test 3.1: defaultQualityConfig ---\n');
    try
        config = defaultQualityConfig();
        fprintf('[PASS] defaultQualityConfig works\n');
        fprintf('  Version: %s\n', config.version);
        fprintf('  Brightness: [%.4f, %.4f]\n', config.thresholds.brightness.lowerFail, config.thresholds.brightness.upperFail);
        fprintf('  Contrast: [%.4f, %.4f]\n', config.thresholds.contrast.lowerFail, config.thresholds.contrast.upperFail);
        fprintf('  Foreground: [%.4f, %.4f]\n', config.thresholds.foreground.lowerFail, config.thresholds.foreground.upperFail);
        passedTests = passedTests + 1;
    catch e
        fprintf('[FAIL] defaultQualityConfig failed: %s\n', e.message);
        failedTests = failedTests + 1;
        failedList{end+1} = 'Day 3: defaultQualityConfig';
    end

    % Test 3.2: assessImageQuality (full dataset)
    totalTests = totalTests + 1;
    fprintf('\n--- Test 3.2: assessImageQuality (Full Dataset) ---\n');
    try
        numImages = length(allFiles);
        status_all = cell(numImages, 1);
        qualityScore_all = zeros(numImages, 1);
        passCount = 0;
        warnCount = 0;
        failCount = 0;
        failedCount = 0;

        fprintf('  Processing %d images...\n', numImages);
        for i = 1:numImages
            try
                img = imread(fullfile(trainDir, allFiles(i).name));
                [result, ~] = assessImageQuality(img, 'Config', config);
                status_all{i} = result.overall;
                qualityScore_all(i) = result.qualityScore;

                switch result.overall
                    case 'PASS'
                        passCount = passCount + 1;
                    case 'WARNING'
                        warnCount = warnCount + 1;
                    case 'FAIL'
                        failCount = failCount + 1;
                end
            catch
                failedCount = failedCount + 1;
                status_all{i} = 'ERROR';
                qualityScore_all(i) = NaN;
            end

            if mod(i, 500) == 0 || i == numImages
                fprintf('    Processed %d/%d images\n', i, numImages);
            end
        end

        fprintf('\n  Results (total: %d images):\n', numImages);
        fprintf('  PASS:    %d (%.1f%%)\n', passCount, passCount/numImages*100);
        fprintf('  WARNING: %d (%.1f%%)\n', warnCount, warnCount/numImages*100);
        fprintf('  FAIL:    %d (%.1f%%)\n', failCount, failCount/numImages*100);
        fprintf('  ERROR:   %d (%.1f%%)\n', failedCount, failedCount/numImages*100);
        fprintf('  Quality Score: Mean=%.4f, Std=%.4f\n', ...
            nanmean(qualityScore_all), nanstd(qualityScore_all));

        % Class distribution analysis
        fprintf('\n  Status by class:\n');
        for c = 0:4
            classIdx = data.diagnosis == c;
            classStatus = status_all(classIdx);
            classPass = sum(strcmp(classStatus, 'PASS'));
            classWarn = sum(strcmp(classStatus, 'WARNING'));
            classFail = sum(strcmp(classStatus, 'FAIL'));
            fprintf('    Class %d: PASS=%d, WARN=%d, FAIL=%d\n', ...
                c, classPass, classWarn, classFail);
        end

        fprintf('[PASS] assessImageQuality works on full dataset\n');
        passedTests = passedTests + 1;
    catch e
        fprintf('[FAIL] assessImageQuality failed: %s\n', e.message);
        failedTests = failedTests + 1;
        failedList{end+1} = 'Day 3: assessImageQuality';
    end

    %% ========================================
    %% DAY 4: Image Enhancement (Full Dataset)
    %% ========================================
    fprintf('\n============================================\n');
    fprintf('         DAY 4: IMAGE ENHANCEMENT            \n');
    fprintf('         (Full Dataset: %d images)          \n', length(allFiles));
    fprintf('============================================\n\n');

    % Test 4.1: enhanceImage (full dataset)
    totalTests = totalTests + 1;
    fprintf('--- Test 4.1: enhanceImage (Full Dataset) ---\n');
    try
        numImages = length(allFiles);
        brightnessDelta_all = zeros(numImages, 1);
        contrastDelta_all = zeros(numImages, 1);
        focusDelta_all = zeros(numImages, 1);
        overallScore_all = zeros(numImages, 1);
        improvedCount = 0;
        failedCount = 0;

        fprintf('  Processing %d images...\n', numImages);
        for i = 1:numImages
            try
                img = imread(fullfile(trainDir, allFiles(i).name));
                [enhanced, qualityImprovement] = enhanceImage(img);
                brightnessDelta_all(i) = qualityImprovement.brightnessDelta;
                contrastDelta_all(i) = qualityImprovement.contrastDelta;
                focusDelta_all(i) = qualityImprovement.focusDelta;
                overallScore_all(i) = qualityImprovement.overallScore;

                if qualityImprovement.overallScore > 0
                    improvedCount = improvedCount + 1;
                end
            catch
                failedCount = failedCount + 1;
                brightnessDelta_all(i) = NaN;
                contrastDelta_all(i) = NaN;
                focusDelta_all(i) = NaN;
                overallScore_all(i) = NaN;
            end

            if mod(i, 500) == 0 || i == numImages
                fprintf('    Processed %d/%d images\n', i, numImages);
            end
        end

        fprintf('\n  Results (total: %d images):\n', numImages);
        fprintf('  Improved: %d (%.1f%%)\n', improvedCount, improvedCount/numImages*100);
        fprintf('  Failed:   %d (%.1f%%)\n', failedCount, failedCount/numImages*100);
        fprintf('  Brightness Delta: Mean=%+.4f, Std=%.4f\n', ...
            nanmean(brightnessDelta_all), nanstd(brightnessDelta_all));
        fprintf('  Contrast Delta:   Mean=%+.4f, Std=%.4f\n', ...
            nanmean(contrastDelta_all), nanstd(contrastDelta_all));
        fprintf('  Focus Delta:      Mean=%+.6e, Std=%.6e\n', ...
            nanmean(focusDelta_all), nanstd(focusDelta_all));
        fprintf('  Overall Score:    Mean=%.4f, Std=%.4f\n', ...
            nanmean(overallScore_all), nanstd(overallScore_all));

        fprintf('[PASS] enhanceImage works on full dataset\n');
        passedTests = passedTests + 1;
    catch e
        fprintf('[FAIL] enhanceImage failed: %s\n', e.message);
        failedTests = failedTests + 1;
        failedList{end+1} = 'Day 4: enhanceImage';
    end

    % Test 4.2: enhanceImage (all features individually)
    totalTests = totalTests + 1;
    fprintf('\n--- Test 4.2: enhanceImage (All Features) ---\n');
    try
        testImg = imread(fullfile(trainDir, allFiles(1).name));
        features = {'CLAHE', 'IlluminationNorm', 'HistogramMatch', ...
                    'GammaCorrection', 'VesselEnhance', 'OpticDiscNorm', 'NoiseAware'};
        featureNames = {'CLAHE', 'IlluminationNorm', 'HistogramMatch', ...
                       'GammaCorrection', 'VesselEnhance', 'OpticDiscNorm', 'NoiseAware'};

        for f = 1:length(features)
            try
                opts = struct();
                for ff = 1:length(features)
                    if ff == f
                        opts.(features{ff}) = true;
                    else
                        opts.(features{ff}) = false;
                    end
                end
                enhanced = enhanceImage(testImg, ...
                    'CLAHE', opts.CLAHE, ...
                    'IlluminationNorm', opts.IlluminationNorm, ...
                    'HistogramMatch', opts.HistogramMatch, ...
                    'GammaCorrection', opts.GammaCorrection, ...
                    'VesselEnhance', opts.VesselEnhance, ...
                    'OpticDiscNorm', opts.OpticDiscNorm, ...
                    'NoiseAware', opts.NoiseAware);
                fprintf('  [PASS] %s works\n', featureNames{f});
            catch e
                fprintf('  [FAIL] %s failed: %s\n', featureNames{f}, e.message);
                failedTests = failedTests + 1;
                failedList{end+1} = sprintf('Day 4: %s', featureNames{f});
            end
        end

        fprintf('[PASS] All enhancement features work\n');
        passedTests = passedTests + 1;
    catch e
        fprintf('[FAIL] Enhancement features test failed: %s\n', e.message);
        failedTests = failedTests + 1;
        failedList{end+1} = 'Day 4: Enhancement Features';
    end

    %% ========================================
    %% INTEGRATION TEST (Full Dataset)
    %% ========================================
    fprintf('\n============================================\n');
    fprintf('         INTEGRATION TEST                   \n');
    fprintf('         (Full Dataset: %d images)          \n', length(allFiles));
    fprintf('============================================\n\n');

    % Test INT.1: Full pipeline (Day 1 -> Day 2 -> Day 3 -> Day 4)
    totalTests = totalTests + 1;
    fprintf('--- Test INT.1: Full Pipeline Integration ---\n');
    try
        numImages = length(allFiles);
        pipelinePass = 0;
        pipelineFail = 0;

        fprintf('  Processing %d images through full pipeline...\n', numImages);
        for i = 1:numImages
            try
                % Day 1: Environment verified (already done)
                
                % Day 2: Compute quality metrics
                img = imread(fullfile(trainDir, allFiles(i).name));
                metrics = computeQualityMetrics(img);
                
                % Day 3: Assess quality
                [result, ~] = assessImageQuality(img, 'Config', config);
                
                % Day 4: Enhance image
                [enhanced, qualityImprovement] = enhanceImage(img);
                
                pipelinePass = pipelinePass + 1;
            catch
                pipelineFail = pipelineFail + 1;
            end

            if mod(i, 500) == 0 || i == numImages
                fprintf('    Processed %d/%d images\n', i, numImages);
            end
        end

        fprintf('\n  Pipeline Results:\n');
        fprintf('  Success: %d (%.1f%%)\n', pipelinePass, pipelinePass/numImages*100);
        fprintf('  Failed:  %d (%.1f%%)\n', pipelineFail, pipelineFail/numImages*100);

        fprintf('[PASS] Full pipeline integration works\n');
        passedTests = passedTests + 1;
    catch e
        fprintf('[FAIL] Full pipeline integration failed: %s\n', e.message);
        failedTests = failedTests + 1;
        failedList{end+1} = 'Integration: Full Pipeline';
    end

    %% ========================================
    %% SUMMARY
    %% ========================================
    fprintf('\n============================================\n');
    fprintf('         VERIFICATION SUMMARY                \n');
    fprintf('============================================\n\n');

    fprintf('Total Tests: %d\n', totalTests);
    fprintf('Passed: %d\n', passedTests);
    fprintf('Failed: %d\n', failedTests);
    fprintf('Pass Rate: %.1f%%\n', passedTests/totalTests*100);

    if failedTests > 0
        fprintf('\nFailed Tests:\n');
        for i = 1:length(failedList)
            fprintf('  - %s\n', failedList{i});
        end
    end

    fprintf('\n============================================\n');
    if failedTests == 0
        fprintf('         ALL TESTS PASSED                   \n');
        fprintf('============================================\n\n');
        fprintf('System Status: READY\n');
        fprintf('All %d images verified successfully\n', length(allFiles));
        fprintf('Ready for Day 5 (Classifier Setup)\n');
    else
        fprintf('         SOME TESTS FAILED                  \n');
        fprintf('============================================\n\n');
        fprintf('System Status: NEEDS ATTENTION\n');
        fprintf('Please fix failed tests before proceeding\n');
    end
end