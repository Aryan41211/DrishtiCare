function D = load_dashboard_data()
%LOAD_DASHBOARD_DATA Load all screening-dashboard numbers from saved artifacts.
%   D = load_dashboard_data()
%
%   Assembles the day3 quality split, day7 champion metrics, the T3 ablation
%   table, Branch B eval numbers, and the val-split referable rate from the
%   committed .mat artifacts. Pure data access (no inference, no training);
%   used by DRScreeningDashboard and by the headless verify script.
%
%   Returns struct D with fields:
%     .quality (PASS/WARNING/FAIL counts + pct + n)
%     .qualityByGrade (classCounts + status split per grade)
%     .failureReasons (cell of {reason, count} rows, sorted desc)
%     .champion (day7 5-class metrics struct)
%     .championBinary (binary referable sens/spec/ppv/npv/tp/fp/fn/tn)
%     .ablation (table: config | acc | macroF1 | qwk | sens | spec | n)
%     .branchB (kind, T, evalAUC, matchRate)
%     .referable (trainFrac, valFrac, trainN, valN)
%     .inference (throughput img/s from day7 predictionTime, secondsPerImg)
%
%   ENGINEERING demo artifact loader. NOT a clinical device.

    projectRoot = pwd;
    dd = @(varargin) fullfile(projectRoot, 'data', varargin{:});

    D = struct();

    %% ---------------- Day 3 quality gate ----------------
    S = load(dd('analysis', 'day3', 'quality_assessment_summary.mat'));
    t = S.summary.resultsTable;
    n = height(t);
    st = upper(string(t.quality_status));
    q = struct();
    q.n = n;
    q.pass = nnz(st == "PASS");
    q.warning = nnz(st == "WARNING");
    q.fail = nnz(st == "FAIL");
    q.error = nnz(st == "ERROR");
    q.passPct = q.pass / n * 100;
    q.warningPct = q.warning / n * 100;
    q.failPct = q.fail / n * 100;
    q.totalTime = S.summary.totalTime;
    q.classCounts = S.summary.classCounts(:)';
    q.classNames = S.summary.classNames;
    D.quality = q;

    % Failure-reason breakdown (from the free-text column)
    reasons = containers.Map();
    for i = 1:n
        fr = strtrim(string(t.failure_reason{i}));
        if fr == "" || strcmpi(fr, "none") || strcmpi(fr, "NONE"), continue; end
        parts = strsplit(fr, ';');
        for k = 1:numel(parts)
            p = strtrim(parts(k));
            if p == "", continue; end
            if isKey(reasons, p), reasons(p) = reasons(p) + 1;
            else, reasons(p) = 1; end
        end
    end
    keys = reasons.keys;
    counts = cellfun(@(k) reasons(k), keys);
    [counts, si] = sort(counts, 'descend');
    keys = keys(si);
    rows = cell(numel(keys), 2);
    for i = 1:numel(keys)
        rows{i, 1} = keys{i};
        rows{i, 2} = counts(i);
    end
    D.failureReasons = rows;

    % Quality status split by grade (referable = grade >= 2)
    diag = t.diagnosis;
    statusMat = zeros(n, 3);  % columns: PASS WARNING FAIL counts per row
    statusMat(st == "PASS", 1) = 1;
    statusMat(st == "WARNING", 2) = 1;
    statusMat(st == "FAIL", 3) = 1;
    byGrade = zeros(5, 3);
    for g = 0:4
        m = diag == g;
        byGrade(g + 1, :) = sum(statusMat(m, :), 1);
    end
    D.qualityByGrade = byGrade;

    %% ---------------- Day 7 champion ----------------
    MC = load(dd('analysis', 'day7', 'eval_fixed_day7_pretrained_resnet18_5class_stage2.mat'));
    m = MC.m;
    champ = struct();
    champ.accuracy = m.accuracy;
    champ.macroF1 = m.macroF1;
    champ.qwk = m.qwk;
    champ.recall = m.recall(:)';
    champ.f1 = m.f1(:)';
    champ.support = m.support(:)';
    champ.classNames = m.classNames;
    champ.n = m.totalSamples;
    champ.predictionTime = m.predictionTime;
    champ.predDist = m.predictedDistribution(:)';
    champ.date = m.date;
    champ.binarySens = m.referable.sensitivity;
    champ.binarySpec = m.referable.specificity;
    champ.binaryPpv = m.referable.ppv;
    champ.binaryNpv = m.referable.npv;
    champ.binaryTp = m.referable.tp;
    champ.binaryFp = m.referable.fp;
    champ.binaryFn = m.referable.fn;
    champ.binaryTn = m.referable.tn;
    D.champion = champ;

    D.inference = struct();
    D.inference.secondsPerImg = champ.predictionTime / champ.n;
    D.inference.imgPerSec = champ.n / champ.predictionTime;
    D.inference.perDayEstimated = D.inference.imgPerSec * 8 * 3600 * 0.75;  % ~75% duty over 8h day

    %% ---------------- T3 ablation ----------------
    ablFile = { ...
        'eval_fixed_day5_resnet18_baseline_stage2.mat',  'day5 baseline (scratch, unbalanced)'; ...
        'eval_fixed_day6_resnet18_balanced_stage2.mat',  'day6 balanced (scratch)'; ...
        'eval_fixed_day7_pretrained_resnet18_5class_stage2.mat', 'day7 pretrained (champion)'};
    rows = cell(3, 7);
    for i = 1:size(ablFile, 1)
        Sa = load(dd('analysis', 'day7', ablFile{i, 1}));
        ma = Sa.m;
        CM = ma.confusionMatrix;
        tp = sum(diag(CM(2:5, 2:5)));
        fp = sum(sum(CM(1, 2:5)));
        fn = sum(sum(CM(2:5, 1)));
        tn = CM(1, 1);
        rows(i, :) = {ablFile{i, 2}, ma.accuracy, ma.macroF1, ma.qwk, ...
            tp / (tp + fn), tn / (tn + fp), ma.totalSamples};
    end
    D.ablation = cell2table(rows, 'VariableNames', ...
        {'config', 'acc', 'macroF1', 'qwk', 'sens', 'spec', 'n'});

    %% ---------------- Branch B ----------------
    try
        B = load(dd('analysis', 'day8', 'branch_b', 'branchB_model.mat'));
        bb = struct();
        bb.available = true;
        bb.kind = B.model.kind;
        bb.temperature = B.model.T;
        bb.evalAUC = B.model.metrics.aucBestEval;
        bb.matchRate = B.model.metrics.matchRateAll_eval;
        bb.nFit = B.model.metrics.nFit;
        bb.nEval = B.model.metrics.nEval;
    catch
        bb = struct('available', false);
    end
    D.branchB = bb;

    %% ---------------- Referable rates ----------------
    ref = struct();
    ref.trainN = sum(q.classCounts);
    ref.trainFrac = sum(q.classCounts(3:5)) / ref.trainN;
    tv = dir(dd('splits', 'val'));
    valN = 0; valRef = 0;
    for g = 0:4
        d = dir(dd('splits', 'val', sprintf('class_%d', g), '*.png'));
        valN = valN + numel(d);
        if g >= 2, valRef = valRef + numel(d); end
    end
    ref.valN = valN;
    ref.valRef = valRef;
    ref.valFrac = valRef / valN;
    D.referable = ref;
end