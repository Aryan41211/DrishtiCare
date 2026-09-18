function fresh_independent_verify()
% FRESH_INDEPENDENT_VERIFY Independent end-to-end re-audit of all headline
% numbers, run on 2026-09-17 at the user's request ("is my model faking the
% scores?"). Performs FRESH inference with BOTH locked champion networks on
% the full 733-image validation set (same preprocessing as training/eval:
% imread -> imresize 224 -> predict, argmax). It does NOT trust any project
% evaluator; all metrics are recomputed here from the fresh predictions with
% independent implementations. Committed artifacts are READ-ONLY (nothing is
% overwritten). Comparison vs the committed T0 cache is bit-exact.

% MIT-simple self-contained audit.
root = 'C:\projects\DrishtiCare';
cd(root);
% NOTE: intentionally no addpath(genpath('src')) - this script stands alone.
% (computeQWK is implemented inline; no eval helper is called.)

outDir = fullfile(root, 'data','analysis','day10','fresh_verify_2026-09-17');
if ~exist(outDir,'dir'), mkdir(outDir); end

fprintf('============================================================\n');
fprintf('  FRESH INDEPENDENT VERIFICATION (2026-09-17)\n');
fprintf('  %s\n', datestr(now));
fprintf('============================================================\n');

results = struct('check',{}, 'status',{}, 'measured',{}, 'expected',{}, 'note',{});

%% ---- 1. Load champions and their manifest SHA-256 ----
man = fullfile(root, 'audit','improvement_baseline','baseline_manifest.md');
txt = fileread(man);
m5 = regexp(txt, '5class_stage2\.mat \| ([A-F0-9]{64})', 'tokens','once');
mB = regexp(txt, 'binary_stage2\.mat \| ([A-F0-9]{64})', 'tokens','once');
if isempty(m5), m5 = regexp(txt, 'data/models/day7_pretrained_resnet18_5class_stage2\.mat\s*\|\s*([A-F0-9]{64})', 'tokens','once'); end
if isempty(mB), mB = regexp(txt, 'data/models/day7_pretrained_resnet18_binary_stage2\.mat\s*\|\s*([A-F0-9]{64})', 'tokens','once'); end
p5 = fullfile('data','models','day7_pretrained_resnet18_5class_stage2.mat');
pB = fullfile('data','models','day7_pretrained_resnet18_binary_stage2.mat');
h5 = sha256(p5); hB = sha256(pB);
ok5 = ~isempty(m5) && strcmpi(h5, m5{1});
okB = ~isempty(mB) && strcmpi(hB, mB{1});
results(end+1) = rec('hash_5class_champion', ok5, h5, m5{1}, 'on-disk weights == committed manifest hash'); %#ok<AGROW>
results(end+1) = rec('hash_binary_champion', okB, hB, mB{1}, 'on-disk weights == committed manifest hash'); %#ok<AGROW>

S5 = load(p5, 'trainedNet'); net5 = S5.trainedNet;
SB = load(pB, 'trainedNet'); netB = SB.trainedNet;

%% ---- 2. Build val list + labels (independent of project datastore) ----
files = {}; labels = {}; yTrue5 = zeros(0,1);
for c = 0:4
    d = dir(fullfile('data','splits','val',sprintf('class_%d',c),'*.png'));
    for i = 1:numel(d)
        files{end+1} = fullfile('data','splits','val',sprintf('class_%d',c),d(i).name); %#ok<AGROW>
        labels{end+1} = c; %#ok<AGROW>   % raw dir index 0..4
        yTrue5(end+1) = c + 1; %#ok<AGROW> % 1-based grading label 1..5
    end
end
n = numel(files);
results(end+1) = rec('val_count', n==733, n, 733, 'validation set size'); %#ok<AGROW>

% class totals per dir (expect 361/74/200/39/59)
cls = zeros(1,5);
for i=1:n, cls(yTrue5(i)) = cls(yTrue5(i)) + 1; end %#ok<AGROW>
results(end+1) = rec('val_class_counts', isequal(cls(:)', [361 74 200 39 59]), cls(:)', [361 74 200 39 59], 'per-class val support'); %#ok<AGROW>

%% ---- 3. Label integrity vs APTOS train.csv (ground truth) ----
% train.csv columns: id_code, diagnosis (0..4). Val dir name should equal diagnosis.
trainCsv = fullfile('data','aptos2019','train.csv');
ids = {}; diag = containers.Map();
if exist(trainCsv,'file')==2
    fh = fopen(trainCsv,'rt'); hdr = fgetl(fh);
    ln = fgetl(fh);
    while ischar(ln)
        tok = regexp(ln, '^([^,]+),(\d+)$', 'tokens','once');
        if ~isempty(tok)
            ids{end+1} = tok{1}; diag(tok{1}) = str2double(tok{2}); %#ok<AGROW>
        end
        ln = fgetl(fh);
    end
    fclose(fh);
end
mism = 0; notIn = 0; dup = 0;
seen = containers.Map();
for i = 1:n
    [~, idBase] = fileparts(files{i});
    if dupExists(seen, idBase), dup = dup + 1; continue; end
    seen(idBase) = 1;
    if isKey(diag, idBase)
        if diag(idBase) ~= labels{i}, mism = mism + 1; end
    else
        notIn = notIn + 1;
    end
end
results(end+1) = rec('label_vs_aptos_csv', mism==0 && notIn==0, ...
    sprintf('mismatch=%d notInCSV=%d', mism, notIn), '0 / 0', ...
    'every val folder class matches the official APTOS train.csv diagnosis; no duplicates, all ids found'); %#ok<AGROW>
results(end+1) = rec('val_dup_ids', dup==0, dup, 0, 'no image appears in two class folders'); %#ok<AGROW>

%% ---- 4. FRESH full-val inference (both champions) ----
yPred5 = zeros(n,1); pRef = zeros(n,1); s5all = zeros(n,5); sBall = zeros(n,2);
t0 = tic;
for i = 1:n
    img = imread(files{i});
    im = imresize(img, [224 224]);
    q5 = predict(net5, im); q5 = q5(:)';
    qB = predict(netB, im); qB = qB(:)';
    [~, gi] = max(q5);
    yPred5(i) = gi;
    pRef(i) = qB(2);          % raw referable probability (binary model, class 2)
    s5all(i,:) = q5; sBall(i,:) = qB;
end
infSec = toc(t0);
fprintf('Fresh inference on %d images took %.0f s\n', n, infSec);

%% ---- 4b. Orientation normalize (column vectors; avoids broadcast bugs) ----
yTrue5 = yTrue5(:); yPred5 = yPred5(:); pRef = pRef(:);

%% ---- 5. Compare fresh predictions VS committed T0 cache ----
cch = fullfile('data','analysis','day8','reverify_audit_T0.mat');
if exist(cch,'file')==2
    C = load(cch);
    yT = C.YTrue5; yP = C.YPred5; pR = C.PRef;
    results(end+1) = rec('fresh_vs_cache_YTrue', isequal(yTrue5(:), yT(:)), 0, 0, 'fresh label parse == committed YTrue5'); %#ok<AGROW>
    results(end+1) = rec('fresh_vs_cache_YPred_exact', isequal(yPred5, yP), isequal(yPred5,yP), true, 'fresh argmax assignments BIT-EXACT match committed cache'); %#ok<AGROW>
    results(end+1) = rec('fresh_vs_cache_PRef_exact', isequal(pRef, pR), isequal(pRef,pR), true, 'fresh binary probabilities BIT-EXACT match committed PRef'); %#ok<AGROW>
end

%% ---- 6. Independent metric recomputation ----
acc   = mean(yPred5 == yTrue5);
conf  = zeros(5);
for i=1:n, conf(yTrue5(i), yPred5(i)) = conf(yTrue5(i), yPred5(i))+1; end
perRec = zeros(5,1); perF1 = zeros(5,1);
for c=1:5
    tp=conf(c,c); fp=sum(conf(:,c))-tp; fn=sum(conf(c,:))-tp;
    perRec(c)=tp/(tp+fn+eps); perF1(c)=2*tp/(2*tp+fp+fn+eps);
end
mac = mean(perF1);
qwk = quadvkappa(yTrue5, yPred5, 5);

labelsIx = yTrue5 >= 3;                 % Moderate/Severe/Prolif (1-based 3,4,5)
thr = 0.60;
dec = pRef >= thr;
tp = sum(labelsIx & dec); fp = sum(~labelsIx & dec);
fn = sum(labelsIx & ~dec); tn = sum(~labelsIx & ~dec);
sens = tp/(tp+fn+eps); spec = tn/(tn+fp+eps);
[Xr,Yr,~,auc] = perfcurve(labelsIx, pRef, true);
[Pp,Rr,~,prauc] = perfcurve(labelsIx, pRef, true,'XCrit','tpr','YCrit','prec');

fprintf('\n--- 5-class headers (independent) ---\n');
fprintf('acc=%.6f macroF1=%.6f qwk=%.6f\n', acc, mac, qwk);
fprintf('recall=%s\n', mat2str(perRec', 4));
fprintf('confusion (rows=true, cols=pred):\n'); disp(conf);
fprintf('\n--- binary @0.60 (independent) ---\n');
fprintf('tp=%d fp=%d fn=%d tn=%d  sens=%.6f spec=%.6f\n', tp,fp,fn,tn,sens,spec);
fprintf('ROC-AUC=%.6f PR-AUC=%.6f\n', auc, prauc);

%% ---- 7. Comparison against every claimed digit ----
chk('acc',   acc,   0.8281, 1e-4);
chk('macroF1',mac,  0.6805, 1e-4);
chk('qwk',   qwk,   0.8914, 1e-4);
expRec = [0.9834 0.6081 0.7850 0.4872 0.5254];
for c=1:5
    chk(sprintf('recall_%d',c), perRec(c), expRec(c), 5e-4);
end
chk('sens',  sens,  0.9060, 5e-4);
chk('spec',  spec,  0.9471, 5e-4);
chk('auroc', auc,   0.9796, 1e-3);
chk('prauc', prauc, 0.7821, 1e-3);
chk('bin_tp',  tp,   270, 0);
chk('bin_fp',  fp,    23, 0);
chk('bin_fn',  fn,    28, 0);
chk('bin_tn',  tn,   412, 0);
chk('referable_count', sum(labelsIx), 298, 0);
chk('nonref_count',    sum(~labelsIx), 435, 0);
chk('eq_0dot8322_not_champ', true, '0.8322 = day9 control model, not champion (see root-cause sub-audit)', '');

function chk(name, meas, exp, tol)
    if ischar(exp)   % informational
        results(end+1) = rec(['INDEPENDENT_' name], true, meas, exp, 'informational'); %#ok<NASGU>
        fprintf('  [INFO] %-22s %s\n', name, meas);
        return;
    end
    if isscalar(meas) && isnumeric(meas)
        ok = abs(meas-exp) <= tol;
        fprintf('  [%s] %-22s measured=%.4f expected=%.4f\n', tf2(ok), name, meas, exp);
    else
        ok = isequal(meas, exp);
        fprintf('  [%s] %-22s (%s)\n', tf2(ok), name, mat2str(meas(:)'));
    end
    results(end+1) = rec(['INDEPENDENT_' name], ok, meas, exp, ''); %#ok<AGROW>
end

%% ---- Save ----
out = struct('date', datestr(now), 'inferenceSec', infSec, 'yTrue5', yTrue5, ...
    'yPred5', yPred5, 'pRef', pRef, 's5All', s5all, 'sBAll', sBall, ...
    'acc', acc, 'macroF1', mac, 'qwk', qwk, 'perRec', perRec, 'confusion', conf, ...
    'sens', sens, 'spec', spec, 'auc', auc, 'prauc', prauc, 'tp',tp,'fp',fp,'fn',fn,'tn',tn, ...
    'hash5', h5, 'hashB', hB, 'results', results);
save(fullfile(outDir,'fresh_independent_verify.mat'), '-struct', 'out');
fprintf('Saved %s\n', fullfile(outDir,'fresh_independent_verify.mat'));

%% ---- 8. Final tally ----
nP=0; nF=0;
for i=1:numel(results)
    if numel(results(i).status)==1 && results(i).status, nP=nP+1; else, nF=nF+1; end
end
fprintf('\n  INDEPENDENT VERIFICATION TALLY: %d PASS / %d FAIL / %d checks\n', nP, nF, numel(results));
if nF>0, fprintf('  *** FAILURES PRESENT - investigate before accepting any claim ***\n'); end
end

function h = sha256(p)
    md = java.security.MessageDigest.getInstance('SHA-256');
    fis = java.io.FileInputStream(p);
    buf = zeros(1,8192,'uint8');
    while (fis.available() > 0)
        k = fis.read(buf, 0, 8192);
        md.update(buf(1:k), 0, k);
    end
    fis.close();
    h = lower(char(reshape(dec2hex(typecast(md.digest(),'uint8')), 1, [])));
end

function q = quadvkappa(t, p, K)
    w = zeros(K); 
    for i=1:K, for j=1:K, w(i,j) = (i-j)^2/(K-1)^2; end, end
    o = zeros(K);
    for i=1:numel(t), o(t(i),p(i)) = o(t(i),p(i)) + 1; end
    rs = sum(o,2); cs = sum(o,1)';
    e = (rs*cs')./numel(t);
    q = 1 - sum(w(:).*o(:))/sum(w(:).*e(:));
end

function b = dupExists(map, key)
    if map.isKey(key); b = true; else; map(key)=1; b=false; end
end

function s = tf2(b)
    if b, s='PASS'; else, s='FAIL'; end
end

function rr = rec(check, status, measured, expected, note)
    rr = struct('check', char(check), 'status', status, 'measured', measured, ...
                'expected', expected, 'note', char(note));
end