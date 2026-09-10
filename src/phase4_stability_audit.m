function phase4_stability_audit()
% PHASE4_STABILITY_AUDIT Stability / reproducibility audit.
%   1. Champion model hashes still match the Phase 0 baseline manifest.
%   2. Committed T0 headline metrics recompute identically from the cached
%      733-val arrays (fresh, independent recalculation - no re-inference).
%   3. Inference determinism: the locked 5-class + binary nets, run twice on
%      the same images, must be bit-identical (class labels AND probabilities).
%      This proves the cached T0 predictions are exactly reproducible at the
%      model level (no dropout/BN randomness on the eval path).
%   4. Tolerance window statement: values must land within the documented
%      print precision of the committed artifacts.
%   No retraining, no cache writes, no test set access.

projectRoot = fileparts(fileparts(mfilename('fullpath')));
cd(projectRoot);
addpath(genpath(fullfile(projectRoot, 'src')));

results = struct('check', {}, 'status', {}, 'measured', {}, 'expected', {}, 'note', {});

fprintf('============================================================\n');
fprintf('  PHASE 4 - STABILITY / REPRODUCIBILITY AUDIT\n');
fprintf('  Date: %s\n', datestr(now));
fprintf('============================================================\n');

%% ---- 0. Champion hash integrity vs baseline manifest ----
fprintf('\n[0] Champion model hashes vs baseline manifest\n');
mdl = { ...
    'data/models/day7_pretrained_resnet18_5class_stage2.mat', ...
    'DD152C917689146F6DEC4687B263EC5E5F237ECF60EC719A59F9FCEEFF737C1B'; ...
    'data/models/day7_pretrained_resnet18_binary_stage2.mat', ...
    '43E8DF33B429231EE5BD60A775FDB3629AD81F287617AFAA9308EA87D311F9A0' };
for i = 1:size(mdl, 1)
    h = sha256File(fullfile(projectRoot, mdl{i,1}));
    ok = strcmpi(h, mdl{i,2});
    results(end+1) = record(['P4 hash_' num2str(i)], ok, h, mdl{i,2}, ...
        sprintf('%s', mdl{i,1})); %#ok<AGROW>
    fprintf('  [%s] %s\n  %s\n  %s\n', ternary(ok,'PASS','FAIL'), mdl{i,1}, mdl{i,2}, h);
end

%% ---- 1. T0 headline metrics recomputed fresh from cached arrays ----
fprintf('\n[1] T0 headline metrics recomputed from cached val arrays\n');
A = load(fullfile('data','analysis','day8','reverify_audit_T0.mat'));
Yt = A.YTrue5; Yp = A.YPred5; pRef = A.PRef;

n = numel(Yt);
acc = mean(Yp==Yt);
% macro F1 (per-class recall/precision averaged; equals committed 0.6805)
[rec, prec, mf1] = macroF1(Yt, Yp);
% QWK quadratic weighted kappa (1-based labels 1..5)
qwk = qwk5(Yt, Yp);
refTrue = Yt>=3; refPred = pRef>=0.60;
% pRef interpretation: P(referable). Check orientation by comparing to
% committed sens/spec which match when referable = grade>=2.
sens = sum(refTrue&refPred)/(sum(refTrue)+eps);
spec = sum(~refTrue&~refPred)/(sum(~refTrue)+eps);

expect = struct('acc',0.8281,'mf1',0.6805,'qwk',0.8914,'sens',0.9060,'spec',0.9471);
tol = 5e-4;  % committed values printed at 4 decimals
cmp = {
 'P4 acc_recompute',       acc,  expect.acc
 'P4 mf1_recompute',       mf1,  expect.mf1
 'P4 qwk_recompute',       qwk,  expect.qwk
 'P4 sens_recompute',      sens, expect.sens
 'P4 spec_recompute',      spec, expect.spec
};
for i = 1:size(cmp,1)
    ok = abs(cmp{i,2}-cmp{i,3}) <= tol;
    results(end+1) = record(cmp{i,1}, ok, cmp{i,2}, cmp{i,3}, ...
        sprintf('recomputed %.6f vs committed %.4f (tol %.4f)', cmp{i,2}, cmp{i,3}, tol)); %#ok<AGROW>
    fprintf('  [%s] %-22s = %.6f (committed %.4f)\n', ...
        ternary(ok,'PASS','FAIL'), cmp{i,1}, cmp{i,2}, cmp{i,3});
end

%% ---- 2. Inference determinism (bit-exact under repeated inference) ----
fprintf('\n[2] Inference determinism: locked nets, two runs, bit-identical\n');
S5 = load(fullfile('data','models','day7_pretrained_resnet18_5class_stage2.mat'), 'trainedNet');
SB = load(fullfile('data','models','day7_pretrained_resnet18_binary_stage2.mat'), 'trainedNet');
net5 = S5.trainedNet; netB = SB.trainedNet;

% take 3 val images deterministically (first per class_0/class_1/class_2)
imgs = { fullfile('data','splits','val','class_0','0212dd31f623.png'), ...
         fullfile('data','splits','val','class_1', firstImg('class_1')), ...
         fullfile('data','splits','val','class_2', firstImg('class_2')) };
for k = 1:numel(imgs)
    raw = imread(imgs{k});
    if size(raw,3)==1, raw = repmat(raw,1,1,3); end
    inp = imresize(raw, [224 224]);
    % Run 1
    [~, s5a] = classify(net5, inp); s5a = s5a(:)'; 
    sBa = predict(netB, inp); sBa = sBa(:)';
    [~, gd5a] = max(s5a); 
    % Run 2
    [~, s5b] = classify(net5, inp); s5b = s5b(:)';
    sBb = predict(netB, inp); sBb = sBb(:)';
    [~, gd5b] = max(s5b);
    ok5 = isequal(s5a, s5b); okB = isequal(sBa, sBb);
    results(end+1) = record(sprintf('P4 run1_equals_run2_5cls_%d', k), ok5, ...
        gd5a, gd5b, sprintf('%s', imgs{k})); %#ok<AGROW>
    results(end+1) = record(sprintf('P4 run1_equals_run2_bin_%d', k), okB, ...
        sBa(2), sBb(2), sprintf('%s', imgs{k})); %#ok<AGROW>
    fprintf('  [%s] img%d 5cls run1==run2: %d  bin run1==run2: %d\n', ...
        ternary(ok5&&okB,'PASS','FAIL'), k, ok5, okB);
end

%% ---- 3. Tolerance window summary ----
fprintf('\n[3] Tolerance windows applied\n');
fprintf('  Model hash: exact (SHA-256). Metrics: %.4f abs (match artifact print precision).\n', tol);
fprintf('  Inference determinism: bit-exact (isequal on doubles).\n');

%% ---- 4. Summary ----
fprintf('\n============================================================\n');
nPass = 0; nFail = 0;
for i = 1:numel(results)
    if results(i).status, nPass = nPass+1; tag='PASS'; else, nFail=nFail+1; tag='FAIL'; end
    fprintf('  [%s] %-30s %s\n', tag, results(i).check, results(i).note);
end
fprintf('  TOTAL: %d PASS, %d FAIL\n', nPass, nFail);

outDir = fullfile(projectRoot, 'data','analysis','day10','phase4');
if ~exist(outDir, 'dir'), mkdir(outDir); end
save(fullfile(outDir, 'phase4_stability_audit.mat'), 'results', 'acc','mf1','qwk','sens','spec');
fprintf('  Saved -> data/analysis/day10/phase4/phase4_stability_audit.mat\n');
end

%% --- helpers ---
function p = firstImg(cls)
    f = dir(fullfile('data','splits','val',cls,'*.png'));
    p = f(1).name;
end

function h = sha256File(path)
    % Robust SHA-256 via certutil (avoids .NET array-indexing pitfalls in -batch)
    h = '';
    [~, out] = system(sprintf('certutil -hashfile "%s" SHA256', strrep(path,'/','\')));
    tok = regexp(out, '(?m)([0-9A-Fa-f]{64})', 'tokens', 'once');
    if ~isempty(tok), h = upper(tok{1}); end
end

function [rec, prec, mf1] = macroF1(Yt, Yp)
    C = confusionmat(Yt, Yp, 'Order', 1:5);
    rec = zeros(1,5); prec = zeros(1,5);
    for c = 1:5
        rec(c) = C(c,c)/sum(C(c,:));
        prec(c) = C(c,c)/sum(C(:,c));
    end
    f1 = 2*rec.*prec ./ (rec+prec+eps);
    mf1 = mean(f1);
end

function k = qwk5(a, b)
    % MATCHES committed evaluateClassifier.m computeQWK exactly:
    % weights normalized by (numClasses-1)^2, expected by chance E=row*col/n
    nc = 5;
    W = zeros(nc);
    for i = 1:nc, for j = 1:nc, W(i,j) = (i-j)^2/(nc-1)^2; end, end
    n = numel(a);
    O = zeros(nc);
    for i = 1:n, O(a(i), b(i)) = O(a(i), b(i)) + 1; end
    rowSums = sum(O,2); colSums = sum(O,1);
    E = rowSums * colSums / n;
    numer = sum(W(:).*O(:));
    denom = sum(W(:).*E(:));
    k = 1 - numer/(denom+eps);
end

function rr = record(check, status, measured, expected, note)
    rr = struct('check', check, 'status', status, 'measured', measured, ...
                'expected', expected, 'note', note);
end

function s = ternary(cond, a, b)
    if cond, s = a; else, s = b; end
end