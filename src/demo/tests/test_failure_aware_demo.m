function test_failure_aware_demo()
% TEST_FAILURE_AWARE_DEMO Sanity contract for the failure-aware demo.
%   Runs a set of independent checks over the demo artifacts and the live
%   production entry point. Exits with an error if any check fails.
%
%   Usage (headless):
%       matlab -batch "addpath('src/demo/tests'); test_failure_aware_demo"
%
%   Checks (TEST 1-11):
%     1  PASS case reaches the AI stage and yields a valid grade
%     2  FAIL cases do NOT reach the AI stage
%     3  FAIL cases produce a clear reason (metric + value + threshold)
%     4  PASS cases produce a grade in 0..4
%     5  No NaN/Inf in quality metrics (with mask caveat)
%     6  Model files unchanged by the demo run
%     7  Locked model SHA-256 unchanged vs the baseline manifest
%     8  No model training anywhere in the demo/quality code
%     9  Official APTOS test set is never referenced (cannot be touched)
%     10 No FAIL case silently becomes a prediction
%     11 Defence in depth: the production entry point withholds on FAIL
%
%   ENGINEERING checks only. NOT a clinical validation suite.

    projectRoot = fileparts(fileparts(fileparts(fileparts(mfilename('fullpath')))));
    demoDir = fullfile(projectRoot, 'src', 'demo');
    qualityDir = fullfile(projectRoot, 'src', 'quality');
    addpath(demoDir, ...
        fullfile(projectRoot, 'src', 'quality'), ...
        fullfile(projectRoot, 'src', 'inference'), ...
        fullfile(projectRoot, 'src', 'enhancement'), ...
        fullfile(projectRoot, 'src', 'explainability'), ...
        fullfile(projectRoot, 'src', 'grading'), ...
        fullfile(projectRoot, 'src', 'analysis', 'gradcam_alignment'));

    outDir = fullfile(projectRoot, 'data', 'analysis', 'failure_aware_demo');
    matFile = fullfile(outDir, 'demo_results.mat');
    assert(exist(matFile, 'file') == 2, ...
        'demo_results.mat not found - run run_failure_aware_demo() first.');

    S = load(matFile);
    R = S.results;
    results = {};
    results{end+1} = t1_pass_reaches_ai(R);
    results{end+1} = t2_fail_skips_ai(R);
    results{end+1} = t3_fail_clear_reason(R);
    results{end+1} = t4_pass_valid_grade(R);
    results{end+1} = t5_no_nan_inf(R);
    results{end+1} = t6_models_unchanged(S);
    results{end+1} = t7_locked_hashes(S, projectRoot);
    results{end+1} = t8_no_training(demoDir, qualityDir);
    results{end+1} = t9_aptos_untouched(demoDir, qualityDir, projectRoot);
    results{end+1} = t10_no_silent_prediction(R);
    results{end+1} = t11_production_guard(projectRoot, R);

    nPass = sum(cellfun(@(r) r.pass, results));
    fprintf('\n----------------------------------------\n');
    fprintf('%d/%d checks passed\n', nPass, numel(results));
    fprintf('----------------------------------------\n');
    for i = 1:numel(results)
        if results{i}.pass
            fprintf('  [PASS] %s\n', results{i}.name);
        else
            fprintf('  [FAIL] %s :: %s\n', results{i}.name, results{i}.detail);
        end
    end
    if nPass ~= numel(results)
        error('test_failure_aware_demo: %d check(s) failed.', numel(results) - nPass);
    end
end

% ========================================================================
function r = rec(name, pass, detail)
    if nargin < 3, detail = ''; end
    r = struct('name', name, 'pass', logical(pass), 'detail', detail);
end

function idx = byRole(R, role)
    idx = find(strcmp({R.role}, role));
end

function tf = allFinite(v)
    tf = all(isfinite(v(:)));
end

% ---- TEST 1 ------------------------------------------------------------
function r = t1_pass_reaches_ai(R)
    idx = byRole(R, 'pass_referable');
    ok = ~isempty(idx) && R(idx).inference_executed && R(idx).grade >= 0 && R(idx).grade <= 4;
    if ok
        r = rec('TEST 1: PASS case reaches AI and yields a grade', true);
    else
        r = rec('TEST 1: PASS case reaches AI and yields a grade', false, ...
            'pass_referable did not execute inference or grade invalid');
    end
end

% ---- TEST 2 ------------------------------------------------------------
function r = t2_fail_skips_ai(R)
    failIdx = find(strcmp({R.quality_status}, 'FAIL'));
    bad = failIdx([R(failIdx).inference_executed]);
    r = rec('TEST 2: FAIL cases do NOT reach the AI stage', isempty(bad), ...
        sprintf('%d FAIL case(s) executed inference', numel(bad)));
end

% ---- TEST 3 ------------------------------------------------------------
function r = t3_fail_clear_reason(R)
    failIdx = find(strcmp({R.quality_status}, 'FAIL'));
    ok = true; msg = '';
    for i = failIdx
        hasMsg = ~isempty(R(i).primary_message) && ~isempty(R(i).primary_metric);
        hasVal = ~isnan(R(i).primary_value);
        rangeMetric = any(strcmp(R(i).primary_metric, ...
            {'focus','brightness','contrast','foreground','illumination'}));
        hasThr = ~rangeMetric || isfinite(R(i).primary_threshold);
        if ~(hasMsg && hasVal && hasThr)
            ok = false;
            msg = sprintf('case %s missing metric/value/threshold', R(i).case_id);
            break;
        end
    end
    if isempty(failIdx)
        r = rec('TEST 3: FAIL cases produce a clear reason', false, 'no FAIL cases in results');
    else
        r = rec('TEST 3: FAIL cases produce a clear reason', ok, msg);
    end
end

% ---- TEST 4 ------------------------------------------------------------
function r = t4_pass_valid_grade(R)
    ok = true; msg = '';
    for i = find(strcmp({R.quality_status}, 'PASS'))
        if ~(isfinite(R(i).grade) && R(i).grade >= 0 && R(i).grade <= 4)
            ok = false; msg = sprintf('case %s grade invalid', R(i).case_id); break;
        end
    end
    r = rec('TEST 4: PASS cases produce a grade in 0..4', ok, msg);
end

% ---- TEST 5 ------------------------------------------------------------
function r = t5_no_nan_inf(R)
    ok = true; msg = '';
    for i = 1:numel(R)
        v = [R(i).brightness R(i).contrast R(i).focus_score R(i).foreground_frac];
        if ~allFinite(v) || any(v < 0)
            ok = false; msg = sprintf('case %s has NaN/Inf/negative metric', R(i).case_id); break;
        end
        if R(i).mask_valid == 1 && ~isfinite(R(i).illumination)
            ok = false; msg = sprintf('case %s illumination NaN despite valid mask', R(i).case_id); break;
        end
    end
    r = rec('TEST 5: no NaN/Inf in quality metrics', ok, msg);
end

% ---- TEST 6 ------------------------------------------------------------
function r = t6_models_unchanged(S)
    ok = isfield(S, 'modelsUnchanged') && S.modelsUnchanged;
    r = rec('TEST 6: model files unchanged by the demo run', ok, ...
        'modelsUnchanged was false/missing');
end

% ---- TEST 7 ------------------------------------------------------------
function r = t7_locked_hashes(~, projectRoot)
    expectedBin = '43E8DF33B429231EE5BD60A775FDB3629AD81F287617AFAA9308EA87D311F9A0';
    expectedGrade = 'DD152C917689146F6DEC4687B263EC5E5F237ECF60EC719A59F9FCEEFF737C1B';
    modelDir = fullfile(projectRoot, 'data', 'models');
    hBin = sha256Hex(fullfile(modelDir, 'day7_pretrained_resnet18_binary_stage2.mat'));
    hGrade = sha256Hex(fullfile(modelDir, 'day7_pretrained_resnet18_5class_stage2.mat'));
    ok = strcmp(hBin, expectedBin) && strcmp(hGrade, expectedGrade);
    r = rec('TEST 7: locked model SHA-256 unchanged vs manifest', ok, ...
        sprintf('bin=%s grade=%s', hBin, hGrade));
end

% ---- TEST 8 ------------------------------------------------------------
function r = t8_no_training(demoDir, qualityDir)
    files = [ls(fullfile(demoDir, '*.m')); ...
             {fullfile(qualityDir, 'quality_failure_detail.m')}];
    pat = 'trainnetwork|trainingoptions|trainclassifier|trainregression|fitcecoc|fitcsvm|fitensemble|train\s*\(';
    ok = true; msg = '';
    for i = 1:numel(files)
        f = strtrim(files{i});
        if isempty(f), continue; end
        if exist(f, 'file') ~= 2, continue; end
        txt = lower(fileread(f));
        if ~isempty(regexp(txt, pat, 'once'))
            ok = false; msg = sprintf('training call found in %s', f); break;
        end
    end
    r = rec('TEST 8: no model training in demo/quality code', ok, msg);
end

% ---- TEST 9 ------------------------------------------------------------
function r = t9_aptos_untouched(demoDir, qualityDir, projectRoot)
    files = [ls(fullfile(demoDir, '*.m')); ...
             {fullfile(qualityDir, 'quality_failure_detail.m')}];
    badTokens = {'aptos2019', 'test_images', 'dr_testing_set'};
    ok = true; msg = '';
    for i = 1:numel(files)
        f = strtrim(files{i});
        if isempty(f) || exist(f, 'file') ~= 2, continue; end
        txt = lower(fileread(f));
        for t = 1:numel(badTokens)
            if contains(txt, badTokens{t})
                ok = false; msg = sprintf('%s references "%s"', f, badTokens{t}); break;
            end
        end
        if ~ok, break; end
    end
    % Informational: record the official test-set signature.
    testDir = fullfile(projectRoot, 'data', 'aptos2019', 'test_images');
    if exist(testDir, 'dir') == 7
        d = dir(fullfile(testDir, '*.png'));
        sigFile = fullfile(demoDir, 'tests', 'aptos_test_snapshot.txt');
        fid = fopen(sigFile, 'w');
        fprintf(fid, 'aptos2019/test_images: %d files, %d bytes total\n', ...
            numel(d), sum([d.bytes]));
        fclose(fid);
    end
    r = rec('TEST 9: official APTOS test set never referenced', ok, msg);
end

% ---- TEST 10 -----------------------------------------------------------
function r = t10_no_silent_prediction(R)
    ok = true; msg = '';
    for i = find(strcmp({R.quality_status}, 'FAIL'))
        cleanGrade = ~isfinite(R(i).grade);
        cleanConf = ~isfinite(R(i).confidence);
        cleanPref = ~isfinite(R(i).referable_probability);
        withheld = strncmp(R(i).binary_decision, 'WITHHELD', 8);
        if ~(cleanGrade && cleanConf && cleanPref && withheld)
            ok = false; msg = sprintf('case %s leaked a prediction', R(i).case_id); break;
        end
    end
    r = rec('TEST 10: no FAIL case becomes a silent prediction', ok, msg);
end

% ---- TEST 11 -----------------------------------------------------------
function r = t11_production_guard(projectRoot, R)
    idx = byRole(R, 'fail_blur');
    if isempty(idx), idx = find(strcmp({R.quality_status}, 'FAIL'), 1); end
    if isempty(idx)
        r = rec('TEST 11: production entry point withholds on FAIL', false, 'no FAIL case available');
        return;
    end
    imgPath = fullfile(projectRoot, 'data', 'splits', 'val', R(idx).image_relpath);
    try
        out = predictSingleFundus(imgPath, 'SkipModelOnFail', true, 'ShowFigure', false);
        ok = isnan(out.grade) && out.qualityGate.modelsSkipped && ...
             strcmp(out.cascade.route, 'REVIEW') && strncmp(out.binaryDecision, 'WITHHELD', 8);
        r = rec('TEST 11: production entry point withholds on FAIL', ok, ...
            sprintf('guard not honoured (grade=%g, modelsSkipped=%d)', ...
                out.grade, out.qualityGate.modelsSkipped));
    catch me
        r = rec('TEST 11: production entry point withholds on FAIL', false, me.message);
    end
end
