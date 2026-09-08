function results = runVesselExperiments(quick)
%RUNVESSEL EXPERIMENTS Controlled optimization of the classical vessel segmenter.
%   runVesselExperiments()            full run (20 dev + 20 test images)
%   runVesselExperiments(true)        smoke test on 2+2 images (for debugging)
%
%   Protocol (no test-set overfitting):
%     DEV  split = DRIVE training set (20 images, 21-40)  -> all tuning here.
%     TEST split = DRIVE test set    (20 images, 01-20)  -> the LOCKED champion
%                 configuration is evaluated exactly once at the end.
%
%   Round 1: preprocessing + enhancement + threshold + cleanup + ensemble
%            ablations on DEV only.
%   Round 2: a threshold/cleanup refinement sweep on DEV only, built around
%            the Round-1 champion.
%   Lock and evaluate the final champion ONCE on TEST.
%
%   Every experiment = a full CONFIG struct (see vesselParams.m) + metrics
%   + runtime. Nothing is tuned against individual test images.
%
%   IMPORTANT limitation: the previous pre-existing 0.743 baseline was tuned
%   partly on DRIVE *test* images in earlier sessions, so its reported test
%   score is "test-set tuning affected". New experiments are tuned on DEV and
%   locked before touching TEST.
%
%   Outputs (data\analysis\vessel\):
%     experiment_results.csv/.mat  - all experiment rows (dev + locked test)
%     vessel_ablation_table.csv    - named ablations for the report
%     best_vessel_montage.png      - 5 test images: Orig|GT|Baseline|Champ|Overlay
%     vessel_error_analysis.png    - 10 test images: Orig|GT|Base|Champ|FP|FN
%     champion_config.mat          - champion CONFIG (read by vesselParams)
%     metrics.txt                  - full report
%
%   This is a research prototype, NOT a clinically validated system.

%% ------------------------------ setup ------------------------------------
scriptDir = fileparts(mfilename('fullpath'));
addpath(scriptDir);
projRoot = 'C:\projects\DrishtiCare';
driveDir = fullfile(projRoot, 'data', 'drive', 'DRIVE');
outDir   = fullfile(projRoot, 'data', 'analysis', 'vessel');
if ~exist(outDir, 'dir'), mkdir(outDir); end

evalFovErode = 5;   % px, applied to BOTH prediction-scoring region and GT

%% ------------------------------ splits ------------------------------------
devAll  = makeSplit(fullfile(driveDir,'training'), 21);
testAll = makeSplit(fullfile(driveDir,'test'),    1);
if nargin < 1 || isempty(quick)
    quick = false;
end
if quick
    dev  = devAll(1:2);
    test = testAll(1:2);
else
    dev  = devAll;
    test = testAll;
end

%% --------------------------- round 1 experiments --------------------------
exps1 = defineExperiments();

% metric accumulator: [exp, metric]  metric order: dice f1 sens spec acc prec auc
dev1  = zeros(numel(exps1), 7);
dev1t = zeros(numel(exps1), 1);   % cumulative apply time per exp
pvTime = struct();                % cumulative bank build time per preproc
for im = 1:numel(dev)
    bank  = [];
    pvCur = '';
    for e = 1:numel(exps1)
        if isempty(bank) || ~strcmp(pvCur, exps1{e}.preproc)
            bank  = buildBank(dev(im), evalFovErode, exps1{e}.preproc);
            pvCur = exps1{e}.preproc;
            if isfield(pvTime, pvCur)
                pvTime.(pvCur) = pvTime.(pvCur) + bank.buildTime;
            else
                pvTime.(pvCur) = bank.buildTime;
            end
        end
        [m, ta] = applyExperiment(bank, exps1{e});
        dev1(e,:) = dev1(e,:) + m;
        dev1t(e)  = dev1t(e) + ta;
    end
end
dev1 = dev1 / numel(dev);
for e = 1:numel(exps1)
    exps1{e}.dice = dev1(e,1); exps1{e}.sens = dev1(e,3);
    exps1{e}.spec = dev1(e,4); exps1{e}.acc  = dev1(e,5);
    exps1{e}.prec = dev1(e,6); exps1{e}.auc  = dev1(e,7);
    exps1{e}.runtime = (dev1t(e) + pvTime.(exps1{e}.preproc)) / numel(dev);
end

[c1, ~] = pickChampion(exps1, dev1);
fprintf('ROUND-1 champion: %s  Dice=%.4f Sens=%.4f Spec=%.4f Acc=%.4f Prec=%.4f AUC=%.4f\n', ...
    c1.experiment, c1.dice, c1.sens, c1.spec, c1.acc, c1.prec, c1.auc);

%% --------------------------- round 2 (dev only) ---------------------------
exps2 = champSweeps(c1);
dev2  = zeros(numel(exps2), 7);
for im = 1:numel(dev)
    bank = buildBank(dev(im), evalFovErode, c1.preproc);
    for e = 1:numel(exps2)
        [m, ~] = applyExperiment(bank, exps2{e});
        dev2(e,:) = dev2(e,:) + m;
    end
end
dev2 = dev2 / numel(dev);
for e = 1:numel(exps2)
    exps2{e}.dice = dev2(e,1); exps2{e}.sens = dev2(e,3);
    exps2{e}.spec = dev2(e,4); exps2{e}.acc  = dev2(e,5);
    exps2{e}.prec = dev2(e,6); exps2{e}.auc  = dev2(e,7);
end
[c2, ~] = pickChampion(exps2, dev2);
fprintf('ROUND-2 champion: %s  Dice=%.4f Sens=%.4f Spec=%.4f Acc=%.4f Prec=%.4f AUC=%.4f\n', ...
    c2.experiment, c2.dice, c2.sens, c2.spec, c2.acc, c2.prec, c2.auc);

% Final champion = better of (round-1 champ, round-2 champ) on DEV
if c2.dice > c1.dice || (abs(c2.dice - c1.dice) < 1e-6 && c2.sens > c1.sens)
    champion = c2;
else
    champion = c1;
end
fprintf('FINAL DEV CHAMPION: %s  Dice=%.4f Sens=%.4f Spec=%.4f\n\n', ...
    champion.experiment, champion.dice, champion.sens, champion.spec);

%% --------------------------- locked TEST evaluation -----------------------
baseline = exps1{1};   % exp #1 = base_clahe (the 0.743 reproduction)
tBase = scoresTest(test, baseline, evalFovErode);
tChamp = scoresTest(test, champion, evalFovErode);
fprintf('LOCKED TEST  baseline: Dice=%.4f Sens=%.4f Spec=%.4f Acc=%.4f Prec=%.4f AUC=%.4f\n', ...
    tBase(1), tBase(3), tBase(4), tBase(5), tBase(6), tBase(7));
fprintf('LOCKED TEST  champion: Dice=%.4f Sens=%.4f Spec=%.4f Acc=%.4f Prec=%.4f AUC=%.4f\n', ...
    tChamp(1), tChamp(3), tChamp(4), tChamp(5), tChamp(6), tChamp(7));

% legacy (original) algorithm on dev + test, for the ablation table
legacyCfg  = vesselParams('legacy_broken');
legacyDev  = scoresLegacy(dev,  legacyCfg, evalFovErode);
legacyTest = scoresLegacy(test, legacyCfg, evalFovErode);

%% --------------------------- save artifacts --------------------------------
allExps = [exps1(:); exps2(:)];
meta.version = 'vessel-opt-round2';
meta.date    = datestr(now);
meta.protocol = 'DRIVE training (21-40) = DEV tuning; DRIVE test (01-20) = one locked evaluation';
meta.note    = '0.743 baseline was tuned partly on test in earlier sessions (test-set tuning limitation).';
meta.devScores   = [dev1; dev2];
meta.testBaseline = tBase;
meta.testChampion = tChamp;
meta.legacyDev    = legacyDev;
meta.legacyTest   = legacyTest;
meta.baselineExp  = baseline;
meta.championExp  = champion;

writeResultsCsv(fullfile(outDir,'experiment_results.csv'), allExps, meta);
writeResultsMat(fullfile(outDir,'experiment_results.mat'), allExps, meta);
writeAblationCsv(fullfile(outDir,'vessel_ablation_table.csv'), exps1, meta);
save(fullfile(outDir,'champion_config.mat'), 'champion');

makeMontages(test, baseline, champion, evalFovErode, outDir);
writeMetricsTxt(fullfile(outDir,'metrics.txt'), meta, exps1, exps2);

fprintf('\nSaved outputs to %s\n', outDir);
results = meta;

%% --------------------------- consistency check ----------------------------
verifyBankVsExtract(test, baseline, evalFovErode);

end

%% ============================ SPLITS =======================================

function S = makeSplit(rootDir, firstIdx)
%MAKESPLIT Build the image/mask/GT list for a DRIVE split.
    f = dir(fullfile(rootDir,'images','*.tif'));
    f = sort({f.name});
    n = numel(f);
    assert(n == 20, 'Expected 20 images in %s, found %d', rootDir, n);
    S = struct();
    for i = 1:n
        idx = firstIdx + i - 1;
        S(i).idx  = idx;
        S(i).img  = fullfile(rootDir,'images', f{i});
        S(i).fov  = fullfile(rootDir,'mask',   sprintf('%02d_test_mask.gif',       idx));
        S(i).m1   = fullfile(rootDir,'1st_manual', sprintf('%02d_manual1.gif',     idx));
        S(i).m2   = fullfile(rootDir,'2nd_manual', sprintf('%02d_manual2.gif',     idx));
        S(i).name = f{i};
    end
    % DRIVE test masks are _test_mask.gif, training are _training_mask.gif
    for i = 1:n
        if contains(S(i).fov, 'training')
            S(i).fov = fullfile(rootDir,'mask', sprintf('%02d_training_mask.gif', firstIdx+i-1));
        end
    end
end

%% ============================ BANK BUILDING ================================

function bank = buildBank(splitRec, erodePx, preproc)
%BUILDBANK Build the cached response bank for one image under a preprocessing.
    img = imread(splitRec.img);
    F   = imread(splitRec.fov ) > 0;
    G1  = imread(splitRec.m1  ) > 0;
    Fe  = imerode(F, strel('disk', erodePx));

    sImg = size(img);
    if numel(sImg) >= 3 && sImg(3) == 3
        g0 = im2double(img(:,:,2));        % green channel
    else
        g0 = im2double(img);
    end

    t0 = tic;
    g = prepGreen(g0, preproc);
    g = im2double(g);

    % multi-scale bottom-hat, individually cached
    bhKs = [1 2 3 4 5 6 7 8 10 12];
    bh = struct();
    for k = 1:numel(bhKs)
        bh.(sprintf('k%d', bhKs(k))) = single(imbothat(g, strel('disk', bhKs(k))));
    end

    % vessel map (current default scale set), normalized -> Frangi input
    vm = single(mat2gray( maxMorph(bh, [2 4 6 8]) ));

    % Frangi (fibermetric) at several thickness sets, input = vessel map
    fiberTs = {[1 2 3], [3 4 5], [2 3 4 5 6], [3 4 5 7 9 12], [2 4 6 8], [3 4 5 6 7], ...
           [1 2 3 4 5 6], [4 5 7 9]};
    fiber = struct();
    for k = 1:numel(fiberTs)
        key = sprintf('t_%s', regexprep(num2str(fiberTs{k}), '\s+', '_'));
        f   = fibermetric(double(vm), fiberTs{k}, 'ObjectPolarity', 'bright');
        fiber.(key) = single(mat2gray(f));
    end

    % matched filter on inverted green (vessels bright)
    gInv = single(1 - g);
    mfSigs = [1.0 1.5 2.0];
    mf = struct();
    for k = 1:numel(mfSigs)
        mf.(mfKey(mfSigs(k))) = ...
            single(matchedFilter(double(gInv), mfSigs(k), 0:15:165));
    end

    % line operator on inverted green
    lineLens = [9 13];
    line = struct();
    for k = 1:numel(lineLens)
        line.(sprintf('L%d', lineLens(k))) = ...
            single(lineOperator(double(gInv), lineLens(k), 0:15:165));
    end

    bank = struct();
    bank.preproc = preproc;
    bank.Fe  = Fe;
    bank.Fm  = Fe(:);
    bank.G1  = logical(G1(:));
    bank.G2  = [];
    if exist(splitRec.m2, 'file')
        bank.G2  = logical(imread(splitRec.m2) > 0);
    end
    bank.g0  = single(g0);
    bank.g   = single(g);
    bank.gInv = gInv;
    bank.bh  = bh;
    bank.vm  = vm;             % mat2gray morph-max over [2 4 6 8]
    bank.fiber = fiber;
    bank.mf  = mf;
    bank.line = line;
    bank.buildTime = toc(t0);
end

function g = prepGreen(g0, preproc)
%PREPGREEN Preprocessing variants (all operate on double green in [0,1]).
    switch preproc
        case 'green'
            g = g0;
        case 'clahe'
            g = im2double(adapthisteq(im2uint8(g0), 'NumTiles',[8 8], 'ClipLimit',0.02));
        case 'clahe_denoise'
            g = im2double(adapthisteq(im2uint8(imgaussfilt(g0,0.75)), ...
                'NumTiles',[8 8], 'ClipLimit',0.02));
        case 'clahe_norm'
            g = im2double(adapthisteq(im2uint8(g0), 'NumTiles',[8 8], 'ClipLimit',0.02));
            m  = largestConn(imbinarize(im2uint8(g0)));
            v  = g(m);
            lo = prctile(v,1); hi = prctile(v,99);
            g  = (g - lo) / max(hi - lo, eps);
            g  = im2double(mat2gray(g));
        otherwise
            error('runVesselExperiments:preproc', 'Unknown preproc ''%s''.', preproc);
    end
end

function m = largestConn(bw)
    cc = bwconncomp(bw, 4);
    if isempty(cc.PixelIdxList)
        m = false(size(bw));
        return;
    end
    np = cellfun(@numel, cc.PixelIdxList);
    [~, mi] = max(np);
    m = false(size(bw));
    m(cc.PixelIdxList{mi}) = true;
    m = imclose(m, strel('disk',5));
    m = imfill(m,'holes');
end

function M = maxMorph(bh, ks)
%MAXMORPH element-wise max of cached bottom-hat maps at the given radii.
    M = zeros(size(bh.k1), 'single');
    for k = 1:numel(ks)
        M = max(M, bh.(sprintf('k%d', ks(k))));
    end
end

%% ============================ RESPONSES ====================================

function [resp, used] = bankPipelines(bank, cfg)
%BANKPIPELINES Build the response map for a config from the cached bank.
    switch cfg.enhanceMode
        case 'bhonly'
            r = double(maxMorph(bank.bh, cfg.bhThickness));
            resp = mat2gray(r);
        case 'bhgate'
            r  = double(maxMorph(bank.bh, cfg.bhThickness));
            vm = mat2gray(r);
            gk = bankFiberKey(cfg.gateThickness);
            gate = double(bank.fiber.(gk));
            gate = mat2gray(gate);
            resp = vm .* (1 - cfg.gateWeight + cfg.gateWeight * gate);
            resp = mat2gray(resp);
        case 'fiber'
            gk = bankFiberKey(cfg.fiberThickness);
            resp = mat2gray(double(bank.fiber.(gk)));
        case 'mf'
            resp = mat2gray(double(bank.mf.(mfKey(cfg.mfSigma))));
        case 'line'
            resp = mat2gray(double(bank.line.(sprintf('L%d', cfg.lineLen))));
        case 'mix'
            % weighted sum of channels (each normalized)
            w = cfg.mixW;   % [morph(fiber-gated) fiber mf line] by default
            part = cell(1,4);
            r = double(maxMorph(bank.bh, cfg.bhThickness));
            vm = mat2gray(r);
            gk = bankFiberKey(cfg.gateThickness);
            gate = mat2gray(double(bank.fiber.(gk)));
            part{1} = vm .* (1 - cfg.gateWeight + cfg.gateWeight*gate);
            part{2} = mat2gray(double(bank.fiber.(bankFiberKey(cfg.chanfiber))));
            part{3} = mat2gray(double(bank.mf.(mfKey(cfg.chanmf))));
            part{4} = mat2gray(double(bank.line.(sprintf('L%d', cfg.chanline))));
            resp = zeros(size(part{1}));
            for k = 1:4
                resp = resp + w(k) * part{k};
            end
            resp = mat2gray(resp);
        otherwise
            error('runVesselExperiments:mode', 'Unknown enhanceMode %s', cfg.enhanceMode);
    end
    used = [];
end

function k = bankFiberKey(T)
    k = sprintf('t_%s', regexprep(num2str(T), '\s+', '_'));
end

function k = mfKey(sigma)
%MFKEY Valid struct-field key for a matched-filter sigma (no dots).
    k = sprintf('s%02d', round(10*sigma));
end

%% ============================ SCORING ======================================

function [m, tElapsed] = applyExperiment(bank, cfg)
%APPLYEXPERIMENT Full pipeline + metrics for one bank + config.
    t0 = tic;
    M    = applyBinary(bank, cfg);
    resp = bankPipelines(bank, cfg);
    tElapsed = toc(t0);
    m    = scoreBinary(M, bank, resp);
end

function M = applyBinary(bank, cfg)
%APPLYBINARY Full pipeline mask for one bank + config.
    resp = bankPipelines(bank, cfg);
    M    = thresholdResp(resp, bank, cfg);
    M    = cleanup(M, bank, cfg);
    M    = M & bank.Fe;
end

function M = thresholdResp(resp, bank, cfg)
%THRESHOLDRESP Threshold the response map.
    switch cfg.thresholdMethod
        case 'otsu'
            level = cfg.thresholdScale * graythresh(resp);
            M = resp > level;
        case 'percentile'
            t = prctile(resp(bank.Fm), 100*(1 - cfg.thresholdFrac));
            M = resp > t;
        case 'hysteresis'
            hi = resp > cfg.hysHi * graythresh(resp);
            lo = resp > cfg.hysLo * graythresh(resp);
            M  = imreconstruct(hi, lo);
        case 'adaptive'
            M = resp > adaptthresh(resp, cfg.adaptSensitivity);
        otherwise
            error('runVesselExperiments:thresh', 'Unknown thresholdMethod %s', cfg.thresholdMethod);
    end
end

function M = cleanup(M, bank, cfg)
%CLEANUP Morphological cleanup (noise removal WITHOUT removing thin vessels).
    M = bwmorph(M, 'clean');
    if cfg.lineLength > 0
        lo = false(size(M));
        for k = 1:numel(cfg.lineAngles)
            lo = lo | imopen(M, strel('line', cfg.lineLength, cfg.lineAngles(k)));
        end
        M = M & lo;
    end
    M = imclose(M, strel('disk', cfg.closeDisk));
    M = bwareaopen(M, cfg.minArea);
    if cfg.postDilate
        M = imdilate(M, strel('disk', 1));
    end
end

function m = scoreBinary(M, bank, resp)
%SCOREBINARY Dice/F1/Sens/Spec/Acc/Prec/AUC inside the eroded FOV.
    g  = bank.G1(bank.Fm);
    p  = M(bank.Fm);
    TP = sum(g & p); FP = sum(~g & p);
    FN = sum(g & ~p); TN = sum(~g & ~p);
    m(1) = 2*TP / max(2*TP+FP+FN, 1);   % dice
    m(2) = m(1);                        % f1 == dice for binary
    m(3) = TP / max(TP+FN, 1);          % sens
    m(4) = TN / max(TN+FP, 1);          % spec
    m(5) = (TP+TN) / max(TP+FN+FP+TN, 1); % acc
    m(6) = TP / max(TP+FP, 1);          % prec
    % AUC of raw response vs 1st manual inside FOV
    try
        [~,~,~,a] = perfcurve(double(bank.G1(bank.Fm)), resp(bank.Fm), true);
        m(7) = a;
    catch
        m(7) = NaN;
    end
end

function scores = scoresTest(split, cfg, erodePx)
%SCORESTEST Mean metrics for a config on a whole split (locked test path).
    scores = zeros(1,7);
    for i = 1:numel(split)
        bank = buildBank(split(i), erodePx, cfg.preproc);
        [m, ~] = applyExperiment(bank, cfg);
        scores = scores + m;
    end
    scores = scores / numel(split);
end

function scores = scoresLegacy(split, cfg, erodePx)
%SCORESLEGACY The ORIGINAL algorithm metrics (ablation).
    scores = zeros(1,7);
    for i = 1:numel(split)
        s  = split(i);
        img = imread(s.img);
        F   = imread(s.fov) > 0;
        G1  = imread(s.m1)  > 0;
        Fe  = imerode(F, strel('disk', erodePx));
        nom = legacyMap(img);
        cand = nom & Fe;
        m = zeros(1,7);
        m(1:6) = scoreVec(cand(Fe(:)), G1(Fe(:)));
        m(7) = NaN;
        scores = scores + m;
    end
    scores = scores / numel(split);
end

function m = scoreVec(p, g)
%SCOREVEC dice/f1/sens/spec/acc/prec given prediction and GT vectors.
    TP = sum(g & p); FP = sum(~g & p);
    FN = sum(g & ~p); TN = sum(~g & ~p);
    m(1) = 2*TP / max(2*TP+FP+FN, 1);
    m(2) = m(1);
    m(3) = TP / max(TP+FN, 1);
    m(4) = TN / max(TN+FP, 1);
    m(5) = (TP+TN) / max(TP+FN+FP+TN, 1);
    m(6) = TP / max(TP+FP, 1);
end

%% ============================ CHAMPION =====================================

function [c, idx] = pickChampion(exps, scores)
%PICKCHAMPION Selection rule: Dice (primary) -> Sens -> Prec -> Spec -> runtimeN/A
    cand = find(scores(:,1) >= 0.3 & scores(:,3) >= 0.3);
    if isempty(cand)
        error('runVesselExperiments:champ', 'No viable champion found.');
    end
    sc = scores(cand, :);
    [~, j] = sortrows([-sc(:,1), -sc(:,3), -sc(:,6), -sc(:,4)], [1 2 3 4]);
    idx = cand(j(1));
    c   = exps{idx};
end

%% ============================ FILTERS ======================================

function resp = matchedFilter(imgIn, sigma, oris)
%MATCHEDFILTER Chaudhuri-style matched filter: max over orientations of a
%mean-zero oriented Gaussian bar convolved with the image.
    resp = zeros(size(imgIn));
    W = max(3, round(2.5*sigma));   % half-width of the kernel footprint
    L = max(5, round(8*sigma));     % half-length along the vessel
    for th = oris
        [x, y] = meshgrid(-L:L, -W:W);
        costh = cosd(th); sinth = sind(th);
        xr =  x*costh + y*sinth;    % along-vessel coordinate
        yr = -x*sinth + y*costh;    % cross-vessel coordinate
        prof = exp(-(yr.^2) / (2*sigma^2));
        prof = prof .* (abs(xr) <= L);      % truncate along length
        K = prof - mean(prof(:));           % zero mean (Chaudhuri)
        r = filter2(rot90(K,2), imgIn, 'same');
        resp = max(resp, r);
    end
end

function resp = lineOperator(imgIn, len, oris)
%LINEOPERATOR Multi-orientation line response: max line-mean minus box mean.
    box = ones(2*len+1, 2*len+1, 'double') / (2*len+1)^2;
    boxmean = imfilter(imgIn, box, 'replicate');
    resp = zeros(size(imgIn));
    for th = oris
        se = strel('line', len, th);
        kern = double(getnhood(se)) / len;
        r = filter2(rot90(kern,2), imgIn, 'same');
        resp = max(resp, r);
    end
    resp = max(resp - boxmean, 0);
end

%% ============================ EXPERIMENTS ==================================

function exps = defineExperiments()
%BASEEXP default config identical to the current 0.743 baseline.
    function e = baseExp()
        e = struct();
        e.preproc          = 'clahe';
        e.enhanceMode      = 'bhgate';
        e.bhThickness      = [2 4 6 8];
        e.gateThickness    = [3 4 5];
        e.gatePolarity     = 'bright';
        e.gateWeight       = 0.4;
        e.fiberThickness   = [3 4 5];
        e.mfSigma          = 1.5;
        e.mfWeight         = 0.5;
        e.lineLen          = 9;
        e.lineWeight       = 0.5;
        e.mixCombine       = 'sum';
        e.mixW             = [1 0 0 0];
        e.chanfiber        = [3 4 5];
        e.chanmf           = 1.5;
        e.chanline         = 9;
        e.thresholdMethod  = 'otsu';
        e.thresholdScale   = 1.00;
        e.thresholdFrac    = 0.12;
        e.hysHi            = 1.00;
        e.hysLo            = 0.50;
        e.adaptSensitivity = 0.50;
        e.lineLength       = 9;
        e.lineAngles       = 0:30:150;
        e.closeDisk        = 2;
        e.minArea          = 40;
        e.postDilate       = 0;
        e.fovErodeRadius   = 15;
    end

    exps = {};
    function addE(name, cat, ov)
        e = baseExp();
        f = fieldnames(ov);
        for k = 1:numel(f), e.(f{k}) = ov.(f{k}); end
        e.experiment = name;
        e.category   = cat;
        exps{end+1} = e; %#ok<AGROW>
    end

    % ---- PREPROCESSING (round 1) -----------------------------------------
    addE('base_clahe',         'baseline', struct());
    addE('pre_green',          'preproc',  struct('preproc','green'));
    addE('pre_clahe_denoise',  'preproc',  struct('preproc','clahe_denoise'));
    addE('pre_clahe_norm',     'preproc',  struct('preproc','clahe_norm'));

    % ---- ENHANCEMENT & SCALES (round 1, preproc=clahe) --------------------
    addE('bh_only_k2468',      'enhance',  struct('enhanceMode','bhonly'));
    addE('bh_only_k1_12',      'enhance',  struct('enhanceMode','bhonly','bhThickness',[1 2 3 4 6 8 12]));
    addE('bh_only_k3456810',   'enhance',  struct('enhanceMode','bhonly','bhThickness',[3 4 5 6 8 10]));
    addE('bhgate_w06',         'enhance',  struct('gateWeight',0.6));
    addE('bhgate_w08',         'enhance',  struct('gateWeight',0.8));
    addE('bhgate_gate2468',    'enhance',  struct('gateThickness',[2 4 6 8]));
    addE('bhgate_gate34567',   'enhance',  struct('gateThickness',[3 4 5 6 7]));

    % ---- RESPONSE PRIMARY CHANNELS ----------------------------------------
    addE('fiber_prim_345',     'response', struct('enhanceMode','fiber','fiberThickness',[3 4 5]));
    addE('fiber_prim_123456',  'response', struct('enhanceMode','fiber','fiberThickness',[1 2 3 4 5 6]));
    addE('fiber_prim_4579',    'response', struct('enhanceMode','fiber','fiberThickness',[4 5 7 9]));
    addE('mf_sig15',           'response', struct('enhanceMode','mf','mfSigma',1.5));
    addE('mf_sig10',           'response', struct('enhanceMode','mf','mfSigma',1.0));
    addE('mf_sig20',           'response', struct('enhanceMode','mf','mfSigma',2.0));
    addE('line_L9',            'response', struct('enhanceMode','line','lineLen',9));
    addE('line_L13',           'response', struct('enhanceMode','line','lineLen',13));

    % ---- ENSEMBLES ---------------------------------------------------------
    addE('mix_morph_mf',       'ensemble', struct('enhanceMode','mix','mixW',[1 0 0.5 0]));
    addE('mix_morph_mf_line',  'ensemble', struct('enhanceMode','mix','mixW',[1 0 0.5 0.5]));
    addE('mix_all',            'ensemble', struct('enhanceMode','mix','mixW',[1 0.4 0.3 0.3]));
    addE('mix_all_nogate',     'ensemble', struct('enhanceMode','mix','gateWeight',0,'mixW',[1 0.4 0.3 0.3]));
    addE('mix_mf_fiber',       'ensemble', struct('enhanceMode','mix','mixW',[0 0.5 0.5 0]));

    % ---- THRESHOLDING (round 1, on base response) --------------------------
    addE('otsu_095',           'thresh',   struct('thresholdScale',0.95));
    addE('otsu_105',           'thresh',   struct('thresholdScale',1.05));
    addE('otsu_110',           'thresh',   struct('thresholdScale',1.10));
    addE('perc_10',            'thresh',   struct('thresholdMethod','percentile','thresholdFrac',0.10));
    addE('perc_12',            'thresh',   struct('thresholdMethod','percentile','thresholdFrac',0.12));
    addE('perc_15',            'thresh',   struct('thresholdMethod','percentile','thresholdFrac',0.15));
    addE('hys_100_50',         'thresh',   struct('thresholdMethod','hysteresis','hysHi',1.00,'hysLo',0.50));
    addE('hys_105_60',         'thresh',   struct('thresholdMethod','hysteresis','hysHi',1.05,'hysLo',0.60));
    addE('hys_110_70',         'thresh',   struct('thresholdMethod','hysteresis','hysHi',1.10,'hysLo',0.70));
    addE('hys_095_45',         'thresh',   struct('thresholdMethod','hysteresis','hysHi',0.95,'hysLo',0.45));
    addE('adapt_45',           'thresh',   struct('thresholdMethod','adaptive','adaptSensitivity',0.45));
    addE('adapt_55',           'thresh',   struct('thresholdMethod','adaptive','adaptSensitivity',0.55));

    % ---- CLEANUP (round 1, on base response) -------------------------------
    addE('lineLen7',           'cleanup',  struct('lineLength',7));
    addE('lineLen5',           'cleanup',  struct('lineLength',5));
    addE('lineLen11',          'cleanup',  struct('lineLength',11));
    addE('closeDisk1',         'cleanup',  struct('closeDisk',1));
    addE('minArea20',          'cleanup',  struct('minArea',20));
    addE('minArea60',          'cleanup',  struct('minArea',60));
    addE('angles15',           'cleanup',  struct('lineAngles',0:15:165));
    addE('postDilate1',        'cleanup',  struct('postDilate',1));
    addE('noLineOpen',         'cleanup',  struct('lineLength',0));
end

function exps = champSweeps(champ)
%CHAMPSWEEPS Round-2: threshold + cleanup refinement around the round-1 champ.
    c = champ;
    exps = {};
    function addE(name, ov)
        e = c; e.experiment = name; e.category = 'round2';
        f = fieldnames(ov);
        for k = 1:numel(f), e.(f{k}) = ov.(f{k}); end
        exps{end+1} = e; %#ok<AGROW>
    end
    for ts = [0.90 0.95 1.00 1.05 1.10]
        addE(sprintf('R2_otsu_%.2f', ts), struct('thresholdMethod','otsu','thresholdScale',ts));
    end
    for fr = [0.09 0.10 0.11 0.12 0.13 0.14]
        addE(sprintf('R2_perc_%.2f', fr), struct('thresholdMethod','percentile','thresholdFrac',fr));
    end
    for H = {[1.00 0.50],[1.05 0.60],[1.10 0.65],[1.00 0.60],[1.05 0.55],[0.95 0.50]}
        addE(sprintf('R2_hys_%g_%g', H{1}(1), H{1}(2)), ...
            struct('thresholdMethod','hysteresis','hysHi',H{1}(1),'hysLo',H{1}(2)));
    end
    for ll = [5 7 9 11]
        addE(sprintf('R2_lineLen%d', ll), struct('lineLength',ll));
    end
    for md = [20 40 60]
        addE(sprintf('R2_minArea%d', md), struct('minArea',md));
    end
    addE('R2_dilate1', struct('postDilate',1));
    addE('R2_angles15', struct('lineAngles',0:15:165));
    addE('R2_close1', struct('closeDisk',1));
end

%% ============================ WRITERS ======================================

function writeResultsCsv(fname, exps, meta)
%WRITERESULTSCSV Write every experiment row to CSV.
    fid = fopen(fname, 'w');
    fprintf(fid, 'experiment,category,split,n,dice,f1,sens,spec,acc,prec,auc,runtime_s,preproc,enhance,threshold,cleanup\n');
    for e = 1:numel(exps)
        x = exps{e};
        fprintf(fid, '%s,%s,%s,%d,%.4f,%.4f,%.4f,%.4f,%.4f,%.4f,%.4f,%.3f,%s,%s,%s,%s\n', ...
            x.experiment, x.category, 'dev', 20, ...
            x.dice, x.dice, x.sens, x.spec, x.acc, x.prec, x.auc, runtimeOf(x), ...
            x.preproc, enhanceStr(x), threshStr(x), cleanupStr(x));
    end
    % locked test rows
    td = meta.testBaseline; tc = meta.testChampion;
    fprintf(fid, '%s,%s,%s,%d,%.4f,%.4f,%.4f,%.4f,%.4f,%.4f,%.4f,%.3f,%s,%s,%s,%s\n', ...
        'TEST_LOCKED_baseline','baseline','test',20,td(1),td(1),td(3),td(4),td(5),td(6),td(7),runtimeOf(meta.baselineExp), ...
        meta.baselineExp.preproc, enhanceStr(meta.baselineExp), threshStr(meta.baselineExp), cleanupStr(meta.baselineExp));
    fprintf(fid, '%s,%s,%s,%d,%.4f,%.4f,%.4f,%.4f,%.4f,%.4f,%.4f,%.3f,%s,%s,%s,%s\n', ...
        'TEST_LOCKED_champion','champion','test',20,tc(1),tc(1),tc(3),tc(4),tc(5),tc(6),tc(7),runtimeOf(meta.championExp), ...
        meta.championExp.preproc, enhanceStr(meta.championExp), threshStr(meta.championExp), cleanupStr(meta.championExp));
    fclose(fid);
end

function r = runtimeOf(x)
    if isfield(x, 'runtime')
        r = x.runtime;
    else
        r = 0;
    end
end

function s = enhanceStr(x)
    switch x.enhanceMode
        case 'bhonly', s = sprintf('morph%s', vecStr(x.bhThickness));
        case 'bhgate', s = sprintf('morph%s*gate%s@%g', ...
                vecStr(x.bhThickness), vecStr(x.gateThickness), x.gateWeight);
        case 'fiber',  s = sprintf('fiber%s', vecStr(x.fiberThickness));
        case 'mf',     s = sprintf('mf_sig%g', x.mfSigma);
        case 'line',   s = sprintf('line_L%d', x.lineLen);
        case 'mix',    s = sprintf('mixW%s', vecStr(x.mixW));
    end
end
function s = threshStr(x)
    switch x.thresholdMethod
        case 'otsu',       s = sprintf('otsu*%.2f', x.thresholdScale);
        case 'percentile', s = sprintf('perc%.0f%%', 100*x.thresholdFrac);
        case 'hysteresis', s = sprintf('hys(%g/%g)', x.hysHi, x.hysLo);
        case 'adaptive',   s = sprintf('adapt%.2f', x.adaptSensitivity);
    end
end
function s = cleanupStr(x)
    s = sprintf('line%d,a%d,close%d,area%d,dil%d', ...
        x.lineLength, numel(x.lineAngles), x.closeDisk, x.minArea, x.postDilate);
end
function s = vecStr(v)
    s = strrep(mat2str(v), ' ', ';');
end

function writeResultsMat(fname, exps, meta)
    expsC = cell(numel(exps), 1);
    for k = 1:numel(exps), expsC{k} = exps(k); end
    save(fname, 'exps', 'expsC', 'meta', '-v7.3');
end

function writeAblationCsv(fname, exps, meta)
%WRITEABLATIONCSV Named ablations for the report table.
    want = {'legacy_broken','base_clahe','pre_green','bh_only_k2468','bhgate_w08', ...
            'fiber_prim_345','mf_sig15','line_L9','mix_all','hys_110_70','perc_12', ...
            'otsu_105','postDilate1'};
    fid = fopen(fname, 'w');
    fprintf(fid, 'method,dice,sens,spec,acc,prec,notes\n');
    % legacy (from its own evaluation)
    ld = meta.legacyDev; lt = meta.legacyTest;
    fprintf(fid, 'legacy_original_dev,%.4f,%.4f,%.4f,%.4f,%.4f,original src\\extractVessels algorithm (dev)\n', ...
        ld(1), ld(3), ld(4), ld(5), ld(6));
    fprintf(fid, 'legacy_original_test,%.4f,%.4f,%.4f,%.4f,%.4f,original src\\extractVessels algorithm (test)\n', ...
        lt(1), lt(3), lt(4), lt(5), lt(6));
    for k = 1:numel(exps)
        if any(strcmp(exps{k}.experiment, want))
            x = exps{k};
            fprintf(fid, '%s_dev,%.4f,%.4f,%.4f,%.4f,%.4f,round-1 dev\n', ...
                x.experiment, x.dice, x.sens, x.spec, x.acc, x.prec);
        end
    end
    td = meta.testBaseline; tc = meta.testChampion;
    fprintf(fid, 'baseline_0.743_test,%.4f,%.4f,%.4f,%.4f,%.4f,locked test (baseline reproduction)\n', ...
        td(1), td(3), td(4), td(5), td(6));
    fprintf(fid, 'champion_test,%.4f,%.4f,%.4f,%.4f,%.4f,locked test (final champion)\n', ...
        tc(1), tc(3), tc(4), tc(5), tc(6));
    fclose(fid);
end

function writeMetricsTxt(fname, meta, exps1, exps2)
    fid = fopen(fname, 'w');
    fprintf(fid, 'DrishtiCare - retinal vessel segmentation experiment report\n');
    fprintf(fid, 'Date: %s   (research prototype, not clinically validated)\n\n', meta.date);
    fprintf(fid, 'Protocol: %s\n', meta.protocol);
    fprintf(fid, 'NOTE: %s\n\n', meta.note);

    fprintf(fid, 'LEGACY ORIGINAL (src\\extractVessels.m):\n');
    fprintf(fid, '  dev : Dice=%.4f Sens=%.4f Spec=%.4f Acc=%.4f Prec=%.4f\n', ...
        meta.legacyDev(1), meta.legacyDev(3), meta.legacyDev(4), meta.legacyDev(5), meta.legacyDev(6));
    fprintf(fid, '  test: Dice=%.4f Sens=%.4f Spec=%.4f Acc=%.4f Prec=%.4f\n\n', ...
        meta.legacyTest(1), meta.legacyTest(3), meta.legacyTest(4), meta.legacyTest(5), meta.legacyTest(6));

    fprintf(fid, 'LOCKED TEST RESULTS (n=20, inside eroded FOV, 1st_manual GT):\n');
    fprintf(fid, '  baseline_0.743: Dice=%.4f F1=%.4f Sens=%.4f Spec=%.4f Acc=%.4f Prec=%.4f AUC=%.4f\n', ...
        meta.testBaseline(1), meta.testBaseline(2), meta.testBaseline(3), meta.testBaseline(4), meta.testBaseline(5), meta.testBaseline(6), meta.testBaseline(7));
    fprintf(fid, '  champion       : Dice=%.4f F1=%.4f Sens=%.4f Spec=%.4f Acc=%.4f Prec=%.4f AUC=%.4f\n\n', ...
        meta.testChampion(1), meta.testChampion(2), meta.testChampion(3), meta.testChampion(4), meta.testChampion(5), meta.testChampion(6), meta.testChampion(7));

    fprintf(fid, 'ROUND-1 top-12 dev results:\n');
    sc = meta.devScores(1:numel(exps1), :);
    [~, j] = sort(sc(:,1), 'descend');
    for k = 1:min(12, numel(j))
        x = exps1{j(k)};
        fprintf(fid, '  %-22s [%s] Dice=%.4f Sens=%.4f Spec=%.4f Acc=%.4f Prec=%.4f AUC=%.4f\n', ...
            x.experiment, x.category, sc(j(k),1), sc(j(k),3), sc(j(k),4), sc(j(k),5), sc(j(k),6), sc(j(k),7));
    end
    if numel(exps2) > 0
        fprintf(fid, '\nROUND-2 top-6 dev results (refinement around round-1 champ):\n');
        sc2 = meta.devScores(numel(exps1)+1:end, :);
        [~, j2] = sort(sc2(:,1), 'descend');
        for k = 1:min(6, numel(j2))
            x = exps2{j2(k)};
            fprintf(fid, '  %-22s Dice=%.4f Sens=%.4f Spec=%.4f Acc=%.4f Prec=%.4f AUC=%.4f\n', ...
                x.experiment, sc2(j2(k),1), sc2(j2(k),3), sc2(j2(k),4), sc2(j2(k),5), sc2(j2(k),6), sc2(j2(k),7));
        end
    end
    fclose(fid);
end

%% ============================ MONTAGES =====================================

function makeMontages(split, baselineExp, championExp, erodePx, outDir)
    show = [1 5 10 15 20];   % 5 test images for the montage
    show = show(show <= numel(split));
    K = numel(show);
    fig = figure('Visible','off','Position',[50 50 220*K+60 5*220]);
    for c = 1:K
        s  = split(show(c));
        img = imread(s.img);
        G1  = imread(s.m1) > 0;
        bank = buildBank(s, erodePx, baselineExp.preproc);
        Mb = applyBinary(bank, baselineExp);
        bank = buildBank(s, erodePx, championExp.preproc);
        Mc = applyBinary(bank, championExp);
        panels = {img, G1, Mb, Mc, vesselOverlay(img, Mc)};
        labs = {'Original','Ground Truth','Baseline','Champion','Overlay'};
        for r = 1:5
            subplot(5, K, (r-1)*K + c);
            imshow(panels{r});
            title(sprintf('%s %02d', labs{r}, show(c)), 'FontSize', 8);
        end
    end
    sgtitle('DRIVE test - baseline vs champion (extractVessels classical)', 'FontSize', 11);
    exportgraphics(fig, fullfile(outDir,'best_vessel_montage.png'), 'Resolution', 110);
    close(fig);

    % error analysis on 10 test images
    show10 = [1 3 5 7 9 11 13 15 17 20];
    show10 = show10(show10 <= numel(split));
    K2 = numel(show10);
    fig = figure('Visible','off','Position',[60 60 230*K2+60 6*220]);
    for c = 1:K2
        s  = split(show10(c));
        img = imread(s.img);
        G1  = imread(s.m1) > 0;
        bank = buildBank(s, erodePx, baselineExp.preproc);
        Mb = applyBinary(bank, baselineExp);
        bank = buildBank(s, erodePx, championExp.preproc);
        Mc = applyBinary(bank, championExp);
        Fe = imerode(imread(s.fov) > 0, strel('disk', erodePx));
        G = G1 & Fe;
        FP = Mc & ~G;
        FN = G & ~Mc;
        panels = {img, G, Mb, Mc, FP, FN};
        labs = {'Original','GT','Baseline','Champion','FP map','FN map'};
        for r = 1:6
            subplot(6, K2, (r-1)*K2 + c);
            imshow(panels{r});
            title(sprintf('%s %02d', labs{r}, show10(c)), 'FontSize', 7);
        end
    end
    sgtitle('Vessel error analysis - DRIVE test (champion): red=pred, blue=missed', 'FontSize', 11);
    exportgraphics(fig, fullfile(outDir,'vessel_error_analysis.png'), 'Resolution', 105);
    close(fig);
end

function ov = vesselOverlay(img, mask)
    if size(img,3) == 1
        ov = repmat(im2double(img), [1 1 3]);
    else
        ov = im2double(img);
    end
    r = ov(:,:,1); g = ov(:,:,2); b = ov(:,:,3);
    r(mask) = 0.15*r(mask); g(mask) = 0.90; b(mask) = 0.15*b(mask);
    ov = cat(3,r,g,b); ov = im2uint8(ov);
end

function nom = legacyMap(img)
%LEGACYMAP Original src/extractVessels.m algorithm.
    gray = im2double(rgb2gray(img));
    gray = adapthisteq(gray);
    nom = imbothat(gray, strel('disk',8));
    nom = mat2gray(nom);
    nom = nom > graythresh(nom);
    nom = bwareaopen(nom, 20);
    nom = bwmorph(nom, 'thin', Inf);
end

function verifyBankVsExtract(split, champCfg, erodePx)
%VERIFYBANKVSEXTRACT Sanity: bank-based eval vs the shipped extractVessels.
%Only valid when the champion uses the extractVessels-compatible pipeline
%(bhgate enhancement + otsu/adaptive threshold); otherwise skipped.
    if ~strcmp(champCfg.enhanceMode, 'bhgate') || ...
       ~ismember(champCfg.thresholdMethod, {'otsu','adaptive'})
        fprintf('SKIP bank-vs-extract verify: pipeline not extract-compatible\n');
        return;
    end
    addpath(fileparts(mfilename('fullpath')));
    % strip experiment-only fields so extractVessels sees only known params
    directCfg = struct();
    directCfg.morphThickness  = champCfg.bhThickness;
    directCfg.gateThickness   = champCfg.gateThickness;
    directCfg.gatePolarity    = champCfg.gatePolarity;
    directCfg.gateWeight      = champCfg.gateWeight;
    directCfg.thresholdMethod = champCfg.thresholdMethod;
    directCfg.thresholdScale  = champCfg.thresholdScale;
    directCfg.adaptSensitivity = champCfg.adaptSensitivity;
    directCfg.lineLength      = champCfg.lineLength;
    directCfg.lineAngles      = champCfg.lineAngles;
    directCfg.closeDisk       = champCfg.closeDisk;
    directCfg.minArea         = champCfg.minArea;
    for i = 1:min(3, numel(split))   % first test images
        s = split(i);
        img = imread(s.img);
        Fe = imerode(imread(s.fov) > 0, strel('disk', erodePx));
        bank = buildBank(s, erodePx, champCfg.preproc);
        [mBank, ~] = applyExperiment(bank, champCfg);
        [Mdir, ~]  = extractVessels(img, directCfg, 'fov', Fe);
        mm = Mdir(Fe(:)); gg = bank.G1(bank.Fm);
        TP=sum(gg&mm); FP=sum(~gg&mm); FN=sum(gg&~mm); TN=sum(~gg&~mm);
        mDir = 2*TP / max(2*TP+FP+FN, 1);
        if abs(mBank(1) - mDir) > 5e-3
            fprintf('WARNING: bank vs extractVessels mismatch on %s (dice %.4f vs %.4f)\n', ...
                s.name, mBank(1), mDir);
        else
            fprintf('OK: %s bank==extractVessels (dice %.4f)\n', s.name, mDir);
        end
    end
end