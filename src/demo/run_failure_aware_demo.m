function summary = run_failure_aware_demo(varargin)
% RUN_FAILURE_AWARE_DEMO Quality-gated, failure-aware DR screening demo
%   summary = run_failure_aware_demo()
%   summary = run_failure_aware_demo('Rescan', true)
%
%   Demonstrates the DrishtiCare "do not blindly predict from every image"
%   behaviour end to end, using ONLY existing project functions:
%
%       IMAGE
%         -> QUALITY CHECK   (assessImageQuality, Day-3 module)
%              PASS / WARNING -> AI screening (predictSingleFundus,
%                                SkipModelOnFail=true) -> grade -> referral
%              FAIL           -> STOP. AI grading is NOT executed here at all
%                                (quality-first short circuit). Reason, metric
%                                and threshold are reported; recapture /
%                                manual review is advised.
%
%   The harness is deliberately ordered quality-FIRST: for a FAIL image the
%   heavy inference entry point is never called, so the AI stage cannot run.
%   (predictSingleFundus carries its own SkipModelOnFail guard as defence in
%   depth; that guard is verified separately by the test suite.)
%
%   Outputs (data/analysis/failure_aware_demo/):
%       audit_log.csv                    - one auditable row per case
%       demo_results.mat                 - full result struct + provenance
%       run_log.txt                      - transcript
%       reports/generated_summary.md     - machine-generated summary
%       figures/failure_aware_comparison.png
%       figures/failure_aware_workflow.png
%       figures/quality_gate_summary.png
%
%   ENGINEERING demo. NOT a clinical device. No training, no weight changes,
%   no changes to thresholds or models.

    p = inputParser;
    addParameter(p, 'Rescan', false, @islogical);
    addParameter(p, 'OutDir', '', @ischar);
    parse(p, varargin{:});

    projectRoot = fileparts(fileparts(fileparts(mfilename('fullpath'))));
    thisDir = fullfile(projectRoot, 'src', 'demo');
    addpath(thisDir, ...
        fullfile(projectRoot, 'src', 'quality'), ...
        fullfile(projectRoot, 'src', 'inference'), ...
        fullfile(projectRoot, 'src', 'enhancement'), ...
        fullfile(projectRoot, 'src', 'explainability'), ...
        fullfile(projectRoot, 'src', 'grading'), ...
        fullfile(projectRoot, 'src', 'analysis', 'gradcam_alignment'));

    if isempty(p.Results.OutDir)
        outDir = fullfile(projectRoot, 'data', 'analysis', 'failure_aware_demo');
    else
        outDir = p.Results.OutDir;
    end
    figDir = fullfile(outDir, 'figures');
    repDir = fullfile(outDir, 'reports');
    if ~exist(outDir, 'dir'); mkdir(outDir); end
    if ~exist(figDir, 'dir'); mkdir(figDir); end
    if ~exist(repDir, 'dir'); mkdir(repDir); end

    logFile = fullfile(outDir, 'run_log.txt');
    fid = fopen(logFile, 'w');
    logmsg = @(varargin) log_and_print(fid, varargin{:});

    logmsg('==== DrishtiCare failure-aware demo ====\n');
    logmsg('started: %s\n', string(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss')));
    logmsg('projectRoot: %s\n', projectRoot);

    cfg = defaultQualityConfig();
    logmsg('quality config version: %s (%s)\n', cfg.version, cfg.validationStatus);

    %% Model provenance (read-only; must not change)
    modelDir = fullfile(projectRoot, 'data', 'models');
    binModel = fullfile(modelDir, 'day7_pretrained_resnet18_binary_stage2.mat');
    gradeModel = fullfile(modelDir, 'day7_pretrained_resnet18_5class_stage2.mat');
    hashBinBefore = sha256Hex(binModel);
    hashGradeBefore = sha256Hex(gradeModel);
    logmsg('binary model SHA-256: %s\n', hashBinBefore);
    logmsg('5-class model SHA-256: %s\n', hashGradeBefore);

    %% Case set
    caseFile = fullfile(outDir, 'demo_cases.csv');
    if ~exist(caseFile, 'file') || p.Results.Rescan
        select_demo_cases('Rescan', p.Results.Rescan);
    end
    cases = readtable(caseFile, 'TextType', 'char');
    logmsg('cases loaded: %d (%d available)\n', height(cases), sum(cases.available));

    valDir = fullfile(projectRoot, 'data', 'splits', 'val');

    %% Evaluate cases
    R = struct([]);
    audit = {};
    nInf = 0;
    for i = 1:height(cases)
        if ~cases.available(i)
            logmsg('SKIP (no natural example): %s\n', cases.id{i});
            continue;
        end
        imgPath = fullfile(valDir, cases.relPath{i});
        raw = imread(imgPath);
        [qres, m] = assessImageQuality(raw);
        det = quality_failure_detail(qres.checks, cfg);

        rec = blankRecord();
        rec.case_id = cases.id{i};
        rec.role = cases.role{i};
        rec.image_relpath = cases.relPath{i};
        rec.timestamp = string(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'));
        rec.quality_status = qres.overall;
        rec.quality_score = qres.qualityScore;
        if isempty(det)
            rec.quality_reason = '';
        else
            rec.quality_reason = strjoin({det.message}, ' | ');
        end
        rec.failure_categories = strjoin(qres.failureCategories, '|');
        rec.brightness = m.brightness;
        rec.contrast = m.contrast;
        rec.focus_score = m.focusScore;
        rec.foreground_frac = m.foregroundFrac;
        rec.illumination = m.illumination;
        rec.mask_valid = double(m.maskValid);
        rec.focus_status = checkStatus(qres, 'focus');
        rec.brightness_status = checkStatus(qres, 'brightness');
        rec.contrast_status = checkStatus(qres, 'contrast');
        rec.foreground_status = checkStatus(qres, 'foreground');
        rec.illumination_status = checkStatus(qres, 'illumination');
        rec.mask_valid_status = checkStatus(qres, 'maskValid');
        if ~isempty(det)
            % Headline metric = the one that DEFINES this demo case's role,
            % when it actually failed; otherwise the first failed check.
            wantMetric = roleDefiningMetric(cases.role{i});
            pick = 1;
            if ~isempty(wantMetric)
                for k = 1:numel(det)
                    if strcmp(det(k).metric, wantMetric), pick = k; break; end
                end
            end
            rec.primary_metric = det(pick).metric;
            rec.primary_value = det(pick).value;
            rec.primary_bound = det(pick).bound;
            rec.primary_threshold = det(pick).threshold;
            rec.primary_message = det(pick).message;
        end

        isFail = strcmp(qres.overall, 'FAIL');
        if isFail
            % QUALITY-FIRST: do NOT call the inference entry point at all.
            rec.inference_executed = false;
            rec.engine = 'quality-gate-skip (predictSingleFundus NOT called)';
            rec.grade = NaN;
            rec.grade_label = 'NOT ASSESSED (quality FAIL)';
            rec.confidence = NaN;
            rec.referable_probability = NaN;
            rec.binary_decision = 'WITHHELD (quality FAIL - not assessed)';
            rec.referral_decision = 'WITHHELD';
            rec.cascade_route = 'REVIEW';
            rec.gradcam_available = false;
            rec.runtime_sec = NaN;
            rec.note = ['AI grading skipped. Reason: ' rec.quality_reason];
            logmsg('FAIL  %-22s -> AI GRADING SKIPPED (%s)\n', rec.case_id, rec.quality_reason);
        else
            t0 = tic;
            r = predictSingleFundus(imgPath, 'SkipModelOnFail', true, 'ShowFigure', false);
            rec.runtime_sec = toc(t0);
            nInf = nInf + 1;
            rec.inference_executed = true;
            rec.engine = 'predictSingleFundus (SkipModelOnFail=true)';
            rec.grade = r.grade;
            rec.grade_label = r.gradeLabel;
            rec.confidence = r.confidence;
            rec.referable_probability = r.binaryProbability;
            rec.binary_decision = r.binaryDecision;
            if strcmp(r.binaryDecision, 'REFERABLE')
                rec.referral_decision = 'REFERABLE';
            else
                rec.referral_decision = 'NON-REFERABLE';
            end
            rec.cascade_route = r.cascade.route;
            rec.gradcam_available = ~isempty(r.gradCAM);
            rec.gradcam_overlay = r.gradCAM;
            rec.explanation = r.explanation.paragraph;
            rec.note = sprintf('quality %s (score %.2f); grade %d (%s)', ...
                qres.overall, qres.qualityScore, r.grade, r.gradeLabel);
            logmsg('%-5s %-22s -> grade %d %-14s P(ref)=%.3f -> %s (route %s, %.1fs)\n', ...
                qres.overall, rec.case_id, r.grade, r.gradeLabel, ...
                r.binaryProbability, r.binaryDecision, rec.cascade_route, rec.runtime_sec);
        end

        if isempty(R)
            R = rec;
        else
            R(end+1) = rec; %#ok<AGROW>
        end
        audit(end+1, :) = recordToRow(rec); %#ok<AGROW>
    end

    logmsg('inference executed on %d of %d available cases.\n', nInf, sum(cases.available));

    %% Audit log
    auditT = cell2table(audit, 'VariableNames', recordColumns());
    auditPath = fullfile(outDir, 'audit_log.csv');
    writetable(auditT, auditPath);
    logmsg('audit log -> %s\n', auditPath);

    %% Model provenance after (must be identical)
    hashBinAfter = sha256Hex(binModel);
    hashGradeAfter = sha256Hex(gradeModel);
    modelsUnchanged = strcmp(hashBinBefore, hashBinAfter) && strcmp(hashGradeBefore, hashGradeAfter);
    logmsg('models unchanged: %d\n', modelsUnchanged);

    %% Quality scan summary
    scanFile = fullfile(outDir, 'quality_scan.csv');
    if exist(scanFile, 'file')
        Tscan = readtable(scanFile, 'TextType', 'char');
        scanSummary = summarizeScan(Tscan);
    else
        scanSummary = struct();
    end

    %% Figures
    render_comparison_figure(R, fullfile(figDir, 'failure_aware_comparison.png'));
    render_workflow_figure(fullfile(figDir, 'failure_aware_workflow.png'));
    if ~isempty(fieldnames(scanSummary))
        render_scan_summary_figure(Tscan, scanSummary, fullfile(figDir, 'quality_gate_summary.png'));
    end
    logmsg('figures written to %s\n', figDir);

    %% Save results bundle
    summary = struct();
    summary.generatedAt = string(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'));
    summary.configVersion = cfg.version;
    summary.configValidationStatus = cfg.validationStatus;
    summary.thresholds = cfg.thresholds;
    summary.cases = cases;
    summary.results = R;
    summary.modelHashes = struct('binary', hashBinBefore, 'grade5', hashGradeBefore);
    summary.modelsUnchanged = modelsUnchanged;
    summary.inferenceExecutedCount = nInf;
    summary.availableCases = sum(cases.available);
    summary.scanSummary = scanSummary;
    outMat = fullfile(outDir, 'demo_results.mat');
    save(outMat, '-struct', 'summary');
    logmsg('results -> %s\n', outMat);

    %% Machine-generated summary report
    write_generated_summary(summary, fullfile(repDir, 'generated_summary.md'));

    logmsg('done: %s\n', string(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss')));
    logmsg('==== end ====\n');
    fclose(fid);

    fprintf('\nFailure-aware demo complete. Files under: %s\n', outDir);
end

% ========================================================================
function write_generated_summary(s, path)
    fid = fopen(path, 'w');
    fprintf(fid, '# Failure-aware demo - generated summary\n\n');
    fprintf(fid, 'Generated: %s\n\n', s.generatedAt);
    fprintf(fid, '- Quality config: `%s` (%s)\n', s.configVersion, s.configValidationStatus);
    fprintf(fid, '- Cases available: %d\n', s.availableCases);
    fprintf(fid, '- Cases that reached AI inference: %d\n', s.inferenceExecutedCount);
    fprintf(fid, '- Models unchanged during run: %d\n', s.modelsUnchanged);
    fprintf(fid, '- Binary model SHA-256: `%s`\n', s.modelHashes.binary);
    fprintf(fid, '- 5-class model SHA-256: `%s`\n\n', s.modelHashes.grade5);

    if isfield(s.scanSummary, 'total')
        fprintf(fid, '## Held-out val scan (%d images)\n\n', s.scanSummary.total);
        fprintf(fid, '| overall | count |\n|---|---|\n');
        fprintf(fid, '| PASS | %d |\n| WARNING | %d |\n| FAIL | %d |\n\n', ...
            s.scanSummary.nPass, s.scanSummary.nWarn, s.scanSummary.nFail);
        cats = s.scanSummary.categories;
        if ~isempty(cats)
            fprintf(fid, '### FAIL categories\n\n| category | count |\n|---|---|\n');
            for i = 1:size(cats, 1)
                fprintf(fid, '| %s | %d |\n', cats{i,1}, cats{i,2});
            end
            fprintf(fid, '\n');
        end
    end

    fprintf(fid, '## Per-case audit\n\n');
    fprintf(fid, '| case | role | quality | inference | grade | referral | route | reason |\n');
    fprintf(fid, '|---|---|---|---|---|---|---|---|\n');
    R = s.results;
    for i = 1:numel(R)
        if isfinite(R(i).grade)
            gradeStr = sprintf('%d (%s)', R(i).grade, R(i).grade_label);
        else
            gradeStr = 'not assessed';
        end
        fprintf(fid, '| %s | %s | %s | %s | %s | %s | %s | %s |\n', ...
            md(R(i).case_id), md(R(i).role), md(R(i).quality_status), ...
            string(R(i).inference_executed), md(gradeStr), md(R(i).referral_decision), ...
            md(R(i).cascade_route), md(R(i).quality_reason));
    end
    fclose(fid);
end

% ========================================================================
function rec = blankRecord()
    rec = struct( ...
        'case_id', '', 'role', '', 'image_relpath', '', 'timestamp', '', ...
        'quality_status', '', 'quality_score', NaN, 'quality_reason', '', ...
        'failure_categories', '', 'brightness', NaN, 'contrast', NaN, ...
        'focus_score', NaN, 'foreground_frac', NaN, 'illumination', NaN, ...
        'mask_valid', NaN, 'focus_status', '', 'brightness_status', '', ...
        'contrast_status', '', 'foreground_status', '', 'illumination_status', '', ...
        'mask_valid_status', '', 'primary_metric', '', 'primary_value', NaN, ...
        'primary_bound', '', 'primary_threshold', NaN, 'primary_message', '', ...
        'inference_executed', false, ...
        'engine', '', 'grade', NaN, 'grade_label', '', 'confidence', NaN, ...
        'referable_probability', NaN, 'binary_decision', '', 'referral_decision', '', ...
        'cascade_route', '', 'gradcam_available', false, 'runtime_sec', NaN, ...
        'note', '', 'gradcam_overlay', [], 'explanation', '');
end

function cols = recordColumns()
    rec = blankRecord();
    cols = fieldnames(rec)';
    cols = setdiff(cols, {'gradcam_overlay', 'explanation'}, 'stable');
end

function row = recordToRow(rec)
    cols = recordColumns();
    row = cell(1, numel(cols));
    for i = 1:numel(cols)
        v = rec.(cols{i});
        if isstring(v) || ischar(v)
            row{i} = char(v);
        elseif islogical(v)
            row{i} = double(v);
        else
            row{i} = v;
        end
    end
end

function m = roleDefiningMetric(role)
    switch role
        case 'fail_blur',         m = 'focus';
        case 'fail_dark',         m = 'brightness';
        case 'fail_bright',       m = 'brightness';
        case 'fail_fov',          m = 'foreground';
        case 'fail_contrast',     m = 'contrast';
        case 'fail_illumination', m = 'illumination';
        case 'warning',           m = 'illumination';
        otherwise,                m = '';
    end
end

function s = checkStatus(qres, metric)
    s = '';
    for k = 1:numel(qres.checks)
        if strcmp(qres.checks(k).metric, metric)
            s = qres.checks(k).status; return;
        end
    end
end

function ss = summarizeScan(T)
    ss = struct();
    ss.total = height(T);
    ss.nPass = sum(strcmp(T.overall, 'PASS'));
    ss.nWarn = sum(strcmp(T.overall, 'WARNING'));
    ss.nFail = sum(strcmp(T.overall, 'FAIL'));
    allCats = {};
    for i = 1:height(T)
        if ~isempty(T.failureCategories{i})
            parts = strsplit(T.failureCategories{i}, '|');
            allCats = [allCats, parts]; %#ok<AGROW>
        end
    end
    if isempty(allCats)
        ss.categories = {};
    else
        u = unique(allCats);
        counts = cell(numel(u), 2);
        for i = 1:numel(u)
            counts{i,1} = u{i};
            counts{i,2} = sum(strcmp(allCats, u{i}));
        end
        ss.categories = counts;
    end
end

function s = md(v)
    % Escape a value for use inside a Markdown table cell.
    s = char(string(v));
    s = strrep(s, '|', '/');
    s = strrep(s, newline, ' ');
end

function log_and_print(fid, fmt, varargin)
    fprintf(fid, fmt, varargin{:});
    fprintf(1, fmt, varargin{:});
end
