function verifyAll()
% VERIFYALL Comprehensive verification of all DrishtiCare modules
%   verifyAll()
%
%   Tests ALL functions from Day 1 through Day 4.
%   Reports pass/fail for each component.
%
%   Output:
%       - Console report with all test results
%       - Summary of system status

    fprintf('============================================\n');
    fprintf('   DrishtiCare - COMPLETE SYSTEM VERIFICATION\n');
    fprintf('============================================\n\n');

    %% Setup
    project_root = pwd;

    % Add all source paths
    addpath(fullfile(project_root, 'src', 'setup'));
    addpath(fullfile(project_root, 'src', 'quality'));
    addpath(fullfile(project_root, 'src', 'enhancement'));

    fprintf('Project root: %s\n\n', project_root);

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
    %% DAY 2: Quality Exploration
    %% ========================================
    fprintf('\n============================================\n');
    fprintf('         DAY 2: QUALITY EXPLORATION          \n');
    fprintf('============================================\n\n');

    % Test 2.1: createRetinalMask
    totalTests = totalTests + 1;
    fprintf('--- Test 2.1: createRetinalMask ---\n');
    try
        dataRoot = fullfile(project_root, 'data', 'aptos2019');
        trainDir = fullfile(dataRoot, 'train_images');
        allFiles = dir(fullfile(trainDir, '*.png'));
        testImg = imread(fullfile(trainDir, allFiles(1).name));
        
        mask = createRetinalMask(testImg);
        fprintf('[PASS] createRetinalMask works\n');
        fprintf('  Input size: %dx%dx%d\n', size(testImg, 1), size(testImg, 2), size(testImg, 3));
        fprintf('  Mask size: %dx%d\n', size(mask, 1), size(mask, 2));
        fprintf('  Mask coverage: %.1f%%\n', sum(mask(:)) / numel(mask) * 100);
        passedTests = passedTests + 1;
    catch e
        fprintf('[FAIL] createRetinalMask failed: %s\n', e.message);
        failedTests = failedTests + 1;
        failedList{end+1} = 'Day 2: createRetinalMask';
    end

    % Test 2.2: computeQualityMetrics
    totalTests = totalTests + 1;
    fprintf('\n--- Test 2.2: computeQualityMetrics ---\n');
    try
        metrics = computeQualityMetrics(testImg);
        fprintf('[PASS] computeQualityMetrics works\n');
        fprintf('  Brightness: %.4f\n', metrics.brightness);
        fprintf('  Contrast: %.4f\n', metrics.contrast);
        fprintf('  Focus Score: %.6e\n', metrics.focusScore);
        fprintf('  Foreground Fraction: %.4f\n', metrics.foregroundFrac);
        fprintf('  Mask Valid: %d\n', metrics.maskValid);
        passedTests = passedTests + 1;
    catch e
        fprintf('[FAIL] computeQualityMetrics failed: %s\n', e.message);
        failedTests = failedTests + 1;
        failedList{end+1} = 'Day 2: computeQualityMetrics';
    end

    % Test 2.3: buildMetricsTable
    totalTests = totalTests + 1;
    fprintf('\n--- Test 2.3: buildMetricsTable ---\n');
    try
        tbl = buildMetricsTable(fullfile(project_root, 'data', 'aptos2019'), 'fast', 42);
        fprintf('[PASS] buildMetricsTable works\n');
        fprintf('  Table size: %dx%d\n', height(tbl), width(tbl));
        fprintf('  Columns: %s\n', strjoin(tbl.Properties.VariableNames, ', '));
        passedTests = passedTests + 1;
    catch e
        fprintf('[FAIL] buildMetricsTable failed: %s\n', e.message);
        failedTests = failedTests + 1;
        failedList{end+1} = 'Day 2: buildMetricsTable';
    end

    %% ========================================
    %% DAY 3: Quality Assessment
    %% ========================================
    fprintf('\n============================================\n');
    fprintf('         DAY 3: QUALITY ASSESSMENT           \n');
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

    % Test 3.2: assessImageQuality
    totalTests = totalTests + 1;
    fprintf('\n--- Test 3.2: assessImageQuality ---\n');
    try
        [result, metrics] = assessImageQuality(testImg, 'Config', config);
        fprintf('[PASS] assessImageQuality works\n');
        fprintf('  Status: %s\n', result.overall);
        fprintf('  Quality Score: %.4f\n', result.qualityScore);
        fprintf('  Pass: %d, Warn: %d, Fail: %d\n', ...
            result.numPass, result.numWarning, result.numFail);
        if ~isempty(result.failureReasons)
            fprintf('  Failure Reason: %s\n', result.failureReasons{1});
        end
        passedTests = passedTests + 1;
    catch e
        fprintf('[FAIL] assessImageQuality failed: %s\n', e.message);
        failedTests = failedTests + 1;
        failedList{end+1} = 'Day 3: assessImageQuality';
    end

    % Test 3.3: testQualityAssessment (run tests)
    totalTests = totalTests + 1;
    fprintf('\n--- Test 3.3: testQualityAssessment ---\n');
    try
        testQualityAssessment();
        fprintf('[PASS] testQualityAssessment works\n');
        passedTests = passedTests + 1;
    catch e
        fprintf('[FAIL] testQualityAssessment failed: %s\n', e.message);
        failedTests = failedTests + 1;
        failedList{end+1} = 'Day 3: testQualityAssessment';
    end

    %% ========================================
    %% DAY 4: Image Enhancement
    %% ========================================
    fprintf('\n============================================\n');
    fprintf('         DAY 4: IMAGE ENHANCEMENT            \n');
    fprintf('============================================\n\n');

    % Test 4.1: enhanceImage (all features)
    totalTests = totalTests + 1;
    fprintf('--- Test 4.1: enhanceImage (all features) ---\n');
    try
        [enhanced, qualityImprovement] = enhanceImage(testImg);
        fprintf('[PASS] enhanceImage works\n');
        fprintf('  Input size: %dx%dx%d\n', size(testImg, 1), size(testImg, 2), size(testImg, 3));
        fprintf('  Output size: %dx%dx%d\n', size(enhanced, 1), size(enhanced, 2), size(enhanced, 3));
        fprintf('  Quality improvement score: %.4f\n', qualityImprovement.overallScore);
        fprintf('  Brightness: %.4f -> %.4f (Δ = %+.4f)\n', ...
            qualityImprovement.original.brightness, qualityImprovement.enhanced.brightness, ...
            qualityImprovement.brightnessDelta);
        fprintf('  Contrast: %.4f -> %.4f (Δ = %+.4f)\n', ...
            qualityImprovement.original.contrast, qualityImprovement.enhanced.contrast, ...
            qualityImprovement.contrastDelta);
        passedTests = passedTests + 1;
    catch e
        fprintf('[FAIL] enhanceImage failed: %s\n', e.message);
        failedTests = failedTests + 1;
        failedList{end+1} = 'Day 4: enhanceImage';
    end

    % Test 4.2: enhanceImage (CLAHE only)
    totalTests = totalTests + 1;
    fprintf('\n--- Test 4.2: enhanceImage (CLAHE only) ---\n');
    try
        enhanced_clahe = enhanceImage(testImg, 'CLAHE', true, 'IlluminationNorm', false, ...
            'Denoise', false, 'GammaCorrection', false, 'Sharpen', false, ...
            'HistogramMatch', false, 'VesselEnhance', false, 'OpticDiscNorm', false);
        fprintf('[PASS] CLAHE enhancement works\n');
        passedTests = passedTests + 1;
    catch e
        fprintf('[FAIL] CLAHE enhancement failed: %s\n', e.message);
        failedTests = failedTests + 1;
        failedList{end+1} = 'Day 4: CLAHE';
    end

    % Test 4.3: enhanceImage (illumination normalization only)
    totalTests = totalTests + 1;
    fprintf('\n--- Test 4.3: enhanceImage (illumination normalization only) ---\n');
    try
        enhanced_illum = enhanceImage(testImg, 'CLAHE', false, 'IlluminationNorm', true, ...
            'Denoise', false, 'GammaCorrection', false, 'Sharpen', false, ...
            'HistogramMatch', false, 'VesselEnhance', false, 'OpticDiscNorm', false);
        fprintf('[PASS] Illumination normalization works\n');
        passedTests = passedTests + 1;
    catch e
        fprintf('[FAIL] Illumination normalization failed: %s\n', e.message);
        failedTests = failedTests + 1;
        failedList{end+1} = 'Day 4: IlluminationNorm';
    end

    % Test 4.4: enhanceImage (histogram matching only)
    totalTests = totalTests + 1;
    fprintf('\n--- Test 4.4: enhanceImage (histogram matching only) ---\n');
    try
        enhanced_hist = enhanceImage(testImg, 'CLAHE', false, 'IlluminationNorm', false, ...
            'Denoise', false, 'GammaCorrection', false, 'Sharpen', false, ...
            'HistogramMatch', true, 'VesselEnhance', false, 'OpticDiscNorm', false);
        fprintf('[PASS] Histogram matching works\n');
        passedTests = passedTests + 1;
    catch e
        fprintf('[FAIL] Histogram matching failed: %s\n', e.message);
        failedTests = failedTests + 1;
        failedList{end+1} = 'Day 4: HistogramMatch';
    end

    % Test 4.5: enhanceImage (gamma correction only)
    totalTests = totalTests + 1;
    fprintf('\n--- Test 4.5: enhanceImage (gamma correction only) ---\n');
    try
        enhanced_gamma = enhanceImage(testImg, 'CLAHE', false, 'IlluminationNorm', false, ...
            'Denoise', false, 'GammaCorrection', true, 'Sharpen', false, ...
            'HistogramMatch', false, 'VesselEnhance', false, 'OpticDiscNorm', false);
        fprintf('[PASS] Gamma correction works\n');
        passedTests = passedTests + 1;
    catch e
        fprintf('[FAIL] Gamma correction failed: %s\n', e.message);
        failedTests = failedTests + 1;
        failedList{end+1} = 'Day 4: GammaCorrection';
    end

    % Test 4.6: enhanceImage (vessel enhancement only)
    totalTests = totalTests + 1;
    fprintf('\n--- Test 4.6: enhanceImage (vessel enhancement only) ---\n');
    try
        enhanced_vessel = enhanceImage(testImg, 'CLAHE', false, 'IlluminationNorm', false, ...
            'Denoise', false, 'GammaCorrection', false, 'Sharpen', false, ...
            'HistogramMatch', false, 'VesselEnhance', true, 'OpticDiscNorm', false);
        fprintf('[PASS] Vessel enhancement works\n');
        passedTests = passedTests + 1;
    catch e
        fprintf('[FAIL] Vessel enhancement failed: %s\n', e.message);
        failedTests = failedTests + 1;
        failedList{end+1} = 'Day 4: VesselEnhance';
    end

    % Test 4.7: enhanceImage (optic disc normalization only)
    totalTests = totalTests + 1;
    fprintf('\n--- Test 4.7: enhanceImage (optic disc normalization only) ---\n');
    try
        enhanced_optic = enhanceImage(testImg, 'CLAHE', false, 'IlluminationNorm', false, ...
            'Denoise', false, 'GammaCorrection', false, 'Sharpen', false, ...
            'HistogramMatch', false, 'VesselEnhance', false, 'OpticDiscNorm', true);
        fprintf('[PASS] Optic disc normalization works\n');
        passedTests = passedTests + 1;
    catch e
        fprintf('[FAIL] Optic disc normalization failed: %s\n', e.message);
        failedTests = failedTests + 1;
        failedList{end+1} = 'Day 4: OpticDiscNorm';
    end

    % Test 4.8: enhanceImage (noise-aware processing)
    totalTests = totalTests + 1;
    fprintf('\n--- Test 4.8: enhanceImage (noise-aware processing) ---\n');
    try
        enhanced_noise = enhanceImage(testImg, 'NoiseAware', true);
        fprintf('[PASS] Noise-aware processing works\n');
        passedTests = passedTests + 1;
    catch e
        fprintf('[FAIL] Noise-aware processing failed: %s\n', e.message);
        failedTests = failedTests + 1;
        failedList{end+1} = 'Day 4: NoiseAware';
    end

    % Test 4.9: enhanceImage (all channels vs green only)
    totalTests = totalTests + 1;
    fprintf('\n--- Test 4.9: enhanceImage (all channels vs green only) ---\n');
    try
        [enhanced_all, quality_all] = enhanceImage(testImg, 'AllChannels', true);
        [enhanced_green, quality_green] = enhanceImage(testImg, 'AllChannels', false);
        fprintf('[PASS] All channels vs green only works\n');
        fprintf('  All channels quality score: %.4f\n', quality_all.overallScore);
        fprintf('  Green only quality score: %.4f\n', quality_green.overallScore);
        passedTests = passedTests + 1;
    catch e
        fprintf('[FAIL] All channels vs green only failed: %s\n', e.message);
        failedTests = failedTests + 1;
        failedList{end+1} = 'Day 4: AllChannels vs GreenOnly';
    end

    %% ========================================
    %% INTEGRATION TEST
    %% ========================================
    fprintf('\n============================================\n');
    fprintf('         INTEGRATION TEST                   \n');
    fprintf('============================================\n\n');

    % Test INT.1: Full pipeline (Day 1 -> Day 2 -> Day 3 -> Day 4)
    totalTests = totalTests + 1;
    fprintf('--- Test INT.1: Full Pipeline Integration ---\n');
    try
        % Day 1: Verify environment
        fprintf('  [1] Verifying environment...\n');
        % (Already verified above)

        % Day 2: Compute quality metrics
        fprintf('  [2] Computing quality metrics...\n');
        metrics = computeQualityMetrics(testImg);
        
        % Day 3: Assess quality
        fprintf('  [3] Assessing quality...\n');
        config = defaultQualityConfig();
        [result, ~] = assessImageQuality(testImg, 'Config', config);
        
        % Day 4: Enhance image
        fprintf('  [4] Enhancing image...\n');
        [enhanced, qualityImprovement] = enhanceImage(testImg);
        
        % Verify pipeline
        fprintf('  Pipeline completed successfully!\n');
        fprintf('  Quality status: %s\n', result.overall);
        fprintf('  Enhancement score: %.4f\n', qualityImprovement.overallScore);
        passedTests = passedTests + 1;
    catch e
        fprintf('[FAIL] Full pipeline integration failed: %s\n', e.message);
        failedTests = failedTests + 1;
        failedList{end+1} = 'Integration: Full Pipeline';
    end

    % Test INT.2: Quality gate filtering
    totalTests = totalTests + 1;
    fprintf('\n--- Test INT.2: Quality Gate Filtering ---\n');
    try
        % Test with multiple images
        data = readtable(fullfile(project_root, 'data', 'aptos2019', 'train.csv'));
        rng(42);
        numTest = min(20, height(data));
        sampleIdx = randperm(height(data), numTest);
        
        passCount = 0;
        warnCount = 0;
        failCount = 0;
        
        for i = 1:numTest
            idx = sampleIdx(i);
            imgName = data.id_code{idx};
            imgPath = fullfile(trainDir, [imgName '.png']);
            
            if exist(imgPath, 'file')
                img = imread(imgPath);
                [result, ~] = assessImageQuality(img, 'Config', config);
                
                switch result.overall
                    case 'PASS'
                        passCount = passCount + 1;
                    case 'WARNING'
                        warnCount = warnCount + 1;
                    case 'FAIL'
                        failCount = failCount + 1;
                end
            end
        end
        
        fprintf('[PASS] Quality gate filtering works\n');
        fprintf('  Tested: %d images\n', numTest);
        fprintf('  PASS: %d, WARNING: %d, FAIL: %d\n', passCount, warnCount, failCount);
        passedTests = passedTests + 1;
    catch e
        fprintf('[FAIL] Quality gate filtering failed: %s\n', e.message);
        failedTests = failedTests + 1;
        failedList{end+1} = 'Integration: Quality Gate';
    end

    % Test INT.3: Enhancement on quality-passed images
    totalTests = totalTests + 1;
    fprintf('\n--- Test INT.3: Enhancement on Quality-Passed Images ---\n');
    try
        enhancedCount = 0;
        improvedCount = 0;
        
        for i = 1:numTest
            idx = sampleIdx(i);
            imgName = data.id_code{idx};
            imgPath = fullfile(trainDir, [imgName '.png']);
            
            if exist(imgPath, 'file')
                img = imread(imgPath);
                [result, ~] = assessImageQuality(img, 'Config', config);
                
                if strcmp(result.overall, 'PASS')
                    [enhanced, qualityImprovement] = enhanceImage(img);
                    enhancedCount = enhancedCount + 1;
                    
                    if qualityImprovement.overallScore > 0
                        improvedCount = improvedCount + 1;
                    end
                end
            end
        end
        
        fprintf('[PASS] Enhancement on quality-passed images works\n');
        fprintf('  Enhanced: %d images\n', enhancedCount);
        fprintf('  Improved: %d images (%.1f%%)\n', improvedCount, improvedCount/enhancedCount*100);
        passedTests = passedTests + 1;
    catch e
        fprintf('[FAIL] Enhancement on quality-passed images failed: %s\n', e.message);
        failedTests = failedTests + 1;
        failedList{end+1} = 'Integration: Enhancement on Passed';
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
        fprintf('Ready for Day 5 (Classifier Setup)\n');
    else
        fprintf('         SOME TESTS FAILED                  \n');
        fprintf('============================================\n\n');
        fprintf('System Status: NEEDS ATTENTION\n');
        fprintf('Please fix failed tests before proceeding\n');
    end
end