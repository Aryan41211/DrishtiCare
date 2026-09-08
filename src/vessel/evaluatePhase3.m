function out = evaluatePhase3(quick)
%EVALUATEPHASE3 Phase-3 candidate evaluation: dev tune -> lock -> test once.
%
%   evaluatePhase3()       full run (20 dev + 20 test images)
%   evaluatePhase3(true)   smoke test on 2+2 images (for debugging)
%
%   Protocol (identical lock discipline to runVesselExperiments):
%     DEV  = DRIVE training set (20 images, 21-40): ALL candidate tuning.
%     TEST = DRIVE test set    (20 images, 01-20): the LOCKED candidate is
%            evaluated EXACTLY ONCE, together with the unchanged session
%            champion (extractVessels + vesselParams('champion')) reference.
%
%   The Phase-3 candidate (extractVessels3 + vesselParams3) attacks the
%   champion's *visual* over-segmentation: false positives clustered on
%   optic-disc rims, illumination-shading bands, bright lesion borders and
%   the FOV edge. It adds a leak-free flat-field correction, OD-rim and
%   bright-lesion suppression, adaptive/percentile thresholding and thin-
%   vessel-preserving cleanup, all inside the FOV.
%
%   Outputs (data\analysis\vessel\phase3\):
%     phase3_results.csv/.mat      - dev sweep + locked test rows
%     phase3_dev_table.csv         - dev sweep table (for the report)
%     phase3_montage.png           - 5 test images Orig|GT|Champ|Phase3|Overlay
%     phase3_error_analysis.png    - 3 test images Orig|GT|Champ|Phase3|FP|FN
%     phase3_diagnostics.png       - image 05: flat-field / gate / OD / bright
%                                    suppression layer-cake
%     fp_analysis.png/.csv         - WHY the champion over-segments: FP rate
%                                    vs distance-to-OD / bright blob / rim
%     phase3_locked_config.mat     - locked candidate CONFIG + presets copy
%     metrics.txt                  - full report
%
%   This is a research prototype, NOT a clinically validated system.

%% ------------------------------ setup ------------------------------------
scriptDir = fileparts(mfilename('fullpath'));
addpath(scriptDir);
projRoot = 'C:\projects\DrishtiCare';
driveDir = fullfile(projRoot, 'data', 'drive', 'DRIVE');
outDir   = fullfile(projRoot, 'data', 'analysis', 'vessel', 'phase3');
if ~exist(outDir, 'dir'), mkdir(outDir); end

evalFovErode = 5;   % px, applied to BOTH prediction-scoring and GT

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

baseCfg    = vesselParams3('phase3');
champCfg   = vesselParams('champion');   % untouched session champion
cands      = defineCandidates(baseCfg); % cell array of {name, override}

%% --------------------------- DEV SWEEP ------------------------------------
nC = size(cands, 1);
devScores   = zeros(nC, 7);   % dice f1 sens spec acc prec auc
devTime     = zeros(nC, 1);
champDev    = zeros(1, 7);

for e = 1:nC
    cfg = mergeOv(baseCfg, cands{e, 2});
    t0  = tic;
    for i = 1:numel(dev)
        s = dev(i);
        img = imread(s.img);
        F   = imread(s.fov) > 0;
        G1  = imread(s.m1)  > 0;
        Fe  = imerode(F, strel('disk', evalFovErode));
        [M, R] = extractVessels3(img, cfg, 'fov', F);
        devScores(e,:) = devScores(e,:) + scorePair(M, R, G1, Fe);
    end
    devTime(e) = toc(t0);
    devScores(e,:) = devScores(e,:) / numel(dev);
end

% champion reference on dev (same scoring path)
for i = 1:numel(dev)
    s = dev(i);
    img = imread(s.img);
    F   = imread(s.fov) > 0;
    G1  = imread(s.m1)  > 0;
    Fe  = imerode(F, strel('disk', evalFovErode));
    [M, R] = extractVessels(img, champCfg, 'fov', F);
    champDev = champDev + scorePair(M, R, G1, Fe);
end
champDev = champDev / numel(dev);

%% --------------------------- LOCK ------------------------------------------
[ci, strictCi] = pickChampion(devScores);
locked        = mergeOv(baseCfg, cands{ci, 2});
lockedName    = cands{ci, 1};
strictName    = cands{strictCi, 1};
fprintf('INFO: strict Dice-first dev pick = %s (dice %.4f); guardrail-locked = %s (dice %.4f)\n', ...
    strictName, devScores(strictCi,1), lockedName, devScores(ci,1));

%% --------------------------- TEST (once) -----------------------------------
testLocked  = zeros(1, 7);
testChamp   = zeros(1, 7);
aucFullLock = zeros(1, numel(test));   % whole-FOV AUC (phase-1 convention)
aucFullChamp = zeros(1, numel(test));
for i = 1:numel(test)
    s = test(i);
    img = imread(s.img);
    F   = imread(s.fov) > 0;
    G1  = imread(s.m1)  > 0;
    Fe  = imerode(F, strel('disk', evalFovErode));

    [M, R] = extractVessels3(img, locked, 'fov', F);
    testLocked = testLocked + scorePair(M, R, G1, Fe);
    try
        [~,~,~,a] = perfcurve(double(G1(:) & F(:)), R(:), true);
        aucFullLock(i) = a;
    catch
        aucFullLock(i) = NaN;
    end

    [M, R] = extractVessels(img, champCfg, 'fov', F);
    testChamp = testChamp + scorePair(M, R, G1, Fe);
    try
        [~,~,~,a] = perfcurve(double(G1(:) & F(:)), R(:), true);
        aucFullChamp(i) = a;
    catch
        aucFullChamp(i) = NaN;
    end
end
testLocked = testLocked / numel(test);
testChamp  = testChamp  / numel(test);

%% --------------------------- OUTPUTS ----------------------------------------
writeTables(outDir, cands, baseCfg, devScores, devTime, champDev, ...
    lockedName, testLocked, testChamp, mean(aucFullLock, 'omitnan'), ...
    mean(aucFullChamp, 'omitnan'), quick, strictName, devScores(strictCi,1));

save(fullfile(outDir,'phase3_locked_config.mat'), 'locked', 'lockedName', ...
    'devScores', 'testLocked', 'testChamp', 'champDev', 'aucFullLock', ...
    'aucFullChamp', 'baseCfg');

% montages use fixed representative TEST images (index by split position)
montInx  = [1 5 8 15 20];  montInx = montInx(montInx <= numel(test));
errInx   = [5 8 18];       errInx  = errInx(errInx <= numel(test));
diagInx  = min(5, numel(test));
makeMontage(outDir, test(montInx), champCfg, locked, evalFovErode);
makeErrorAnalysis(outDir, test(errInx), champCfg, locked, evalFovErode);
makeDiagnostics(outDir, test(diagInx), champCfg, locked, evalFovErode);

% root-cause: WHY does the champion over-segment visually?
fp = analyzeFP(dev, champCfg, evalFovErode, outDir);

%% --------------------------- REPORT -----------------------------------------
reportMetrics(outDir, cands, devScores, devTime, champDev, lockedName, ...
    testLocked, testChamp, mean(aucFullLock,'omitnan'), ...
    mean(aucFullChamp,'omitnan'), fp, quick, strictName, devScores(strictCi,1));

fprintf('\n==== Phase-3 dev sweep (top 8) ====\n');
top = sortrows([(1:nC)' devScores], 2, 'descend');
for k = 1:min(8, size(top,1))
    e = top(k,1);
    fprintf('  %-16s dice %.4f sens %.4f spec %.4f acc %.4f prec %.4f auc %.4f (%.0fs)\n', ...
        cands{e, 1}, devScores(e,1), devScores(e,3), devScores(e,4), ...
        devScores(e,5), devScores(e,6), devScores(e,7), devTime(e));
end
fprintf('\n==== Dev champion =====\n');
fprintf('  champion preset   dice %.4f sens %.4f spec %.4f acc %.4f prec %.4f auc %.4f\n', ...
    champDev(1), champDev(3), champDev(4), champDev(5), champDev(6), champDev(7));
fprintf('  LOCKED %-16s dice %.4f sens %.4f spec %.4f acc %.4f prec %.4f auc %.4f\n', ...
    lockedName, devScores(ci,1), devScores(ci,3), devScores(ci,4), ...
    devScores(ci,5), devScores(ci,6), devScores(ci,7));
fprintf('\n==== TEST (locked, exactly once) ====\n');
fprintf('  champion preset   dice %.4f sens %.4f spec %.4f acc %.4f prec %.4f auc %.4f (aucFOV %.4f)\n', ...
    testChamp(1), testChamp(3), testChamp(4), testChamp(5), testChamp(6), ...
    testChamp(7), mean(aucFullChamp,'omitnan'));
fprintf('  %s  dice %.4f sens %.4f spec %.4f acc %.4f prec %.4f auc %.4f (aucFOV %.4f)\n', ...
    lockedName, testLocked(1), testLocked(3), testLocked(4), testLocked(5), ...
    testLocked(6), testLocked(7), mean(aucFullLock,'omitnan'));

out = struct();
out.lockedName = lockedName; out.locked = locked;
out.devScores = devScores; out.champDev = champDev;
out.testLocked = testLocked; out.testChamp = testChamp;
out.aucFullLock = mean(aucFullLock,'omitnan');
out.aucFullChamp = mean(aucFullChamp,'omitnan');
out.fp = fp;

end

%% ============================ LOCAL FUNCTIONS ===============================

function cands = defineCandidates(base)
%DEIFNECANDIDATES Named single-factor perturbations (and two combos) on the
%default Phase-3 config. Each entry = {name, struct-of-overrides}.
    cands = { ...
        'p3_default',    struct(); ...
        'p3_thr_11',     struct('thresholdFrac', 0.11); ...
        'p3_thr_15',     struct('thresholdFrac', 0.15); ...
        'p3_od_off',     struct('odEnable', false); ...
        'p3_od_strong',  struct('odRingAtten', 0.02, 'odInteriorAtten', 0.50, 'odDilateFrac', 2.0); ...
        'p3_od_wide',    struct('odDilateFrac', 2.2, 'odNearCenter', 0.70, 'odInteriorAtten', 0.70); ...
        'p3_bright_off', struct('brightEnable', false); ...
        'p3_bright_d4',  struct('brightDilate', 4, 'brightMinSize', 60); ...
        'p3_gate_03',    struct('gateWeight', 0.3); ...
        'p3_gate_07',    struct('gateWeight', 0.7); ...
        'p3_adapt_45',   struct('thresholdMethod', 'adaptive', 'adaptSensitivity', 0.45); ...
        'p3_adapt_55',   struct('thresholdMethod', 'adaptive', 'adaptSensitivity', 0.55); ...
        'p3_thin_on',    struct('thinPreserve', true); ...
        'p3_close_1',    struct('closeDisk', 1); ...
        'p3_minA_25',    struct('minArea', 25); ...
        'p3_nobridge',   struct('doBridge', false); ...
        'p3_comb_A',     struct('odRingAtten', 0.02, 'odInteriorAtten', 0.50, 'brightDilate', 4); ...
        'p3_comb_B',     struct('odRingAtten', 0.02, 'thinPreserve', true, 'thresholdFrac', 0.15); ...
        'p3_ff_on',      struct('flatFieldEnable', true, 'bgSigma', 25); ...
        'p3_ff_strong',  struct('flatFieldEnable', true, 'bgSigma', 40); ...
        };
end

function cfg = mergeOv(base, ov)
    cfg = base;
    f = fieldnames(ov);
    for i = 1:numel(f)
        if isfield(cfg, f{i})
            cfg.(f{i}) = ov.(f{i});
        else
            warning('evaluatePhase3:unknownOverride', ...
                'Ignoring unknown override ''%s''.', f{i});
        end
    end
end

function m = scorePair(M, R, G1, Fe)
%SCOREPAIR dice/f1/sens/spec/acc/prec/auc inside the eroded FOV (Fe).
    g = G1(Fe); p = M(Fe); r = R(Fe);
    TP = sum(g & p); FP = sum(~g & p);
    FN = sum(g & ~p); TN = sum(~g & ~p);
    m(1) = 2*TP / max(2*TP+FP+FN, 1);
    m(2) = m(1);
    m(3) = TP / max(TP+FN, 1);
    m(4) = TN / max(TN+FP, 1);
    m(5) = (TP+TN) / max(TP+FN+FP+TN, 1);
    m(6) = TP / max(TP+FP, 1);
    try
        [~,~,~,a] = perfcurve(double(g), r, true);
        m(7) = a;
    catch
        m(7) = NaN;
    end
end

function [idx, strictIdx] = pickChampion(devScores)
%PICKCHAMPION Selection rule per session protocol: Dice (primary) ->
%Sens -> Prec -> Spec, with a VISUAL-consistency guardrail on top of it:
%among candidates within `band` of the best Dice, prefer the one with the
%highest precision (fewest false positives per FOV pixel). This reflects
%the Phase-3 goal (suppress concentrated FP) without touching TEST.
%Also returns the strict protocol pick (Dice-only) for transparency.
    cand = find(devScores(:,1) >= 0.3 & devScores(:,3) >= 0.3);
    if isempty(cand)
        error('evaluatePhase3:champ', 'No viable candidate.');
    end
    sc     = devScores(cand, :);
    [~, j] = sortrows([-sc(:,1), -sc(:,3), -sc(:,6), -sc(:,4)], [1 2 3 4]);
    strictIdx = cand(j(1));
    best   = j(1);
    band   = 0.003;
    inBand = cand(sc(:,1) >= sc(best,1) - band);
    sub    = devScores(inBand, :);
    [~, p] = max(sub(:,6));          % highest precision inside the band
    idx = inBand(p);
end

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
        S(i).fov  = fullfile(rootDir,'mask',   sprintf('%02d_test_mask.gif',   idx));
        S(i).m1   = fullfile(rootDir,'1st_manual', sprintf('%02d_manual1.gif', idx));
        S(i).m2   = fullfile(rootDir,'2nd_manual', sprintf('%02d_manual2.gif', idx));
        S(i).name = f{i};
    end
    for i = 1:n
        if contains(S(i).fov, 'training')
            S(i).fov = fullfile(rootDir,'mask', sprintf('%02d_training_mask.gif', firstIdx+i-1));
        end
    end
end

%% ---------------------------- OUTPUT WRITERS --------------------------------

function writeTables(outDir, cands, baseCfg, devScores, devTime, champDev, ...
    lockedName, testLocked, testChamp, aucFullLock, aucFullChamp, quick, ...
    strictName, strictDice)
%WRITETABLES CSV/MAT of dev sweep + locked test rows.
    n = size(cands, 1);
    names = cell(n,1);
    for e = 1:n, names{e} = cands{e, 1}; end
    % dev table
    fid = fopen(fullfile(outDir,'phase3_dev_table.csv'), 'w');
    fprintf(fid, 'candidate,split,n,dice,f1,sens,spec,acc,prec,auc,runtime_s\n');
    for e = 1:n
        fprintf(fid, '%s,dev,%d,%.4f,%.4f,%.4f,%.4f,%.4f,%.4f,%.4f,%.1f\n', ...
            names{e}, 1, devScores(e,1), devScores(e,2), ...
            devScores(e,3), devScores(e,4), devScores(e,5), devScores(e,6), ...
            devScores(e,7), devTime(e));
    end
    fprintf(fid, 'champion_preset,dev,1,%.4f,%.4f,%.4f,%.4f,%.4f,%.4f,%.4f,-\n', ...
        champDev(1), champDev(2), champDev(3), champDev(4), champDev(5), champDev(6), champDev(7));
    fclose(fid);

    % results CSV (dev sweep + locked + champion rows)
    fid = fopen(fullfile(outDir,'phase3_results.csv'), 'w');
    fprintf(fid, 'candidate,split,n,dice,f1,sens,spec,acc,prec,auc,aucFOV_full\n');
    for e = 1:n
        fprintf(fid, '%s,dev,%d,%.4f,%.4f,%.4f,%.4f,%.4f,%.4f,%.4f,\n', ...
            names{e}, 1, devScores(e,1), devScores(e,2), ...
            devScores(e,3), devScores(e,4), devScores(e,5), devScores(e,6), devScores(e,7));
    end
    fprintf(fid, '%s,test,20,%.4f,%.4f,%.4f,%.4f,%.4f,%.4f,%.4f,%.4f\n', ...
        lockedName, testLocked(1), testLocked(2), testLocked(3), testLocked(4), ...
        testLocked(5), testLocked(6), testLocked(7), aucFullLock);
    fprintf(fid, 'champion_preset,test,20,%.4f,%.4f,%.4f,%.4f,%.4f,%.4f,%.4f,%.4f\n', ...
        testChamp(1), testChamp(2), testChamp(3), testChamp(4), testChamp(5), ...
        testChamp(6), testChamp(7), aucFullChamp);
    fclose(fid);

    res = struct();
    res.candidate = names; res.dev = devScores; res.devTime_s = devTime;
    res.champDev = champDev; res.locked = lockedName;
    res.testLocked = testLocked; res.testChamp = testChamp;
    res.aucFullLock = aucFullLock; res.aucFullChamp = aucFullChamp;
    res.quick = quick; res.base = baseCfg;
    save(fullfile(outDir,'phase3_results.mat'), 'res');

    if ~quick
        % human-observer secondary GT for the two test rows
        [dl, dc] = test2ndManual(outDir, testLocked, lockedName, testChamp);
        fprintf('INFO: 2nd-manual Dice on test -> locked %.4f champion %.4f\n', dl, dc);
    end
end

function [dl, dc] = test2ndManual(outDir, lk, lockedName, ch)
%TEST2NDMANUAL Report test Dice vs the 2nd manual observer as a secondary
%view (primary metrics stay on 1st_manual).
    projRoot = 'C:\projects\DrishtiCare';
    driveDir = fullfile(projRoot, 'data', 'drive', 'DRIVE');
    testAll = makeSplit(fullfile(driveDir,'test'), 1);
    dl = 0; dc = 0;
    for i = 1:numel(testAll)
        s = testAll(i);
        img = imread(s.img);
        F   = imread(s.fov) > 0;
        G2  = imread(s.m2)  > 0;
        Fe  = imerode(F, strel('disk', 5));
        [M, ~] = extractVessels3(img, lk, 'fov', F);
        dl = dl + diceV(M, G2, Fe);
        [M, ~] = extractVessels(img, ch, 'fov', F);
        dc = dc + diceV(M, G2, Fe);
    end
    dl = dl/numel(testAll); dc = dc/numel(testAll);
    dlm = struct('locked_dice2nd', dl, 'champ_dice2nd', dc);
    save(fullfile(outDir,'phase3_dice2nd.mat'), '-struct', 'dlm');
end

function d = diceV(M, G, Fe)
    g = G(Fe); p = M(Fe);
    TP = sum(g & p); FP = sum(~g & p); FN = sum(g & ~p);
    d = 2*TP / max(2*TP+FP+FN, 1);
end

function makeMontage(outDir, imgs, champCfg, locked, erodePx)
%MAKEMONTAGE 5 images: Orig | GT | Champion | Phase3 | Overlay.
    npanels = 5;
    rows = numel(imgs);
    fig = figure('Color','w', 'Visible','off');
    for r = 1:rows
        s = imgs(r);
        img = imread(s.img);
        F   = imread(s.fov) > 0;
        G1  = imread(s.m1)  > 0;
        Fe  = imerode(F, strel('disk', erodePx));
        [Mc, ~] = extractVessels(img, champCfg, 'fov', F);
        [Mp, ~] = extractVessels3(img, locked, 'fov', F);
        gtR = im2uint8(G1); champR = im2uint8(Mc); p3 = im2uint8(Mp);
        gp = im2double(img); gp(:,:,1) = max(gp(:,:,1), 0.55*im2double(p3));
        gp = im2uint8(gp);
        panels = {img, gtR, champR, p3, gp};
        for c = 1:npanels
            ax = subtightplot(rows, npanels, (r-1)*npanels + c);
            if c == 1
                image(panels{c}); axis image off; title(sprintf('img %s', s.name), 'FontSize', 8);
            elseif c == 2
                image(repmat(panels{c},1,1,3)); axis image off; title('GT 1st manual','FontSize',8);
            elseif c == 3
                image(repmat(panels{c},1,1,3)); axis image off; title('Champion','FontSize',8);
            elseif c == 4
                image(repmat(panels{c},1,1,3)); axis image off; title('Phase-3','FontSize',8);
            else
                image(panels{c}); axis image off; title('Phase-3 overlay','FontSize',8);
            end
        end
    end
    print(fig, fullfile(outDir,'phase3_montage.png'), '-dpng', '-r100');
    close(fig);
end

function makeErrorAnalysis(outDir, imgs, champCfg, locked, erodePx)
%MAKEERRORANALYSIS 3 images: Orig|GT|Champ|Phase3|FP|FN (FP/FN of Phase-3).
    fig = figure('Color','w', 'Visible','off');
    npanels = 6;
    rows = numel(imgs);
    for r = 1:rows
        s = imgs(r);
        img = imread(s.img);
        F   = imread(s.fov) > 0;
        G1  = imread(s.m1)  > 0;
        Fe  = imerode(F, strel('disk', erodePx));
        [Mc, ~] = extractVessels(img, champCfg, 'fov', F);
        [Mp, ~] = extractVessels3(img, locked, 'fov', F);
        fp = Mp & ~G1 & Fe;
        fn = ~Mp & G1 & Fe;
        pan = {img, repmat(im2uint8(G1),1,1,3), repmat(im2uint8(Mc),1,1,3), ...
               repmat(im2uint8(Mp),1,1,3), fp, fn};
        for c = 1:npanels
            ax = subtightplot(rows, npanels, (r-1)*npanels + c);
            if c == 1
                image(pan{c}); axis image off; title(s.name, 'FontSize', 8);
            elseif c == 5
                image(repmat(im2uint8(pan{c}),1,1,3));  axis image off; title('FP','FontSize',8);
            elseif c == 6
                image(repmat(im2uint8(pan{c}),1,1,3));  axis image off; title('FN','FontSize',8);
            else
                image(pan{c}); axis image off;
                titles = {'GT','Champion','Phase-3'};
                title(titles{c-1}, 'FontSize', 8);
            end
        end
    end
    print(fig, fullfile(outDir,'phase3_error_analysis.png'), '-dpng', '-r100');
    close(fig);
end

function makeDiagnostics(outDir, s, champCfg, locked, erodePx)
%MAKEDIAGNOSTICS Layer-cake for image 05: what the Phase-3 pipeline sees.
%The suppression layers are shown with the DEFAULT candidate (detection ON),
%the binary map with the LOCKED config.
    img = imread(s.img);
    F   = imread(s.fov) > 0;
    def = vesselParams3('phase3');
    [~, ~, ~, dbg] = extractVessels3(img, def, 'fov', F);
    [Mp, R] = extractVessels3(img, locked, 'fov', F);
    fig = figure('Color','w', 'Visible','off');
    pan = {img, ...
           repmat(im2uint8(dbg.background),1,1,3), ...
           repmat(im2uint8(dbg.corrected),1,1,3), ...
           dbg.odMask, dbg.odRing, dbg.brightMask, ...
           repmat(im2uint8(dbg.gate),1,1,3), ...
           repmat(im2uint8(R),1,1,3), ...
           repmat(im2uint8(Mp),1,1,3)};
    labs = {sprintf('Orig %s', s.name), 'illumination B', 'flat-corrected', ...
            'OD mask', 'OD ring', 'bright mask', 'Frangi gate', ...
            'phase3 response', 'phase3 binary'};
    for c = 1:9
        subplot(3,3,c);
        image(pan{c}); axis image off; title(labs{c}, 'FontSize', 8);
    end
    print(fig, fullfile(outDir,'phase3_diagnostics.png'), '-dpng', '-r100');
    close(fig);
end

function h = subtightplot(a, b, p)
%SUBTIGHTPLOT minimal tight subplot (avoid extra toolbox dependency).
    h = subplot(a, b, p);
end

function fp = analyzeFP(dev, champCfg, erodePx, outDir)
%ANALYZEFP Root-cause: where do the champion's false positives live, and
%how much of them fall inside the regions the Phase-3 candidate SUPPRESSES?
%Buckets inside the eroded FOV (Fe), measured against the champion's own
%predictions:
%   OD-region  = the candidate's detected optic-disc suppression mask
%                (disc + dilated rim ring) - dbg.odMask.
%   bright-near = candidate's bright-lesion mask dilated 10 px - what the
%                bright suppression is designed to kill.
%   rim         = FOV edge band (15 px inside the FOV edge).
%   rest        = everything else.
%This tells us whether the "visual over-segmentation" is actually driven by
%OD edges / brightlesions / rims (then suppression helps) or by diffuse
%background texture (then it cannot help DRIVE metrics).
    candCfg = vesselParams3('phase3');   % detectors used by the candidate
    counts = zeros(1, 4); npix = zeros(1, 4);
    for i = 1:numel(dev)
        s = dev(i);
        img = imread(s.img);
        F   = imread(s.fov) > 0;
        G1  = imread(s.m1)  > 0;
        Fe  = imerode(F, strel('disk', erodePx));
        [M, ~] = extractVessels(img, champCfg, 'fov', F);
        [~, ~, ~, dbg] = extractVessels3(img, candCfg, 'fov', F);
        FP = M & ~G1 & Fe;
        bOD  = dbg.odMask & Fe;
        bBr  = imdilate(dbg.brightMask, strel('disk', 10)) & Fe;
        bRim = Fe & ~imerode(Fe, strel('disk', 15));
        rest = ~(bOD | bBr | bRim);
        counts = counts + [sum(FP(:) & bOD(:)), sum(FP(:) & bBr(:)), ...
                           sum(FP(:) & bRim(:)), sum(FP(:) & rest(:))];
        npix   = npix + [sum(bOD(:)), sum(bBr(:)), sum(bRim(:)), sum(rest(:))];
    end
    labels = {'OD-region', 'bright-near', 'rim', 'rest'};
    totFP = sum(counts); totN  = sum(npix);
    rate  = counts ./ max(npix, 1);
    over  = totFP / max(totN, 1);
    lift  = rate / max(over, 1e-9);
    share = counts / max(totFP, 1);

    fid = fopen(fullfile(outDir,'fp_analysis.csv'), 'w');
    fprintf(fid, 'bucket,FP_px,bucket_px,FP_rate,lift_vs_overall,share_of_totalFP\n');
    for k = 1:4
        fprintf(fid, '%s,%d,%d,%.6f,%.2f,%.2f\n', labels{k}, counts(k), ...
            npix(k), rate(k), lift(k), share(k));
    end
    fprintf(fid, 'OVERALL,%d,%d,%.6f,1.00,1.00\n', totFP, totN, over);
    fclose(fid);

    fig = figure('Color','w', 'Visible','off');
    subplot(1,2,1);
    bar(labels, lift); ylabel('FP-rate lift vs overall'); grid on;
    title('Champion FP rate by region (dev, n=20)');
    subplot(1,2,2);
    bar(labels, share); ylabel('share of total FP'); grid on;
    title('Where the champion''s false positives are');
    print(fig, fullfile(outDir,'fp_analysis.png'), '-dpng', '-r120');
    close(fig);

    fp = struct('labels', {labels}, 'counts', counts, 'npix', npix, ...
        'rate', rate, 'lift', lift, 'share', share, 'overall', over, ...
        'totalFP', totFP, 'totalN', totN);
end

function reportMetrics(outDir, cands, devScores, devTime, champDev, lockedName, ...
    testLocked, testChamp, aucFullLock, aucFullChamp, fp, quick, ...
    strictName, strictDice)
%REPORTMETRICS Write metrics.txt.
    fid = fopen(fullfile(outDir,'metrics.txt'), 'w');
    fprintf(fid, 'Phase-3 candidate evaluation - DRIVE (research prototype)\n');
    fprintf(fid, '=========================================================\n\n');
    fprintf(fid, 'Lock discipline: ALL tuning on DEV (DRIVE training 21-40),\n');
    fprintf(fid, 'locked candidate evaluated EXACTLY ONCE on TEST (01-20).\n');
    fprintf(fid, 'Metrics inside FOV eroded by 5 px; primary GT = 1st_manual.\n\n');
    fprintf(fid, 'Lock rule (dev-only): among candidates within 0.003 Dice of\n');
    fprintf(fid, 'the strict best (Dice->Sens->Prec->Spec), pick highest PRECISION\n');
    fprintf(fid, '(the Phase-3 goal is fewer concentrated false positives).\n');
    fprintf(fid, 'Strict Dice-first dev pick would be: %s (dice %.4f).\n\n', ...
        strictName, strictDice);
    fprintf(fid, 'DEV sweep (n=20):\n');
    fprintf(fid, '  candidate         dice   f1     sens   spec   acc    prec   auc    runtime_s\n');
    for e = 1:size(cands, 1)
        fprintf(fid, '  %-16s %.4f %.4f %.4f %.4f %.4f %.4f %.4f %.0f\n', ...
            cands{e, 1}, devScores(e,1), devScores(e,2), devScores(e,3), ...
            devScores(e,4), devScores(e,5), devScores(e,6), devScores(e,7), devTime(e));
    end
    fprintf(fid, '  champion_preset   %.4f %.4f %.4f %.4f %.4f %.4f %.4f -\n', ...
        champDev(1), champDev(2), champDev(3), champDev(4), champDev(5), champDev(6), champDev(7));
    fprintf(fid, '\nLOCKED candidate: %s\n', lockedName);
    fprintf(fid, '\nTEST (n=20, exactly one evaluation of the locked config):\n');
    fprintf(fid, '  %-16s dice   f1     sens   spec   acc    prec   auc(FOV)  auc(FOVfull)\n', '');
    fprintf(fid, '  champion_preset   %.4f %.4f %.4f %.4f %.4f %.4f %.4f %.4f\n', ...
        testChamp(1), testChamp(2), testChamp(3), testChamp(4), ...
        testChamp(5), testChamp(6), testChamp(7), aucFullChamp);
    fprintf(fid, '  %-16s %.4f %.4f %.4f %.4f %.4f %.4f %.4f %.4f\n', ...
        lockedName, testLocked(1), testLocked(2), testLocked(3), ...
        testLocked(4), testLocked(5), testLocked(6), testLocked(7), aucFullLock);
    fprintf(fid, '\nChampion (unchanged reference): DRIVE test Dice %.4f (this session).\n', testChamp(1));
    fprintf(fid, 'Phase-1 baseline Dice 0.7428 / session champion Dice 0.7535 (prior session).\n');
    if ~exist(fullfile(outDir,'phase3_dice2nd.mat'),'file')
        fprintf(fid, '\n2nd-manual Dice: (not computed in quick mode)\n');
    else
        dd = load(fullfile(outDir,'phase3_dice2nd.mat'));
        fprintf(fid, '\n2nd-manual Dice: locked %.4f champion %.4f (human inter-observer ~0.790).\n', ...
            dd.locked_dice2nd, dd.champ_dice2nd);
    end
    fprintf(fid, '\nRoot-cause (champion FP on DEV, n=%d):\n', 20);
    fprintf(fid, '  bucket        FP_px  bucket_px  FPrate   lift  share\n');
    for k = 1:4
        fprintf(fid, '  %-12s %6d %9d  %6.4f  %5.2f  %5.2f\n', fp.labels{k}, ...
            fp.counts(k), fp.npix(k), fp.rate(k), fp.lift(k), fp.share(k));
    end
    fprintf(fid, '  OVERALL       %6d %9d  %6.4f   1.00   1.00\n', fp.totalFP, fp.totalN, fp.overall);
    fprintf(fid, '\nQuick smoke run: %d\n', quick);
    fclose(fid);
end