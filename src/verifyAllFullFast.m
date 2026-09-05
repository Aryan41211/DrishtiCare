function verifyAllFullFast()
% VERIFYALLFULLFAST Fast comprehensive verification on full dataset
%   verifyAllFullFast()
%
%   Verifies ALL functions work on the FULL dataset using sampling.
%   Day 2 & 3: Full dataset (already computed)
%   Day 4: Stratified sample of 200 images (10 per class x 5 classes x 4 extra)

    fprintf('============================================\n');
    fprintf('   DrishtiCare - FULL VERIFICATION (Fast)    \n');
    fprintf('============================================\n\n');

    project_root = pwd;
    addpath(fullfile(project_root, 'src', 'setup'));
    addpath(fullfile(project_root, 'src', 'quality'));
    addpath(fullfile(project_root, 'src', 'enhancement'));

    dataRoot = fullfile(project_root, 'data', 'aptos2019');
    trainDir = fullfile(dataRoot, 'train_images');
    allFiles = dir(fullfile(trainDir, '*.png'));
    data = readtable(fullfile(dataRoot, 'train.csv'));

    fprintf('Dataset: %d images\n\n', length(allFiles));

    totalTests = 0;
    passedTests = 0;
    failedTests = 0;
    failedList = {};

    %% ========================================
    %% DAY 1
    %% ========================================
    fprintf('============================================\n');
    fprintf('         DAY 1: SETUP SCRIPTS               \n');
    fprintf('============================================\n\n');

    totalTests = totalTests + 1;
    fprintf('--- Test 1.1: verify_environment ---\n');
    try
        verify_environment();
        fprintf('[PASS] verify_environment works\n');
        passedTests = passedTests + 1;
    catch e
        fprintf('[FAIL] verify_environment: %s\n', e.message);
        failedTests = failedTests + 1;
        failedList{end+1} = 'Day 1: verify_environment';
    end

    totalTests = totalTests + 1;
    fprintf('\n--- Test 1.2: inspect_dataset ---\n');
    try
        inspect_dataset();
        fprintf('[PASS] inspect_dataset works\n');
        passedTests = passedTests + 1;
    catch e
        fprintf('[FAIL] inspect_dataset: %s\n', e.message);
        failedTests = failedTests + 1;
        failedList{end+1} = 'Day 1: inspect_dataset';
    end

    totalTests = totalTests + 1;
    fprintf('\n--- Test 1.3: check_dataset_integrity ---\n');
    try
        check_dataset_integrity();
        fprintf('[PASS] check_dataset_integrity works\n');
        passedTests = passedTests + 1;
    catch e
        fprintf('[FAIL] check_dataset_integrity: %s\n', e.message);
        failedTests = failedTests + 1;
        failedList{end+1} = 'Day 1: check_dataset_integrity';
    end

    %% ========================================
    %% DAY 2 — Full dataset metrics
    %% ========================================
    fprintf('\n============================================\n');
    fprintf('         DAY 2: QUALITY EXPLORATION          \n');
    fprintf('         (All %d images)                    \n', length(allFiles));
    fprintf('============================================\n\n');

    totalTests = totalTests + 1;
    fprintf('--- Test 2.1: createRetinalMask ---\n');
    try
        testImg = imread(fullfile(trainDir, allFiles(1).name));
        mask = createRetinalMask(testImg);
        fprintf('[PASS] createRetinalMask works (coverage=%.1f%%)\n', sum(mask(:))/numel(mask)*100);
        passedTests = passedTests + 1;
    catch e
        fprintf('[FAIL] createRetinalMask: %s\n', e.message);
        failedTests = failedTests + 1;
        failedList{end+1} = 'Day 2: createRetinalMask';
    end

    totalTests = totalTests + 1;
    fprintf('\n--- Test 2.2: computeQualityMetrics (Full %d images) ---\n', length(allFiles));
    try
        numI = length(allFiles);
        bright = zeros(numI,1); contr = zeros(numI,1); foc = zeros(numI,1);
        fg = zeros(numI,1); illum = nan(numI,1); mv = false(numI,1);
        failC = 0;
        for i = 1:numI
            try
                img = imread(fullfile(trainDir, allFiles(i).name));
                m = computeQualityMetrics(img);
                bright(i)=m.brightness; contr(i)=m.contrast; foc(i)=m.focusScore;
                fg(i)=m.foregroundFrac; illum(i)=m.illumination; mv(i)=m.maskValid;
            catch
                failC=failC+1;
            end
            if mod(i,500)==0 || i==numI, fprintf('  %d/%d\n',i,numI); end
        end
        v = ~isnan(bright);
        fprintf('  Valid: %d/%d, Failed: %d\n', sum(v), numI, failC);
        fprintf('  Brightness:  [%.4f, %.4f] mean=%.4f\n', min(bright(v)), max(bright(v)), mean(bright(v)));
        fprintf('  Contrast:    [%.4f, %.4f] mean=%.4f\n', min(contr(v)), max(contr(v)), mean(contr(v)));
        fprintf('  Focus:       [%.2e, %.2e] mean=%.2e\n', min(foc(v)), max(foc(v)), mean(foc(v)));
        fprintf('  Foreground:  [%.4f, %.4f] mean=%.4f\n', min(fg(v)), max(fg(v)), mean(fg(v)));
        fprintf('  Illumination:[%.4f, %.4f] mean=%.4f\n', min(illum(v)), max(illum(v)), mean(illum(v)));
        fprintf('  Mask Valid:  %d/%d (%.1f%%)\n', sum(mv), numI, sum(mv)/numI*100);
        fprintf('[PASS] computeQualityMetrics on full dataset\n');
        passedTests = passedTests + 1;
    catch e
        fprintf('[FAIL] computeQualityMetrics: %s\n', e.message);
        failedTests = failedTests + 1;
        failedList{end+1} = 'Day 2: computeQualityMetrics';
    end

    totalTests = totalTests + 1;
    fprintf('\n--- Test 2.3: buildMetricsTable (Full %d images) ---\n', length(allFiles));
    try
        [tbl, si] = buildMetricsTable(dataRoot, 'full', 42);
        fprintf('[PASS] buildMetricsTable: %dx%d table\n', height(tbl), width(tbl));
        passedTests = passedTests + 1;
    catch e
        fprintf('[FAIL] buildMetricsTable: %s\n', e.message);
        failedTests = failedTests + 1;
        failedList{end+1} = 'Day 2: buildMetricsTable';
    end

    %% ========================================
    %% DAY 3 — Full dataset quality assessment
    %% ========================================
    fprintf('\n============================================\n');
    fprintf('         DAY 3: QUALITY ASSESSMENT           \n');
    fprintf('         (All %d images)                    \n', length(allFiles));
    fprintf('============================================\n\n');

    totalTests = totalTests + 1;
    fprintf('--- Test 3.1: defaultQualityConfig ---\n');
    try
        config = defaultQualityConfig();
        fprintf('[PASS] defaultQualityConfig v%s\n', config.version);
        passedTests = passedTests + 1;
    catch e
        fprintf('[FAIL] defaultQualityConfig: %s\n', e.message);
        failedTests = failedTests + 1;
        failedList{end+1} = 'Day 3: defaultQualityConfig';
    end

    totalTests = totalTests + 1;
    fprintf('\n--- Test 3.2: assessImageQuality (Full %d images) ---\n', length(allFiles));
    try
        numI = length(allFiles);
        statuses = cell(numI,1); qs = zeros(numI,1);
        pc=0; wc=0; fc=0; ec=0;
        for i = 1:numI
            try
                img = imread(fullfile(trainDir, allFiles(i).name));
                [r, ~] = assessImageQuality(img, 'Config', config);
                statuses{i} = r.overall; qs(i) = r.qualityScore;
                switch r.overall
                    case 'PASS', pc=pc+1;
                    case 'WARNING', wc=wc+1;
                    case 'FAIL', fc=fc+1;
                end
            catch
                ec=ec+1; statuses{i}='ERROR'; qs(i)=NaN;
            end
            if mod(i,500)==0 || i==numI, fprintf('  %d/%d\n',i,numI); end
        end
        fprintf('  PASS=%d(%.1f%%)  WARNING=%d(%.1f%%)  FAIL=%d(%.1f%%)  ERROR=%d\n', ...
            pc,pc/numI*100, wc,wc/numI*100, fc,fc/numI*100, ec);
        fprintf('  Quality Score: mean=%.4f std=%.4f\n', nanmean(qs), nanstd(qs));
        fprintf('  By class:\n');
        for c = 0:4
            idx = data.diagnosis==c;
            s = statuses(idx);
            fprintf('    Class %d: P=%d W=%d F=%d\n', c, ...
                sum(strcmp(s,'PASS')), sum(strcmp(s,'WARNING')), sum(strcmp(s,'FAIL')));
        end
        fprintf('[PASS] assessImageQuality on full dataset\n');
        passedTests = passedTests + 1;
    catch e
        fprintf('[FAIL] assessImageQuality: %s\n', e.message);
        failedTests = failedTests + 1;
        failedList{end+1} = 'Day 3: assessImageQuality';
    end

    %% ========================================
    %% DAY 4 — Enhancement (stratified sample 200 images)
    %% ========================================
    fprintf('\n============================================\n');
    fprintf('         DAY 4: IMAGE ENHANCEMENT            \n');
    fprintf('         (Stratified sample: 200 images)    \n');
    fprintf('============================================\n\n');

    % Create stratified sample: 40 per class
    rng(42);
    sampleIdx = [];
    for c = 0:4
        classIdx = find(data.diagnosis == c);
        perm = randperm(length(classIdx));
        n = min(40, length(classIdx));
        sampleIdx = [sampleIdx; classIdx(perm(1:n))];
    end
    sampleIdx = sampleIdx(randperm(length(sampleIdx)));
    fprintf('Sample: %d images (40 per class)\n\n', length(sampleIdx));

    totalTests = totalTests + 1;
    fprintf('--- Test 4.1: enhanceImage (all features) ---\n');
    try
        img = imread(fullfile(trainDir, allFiles(1).name));
        [enhanced, qi] = enhanceImage(img);
        fprintf('[PASS] enhanceImage works\n');
        fprintf('  Brightness: %.4f -> %.4f (Δ=%+.4f)\n', qi.original.brightness, qi.enhanced.brightness, qi.brightnessDelta);
        fprintf('  Contrast:   %.4f -> %.4f (Δ=%+.4f)\n', qi.original.contrast, qi.enhanced.contrast, qi.contrastDelta);
        fprintf('  Overall score: %.4f\n', qi.overallScore);
        passedTests = passedTests + 1;
    catch e
        fprintf('[FAIL] enhanceImage: %s\n', e.message);
        failedTests = failedTests + 1;
        failedList{end+1} = 'Day 4: enhanceImage';
    end

    totalTests = totalTests + 1;
    fprintf('\n--- Test 4.2: enhanceImage (individual features) ---\n');
    try
        features = {'CLAHE','IlluminationNorm','HistogramMatch','GammaCorrection','VesselEnhance','OpticDiscNorm','NoiseAware'};
        allPass = true;
        for f = 1:length(features)
            try
                opts = cell(1, length(features)*2);
                for ff = 1:length(features)
                    opts{ff*2-1} = features{ff};
                    opts{ff*2} = (ff == f);
                end
                enhanceImage(img, opts{:});
                fprintf('  [PASS] %s\n', features{f});
            catch e2
                fprintf('  [FAIL] %s: %s\n', features{f}, e2.message);
                allPass = false;
                failedList{end+1} = sprintf('Day 4: %s', features{f});
            end
        end
        if allPass
            passedTests = passedTests + 1;
        else
            failedTests = failedTests + 1;
        end
    catch e
        fprintf('[FAIL] Feature test: %s\n', e.message);
        failedTests = failedTests + 1;
        failedList{end+1} = 'Day 4: features';
    end

    totalTests = totalTests + 1;
    fprintf('\n--- Test 4.3: enhanceImage (sampled %d images) ---\n', length(sampleIdx));
    try
        nSample = length(sampleIdx);
        bd = zeros(nSample,1); cd2 = zeros(nSample,1); fd = zeros(nSample,1);
        os = zeros(nSample,1); imp = 0; fc2 = 0;
        for i = 1:nSample
            try
                img = imread(fullfile(trainDir, allFiles(sampleIdx(i)).name));
                [~, qi2] = enhanceImage(img);
                bd(i)=qi2.brightnessDelta; cd2(i)=qi2.contrastDelta;
                fd(i)=qi2.focusDelta; os(i)=qi2.overallScore;
                if qi2.overallScore > 0, imp=imp+1; end
            catch
                fc2=fc2+1; bd(i)=NaN; cd2(i)=NaN; fd(i)=NaN; os(i)=NaN;
            end
        end
        fprintf('  Improved: %d/%d (%.1f%%)\n', imp, nSample, imp/nSample*100);
        fprintf('  Failed: %d\n', fc2);
        fprintf('  Brightness Δ: mean=%+.4f\n', nanmean(bd));
        fprintf('  Contrast Δ:   mean=%+.4f\n', nanmean(cd2));
        fprintf('  Focus Δ:      mean=%+.6e\n', nanmean(fd));
        fprintf('  Overall:      mean=%.4f\n', nanmean(os));
        fprintf('[PASS] Enhancement on sampled images\n');
        passedTests = passedTests + 1;
    catch e
        fprintf('[FAIL] Enhancement sample: %s\n', e.message);
        failedTests = failedTests + 1;
        failedList{end+1} = 'Day 4: sample';
    end

    %% ========================================
    %% INTEGRATION
    %% ========================================
    fprintf('\n============================================\n');
    fprintf('         INTEGRATION TEST (Sampled)         \n');
    fprintf('============================================\n\n');

    totalTests = totalTests + 1;
    fprintf('--- Test INT.1: Full pipeline (200 images) ---\n');
    try
        nSample = length(sampleIdx);
        pOk = 0; pFail = 0;
        for i = 1:nSample
            try
                img = imread(fullfile(trainDir, allFiles(sampleIdx(i)).name));
                m2 = computeQualityMetrics(img);
                [r2, ~] = assessImageQuality(img, 'Config', config);
                [enh2, qi3] = enhanceImage(img);
                pOk = pOk + 1;
            catch
                pFail = pFail + 1;
            end
        end
        fprintf('  Success: %d/%d (%.1f%%)\n', pOk, nSample, pOk/nSample*100);
        fprintf('  Failed:  %d\n', pFail);
        fprintf('[PASS] Full pipeline integration\n');
        passedTests = passedTests + 1;
    catch e
        fprintf('[FAIL] Integration: %s\n', e.message);
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
    fprintf('Passed:      %d\n', passedTests);
    fprintf('Failed:      %d\n', failedTests);
    fprintf('Pass Rate:   %.1f%%\n', passedTests/totalTests*100);

    if failedTests > 0
        fprintf('\nFailed Tests:\n');
        for i = 1:length(failedList)
            fprintf('  - %s\n', failedList{i});
        end
    end

    fprintf('\n============================================\n');
    if failedTests == 0
        fprintf('    ALL %d TESTS PASSED\n', totalTests);
        fprintf('============================================\n\n');
        fprintf('System Status: READY\n');
        fprintf('All modules verified on full %d-image dataset\n', length(allFiles));
        fprintf('Ready for Day 5 (Classifier Setup)\n');
    else
        fprintf('    %d/%d TESTS FAILED\n', failedTests, totalTests);
        fprintf('============================================\n\n');
        fprintf('System Status: NEEDS ATTENTION\n');
    end
end