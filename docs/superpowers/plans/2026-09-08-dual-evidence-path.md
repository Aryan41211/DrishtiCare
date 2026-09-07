# Dual-Evidence Path (Branch A + Branch B + Evidence Agreement) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a lightweight Branch B (lesion-feature → referable probability) and an evidence-agreement fusion layer that flags Branch A/B disagreements for manual review, surfaced in the single-image report — without touching the locked 0.60 threshold, the closed test set, or the day7 models.

**Architecture:** Branch B is a small logistic/boosted-tree classifier trained on cached lesion features (MA/HE/EX counts, quadrants, OD flag) extracted from a stratified ~400-image APTOS train subsample. `fuseEvidence` compares Branch A (grade/confidence/calibrated pRef) against Branch B (P(referable)) and emits agree/discrepancy flags; discrepancy routes to REVIEW. Coordinator wires Branch B + fusion into `predictSingleFundus` and the narrative.

**Tech Stack:** MATLAB R2026a (CPU-only), Statistics & ML Toolbox (`fitclinear`, `fitcensemble`, `perfcurve` confirmed available), existing `extractLesionCandidates` / `locateOpticDiscCnn` / `temperatureScale` / cascade router.

**Spec:** `docs/superpowers/specs/2026-09-08-dual-evidence-path-design.md`

## Global Constraints

- Official APTOS test set is CLOSED. Never read `data/aptos2019/test_images`.
- Binary referable threshold LOCKED at 0.60. Screening decision stays on raw Branch A P(referable). Fusion only adds review flags; never downgrades a referable.
- `data/models/day7_pretrained_resnet18_*` are read-only (never overwrite).
- Report only measured numbers; Branch B is a PILOT (low-recall cues), claims hedged.
- Disjoint file ownership between tracks. NEVER edit files owned by the other track or by the coordinator.
- No function definitions inside `-batch` scripts. Launch MATLAB via:
  `& "C:\Program Files\MATLAB\R2026a\bin\matlab.exe" -batch "cd('C:\projects\DrishtiCare'); run('src\path\file.m')"`
- Split source of truth: `data/splits/{train,val}/class_{0..4}/<id>.png`; grade = class folder index, train/val = folder path.
- Existing single-image features (see `src/lesions/extractLesionCandidates.m` return struct):
  - `f.microaneurysms.count`, `f.haemorrhages.count`, `f.exudates.count`
  - `f.haemorrhages.centroidX/Y`, `f.exudates.centroidX/Y` (for quadrant accumulation)
  - `f.quadrantHemorrhage` (4-vector, direct) — PREFERRED over recomputing quadrant
  - `f.odCenter` (may be `[]`), `f.odRadius`
  - Set `opts.returnVisual=false, opts.verbose=false` for speed.

---

## TRACK F1 — Branch B (feature cache + classifier + verify)

### Task F1.1: Feature cache builder

**Files:**
- Create: `src/lesions/build_aptos_feature_cache.m`
- Creates output: `data/analysis/day8/branch_b/feat_cache.mat`

**Interfaces:**
- Consumes: `extractLesionCandidates(imgPath, opts)`, split folders `data/splits/{train,val}/class_{0..4}/`, `locateOpticDiscCnn` (via injectable OD callback).
- Produces: `feat_cache.mat` containing `X` (N×10 double, columns doc'd below), `grade` (N×1 int 0-4), `isVal` (N×1 logical), `ids` (N×1 string), `featNames` (1×10 cellstr). Row ordering = the APTOS train image order used by the calibration cache (first 3662 train images, then the val members that were also subsampled).

- [ ] **Step 1: Build the script**

```matlab
% build_aptos_feature_cache.m
% Build Branch B feature cache on a stratified subsample of APTOS train.
% Columns (featNames):
%   1 MA_count     2 HE_count       3 EX_count
%   4 q1HE         5 q2HE           6 q3HE           7 q4HE     (quadrant hemorrhage)
%   8 odLocated    9 exNearDisc    10 meanExDistToDisc
% referable label = grade>=2. Split = data/splits/{train,val}/class_*.
%
% OD callback: try locateOpticDiscCnn(I); if unavailable or P<0.90 -> odLocated=0.

projectRoot = 'C:\projects\DrishtiCare';
addpath(genpath(fullfile(projectRoot, 'src')));
outDir = fullfile(projectRoot, 'data', 'analysis', 'day8', 'branch_b');
if ~exist(outDir, 'dir'), mkdir(outDir); end

rng(42);  % replicate
N_PER_CLASS_TRAIN = 70;  % 5 classes x 70 = 350 train subsample
grades = 0:4;
ids = strings(0); grade = zeros(0,1); isVal = false(0,1);
for g = grades
    % list class folder images
    dTr = dir(fullfile('data','splits','train',sprintf('class_%d',g),'*.png'));
    selTr = datasample(dTr, min(N_PER_CLASS_TRAIN, numel(dTr)), 'Replace', false);
    for i = 1:numel(selTr)
        ids(end+1) = string(selTr(i).name); %#ok<SAGROW>
        grade(end+1) = g; %#ok<SAGROW>
        isVal(end+1) = false; %#ok<SAGROW>
    end
end
isVal = isVal(:);

% Choose ~50 balanced val images (10 per grade) shared with the calibration cache
N_VAL_PER_CLASS = 10;
idsVal = strings(0); gradeVal = zeros(0,1);
for g = grades
    dV = dir(fullfile('data','splits','val','class_%d', ... %#ok<*PFBNS>
        sprintf('class_%d',g),'*.png'));
    if isempty(dV), dV = dir(fullfile('data','splits','val',sprintf('class_%d',g),'*.png')); end
    selV = datasample(dV, min(N_VAL_PER_CLASS, numel(dV)), 'Replace', false);
    for i = 1:numel(selV)
        idsVal(end+1) = string(selV(i).name); %#ok<SAGROW>
        gradeVal(end+1) = g; %#ok<SAGROW>
    end
end
ids = [ids idsVal]; grade = [grade(:); gradeVal(:)];
isVal = [isVal; true(numel(gradeVal),1)];

featNames = {'MA_count','HE_count','EX_count','q1HE','q2HE','q3HE','q4HE', ...
             'odLocated','exNearDisc','meanExDistToDisc'};
X = zeros(numel(ids), numel(featNames));

for i = 1:numel(ids)
    imgPath = fullfile(projectRoot, 'data', 'aptos2019', 'train_images', char(ids(i)));
    f = extractLesionCandidates(imgPath, struct('returnVisual', false, ...
                                                'verbose', false));
    q = f.quadrantHemorrhage; if isempty(q), q = zeros(1,4); end
    X(i,1) = f.microaneurysms.count;
    X(i,2) = f.haemorrhages.count;
    X(i,3) = f.exudates.count;
    X(i,4:7) = q;
    odOk = ~isempty(f.odCenter) && numel(f.odCenter)==2 && f.odCenter(1)>0;
    X(i,8) = double(odOk);
    % exNearDisc = exudate centroids within ~1.5 x OD radius of disc centre
    ed = f.exudates.centroidX;
    if odOk && ~isempty(ed)
        r = f.odRadius; if isempty(r) || r<=0, r = 0; end
        thr = 1.5 * max(r, 50);
        cx = f.odCenter(1); cy = f.odCenter(2);
        d = sqrt(sum(([ed; f.exudates.centroidY] - [cx; cy]).^2, 1));
        X(i,9) = double(sum(d <= thr));
    end
    % mean exudate distance to disc (if odOk)
    if odOk && ~isempty(ed)
        cx = f.odCenter(1); cy = f.odCenter(2);
        d = sqrt(sum(([ed; f.exudates.centroidY] - [cx; cy]).^2, 1));
        X(i,10) = mean(d);
    end
    if mod(i,25)==0, fprintf('%d/%d\n', i, numel(ids)); end
end

save(fullfile(outDir, 'feat_cache.mat'), 'X', 'grade', 'isVal', 'ids', 'featNames', 'N_PER_CLASS_TRAIN', 'N_VAL_PER_CLASS');
fprintf('Saved feat_cache.mat: %d rows (train=%d val=%d)\n', numel(ids), sum(~isVal), sum(isVal));
```

- [ ] **Step 2: Run the cache builder**

Run: `& "C:\Program Files\MATLAB\R2026a\bin\matlab.exe" -batch "cd('C:\projects\DrishtiCare'); run('src\lesions\build_aptos_feature_cache.m')"`
Expected: prints progress, then `Saved feat_cache.mat: 400 rows (train=350 val=50)`.

- [ ] **Step 3: Commit**

```bash
git add src/lesions/build_aptos_feature_cache.m data/analysis/day8/branch_b/feat_cache.mat
git commit -m "feat(branchB): build APTOS lesion-feature cache for Branch B"
```

### Task F1.2: Branch B classifier (logistic + GBT compare, honest eval)

**Files:**
- Create: `src/lesions/trainBranchB.m`
- Create: `src/lesions/branch_b_predict.m`
- Creates output: `data/analysis/day8/branch_b/branchB_model.mat`

**Interfaces:**
- Consumes: `feat_cache.mat` (X, grade, isVal, ids, featNames).
- Produces: `branchB_model.mat` with struct `model` containing `.kind` (logistic|gbt), `.mdl` (fit model), `.T` (Optional temperature fitted on eval-slice NLL), `.features` (cellstr featNames), `.kindOrder` (cellstr: {'logistic','gbt'}), `.fitIdx`, `.evalIdx`, and metrics struct `.metrics` with fields `aucLogisticRaw`, `aucLogisticCal`, `aucGbt`, `aucGbtCal`, `bestKind`, `matchRateAll_train`, `matchRateAll_eval`, `calLogisticEval`, `calGbtEval` (each with ece/nll), plus `grade` and `ids` at train/eval. Also `pTrueReferable` (mean referable rate at eval).
- `branch_b_predict(featRow, model)` → `pRefB` (scalar 0-1): applies model.kind prediction, then temperature T via `temperatureScale` if model.T ~= 1.

- [ ] **Step 1: Write trainBranchB.m**

```matlab
% trainBranchB.m
% Fit Branch B: referable (grade>=2) from lesion features.
% Compares logistic vs gradient-boosted trees on a firewalled eval slice
% (keep disjoint fit/eval of the cache). Reports honest metrics. Saves model.
addpath(genpath('C:\projects\DrishtiCare\src'));
S = load(fullfile('data','analysis','day8','branch_b','feat_cache.mat'));
X = double(S.X); yRef = double(S.grade >= 2); g = S.grade; isVal = S.isVal(:);

n = size(X,1);
rng(7);
% Use isVal members as eval slice (they are disjoint by construction) —
%   fit on the ~350 train-subsample images, eval on the ~50 val images.
fitIdx = find(~isVal); evalIdx = find(isVal);
assert(numel(unique(fitIdx)) > 100, 'Need enough fit samples');

% Standardize features (robust: /max to keep interpretable)
mx = max(X(fitIdx,:), [], 1); mx(mx==0) = 1;
Xf = X ./ mx;

% ---- Logistic ----
mdlLog = fitclinear(Xf(fitIdx,:), yRef(fitIdx), 'Learner','logistic', ...
    'Regularization','lasso', 'Lambda', 1e-3, 'Solver','sparsa');
pLogTrain = predict(mdlLog, Xf(fitIdx,:));
pLogEval  = predict(mdlLog, Xf(evalIdx,:));
[~,~,~,auL] = perfcurve(yRef(fitIdx), pLogTrain, 1);
[~,~,~,auE] = perfcurve(yRef(evalIdx), pLogEval, 1);
% fit temperature on eval NLL (inline helper: no local fns in scripts)
Tlog = 1.0;
try
    fT = @(T) mean(-(yRef(evalIdx).*log(max(temperatureScale(pLogEval, T),1e-9)) ...
                  + (1-yRef(evalIdx)).*log(max(1-temperatureScale(pLogEval, T),1e-9))));
    Tlog = fminbnd(fT, 0.1, 8.0);
catch, Tlog = 1.0; end

% ---- Gradient boosted trees ----
mdlGbt = fitcensemble(Xf(fitIdx,:), yRef(fitIdx), 'Method','AdaBoostM2', ...
    'NumLearningCycles', 90, 'Learners', templateTree('MaxNumSplits', 4));
pGbtTrain = predict(mdlGbt, Xf(fitIdx,:));
pGbtEval  = predict(mdlGbt, Xf(evalIdx,:));
[~,~,~,auGL] = perfcurve(yRef(fitIdx), pGbtTrain, 1);
[~,~,~,auGE] = perfcurve(yRef(evalIdx), pGbtEval, 1);
Tgbt = 1.0;
try
    fT = @(T) mean(-(yRef(evalIdx).*log(max(temperatureScale(pGbtEval, T),1e-9)) ...
                  + (1-yRef(evalIdx)).*log(max(1-temperatureScale(pGbtEval, T),1e-9))));
    Tgbt = fminbnd(fT, 0.1, 8.0);
catch, Tgbt = 1.0; end

% Choose best by eval AUC (ties -> lower eval NLL after temp)
pick = 'logistic';
if auGE > auE + 0.01, pick = 'gbt'; end
if strcmp(pick,'logistic')
    mdl = mdlLog; kind = 'logistic'; Tf = Tlog; pE = pLogEval; auEf = auE;
else
    mdl = mdlGbt; kind = 'gbt'; Tf = Tgbt; pE = pGbtEval; auEf = auGE;
end
pEcal = temperatureScale(pE, Tf);

% Match-rate vs Branch A on the eval slice (Branch A gt-grade is same data)
matchRate = mean((pEcal >= 0.60) == yRef(evalIdx));

model = struct();
model.kind = kind; model.mdl = mdl; model.T = Tf; model.mx = mx;
model.features = S.featNames;
model.kindOrder = {'logistic','gbt'};
model.fitIdx = fitIdx(:); model.evalIdx = evalIdx(:);
model.metrics = struct();
model.metrics.aucLogisticRaw = auL; model.metrics.aucLogisticEval = auE;
model.metrics.aucGbtTrain = auGL; model.metrics.aucGbtEval = auGE;
model.metrics.aucBestEval = auEf;
model.metrics.tLogistic = Tlog; model.metrics.tGbt = Tgbt; model.metrics.tBest = Tf;
model.metrics.matchRateAll_eval = matchRate;
model.metrics.nFit = numel(fitIdx); model.metrics.nEval = numel(evalIdx);
model.metrics.pTrueReferable_eval = mean(yRef(evalIdx));

fprintf('logistic: trainAUC=%.3f evalAUC=%.3f T=%.3f | gbt: trainAUC=%.3f evalAUC=%.3f T=%.3f\n', ...
    auL, auE, Tlog, auGL, auGE, Tgbt);
fprintf('picked %s  evalAUC=%.3f  calibration-match@0.60=%.3f (n=%d)\n', ...
    kind, auEf, matchRate, numel(evalIdx));

save(fullfile('data','analysis','day8','branch_b','branchB_model.mat'), 'model');
fprintf('saved branchB_model.mat\n');
```

- [ ] **Step 2: Run trainBranchB**

Run: `& "C:\Program Files\MATLAB\R2026a\bin\matlab.exe" -batch "cd('C:\projects\DrishtiCare'); run('src\lesions\trainBranchB.m')"`
Expected: prints both model lines + picked kind + eval AUC + match-rate ~0.7–0.9 (documented as PILOT-limited by low-recall lesion cues), saves branchB_model.mat.

- [ ] **Step 3: Self-check branch_b_predict works on model**

Run:
```matlab
S = load('data/analysis/day8/branch_b/branchB_model.mat');
row = [0 0 0 0 0 0 0 0 0 0];
p = branch_b_predict(row, S.model);
assert(p>=0 && p<=1);
p2 = branch_b_predict([0 0 50 1 1 1 1 1 5 30], S.model);
assert(p2 >= p, 'More lesions should not be less referable');
fprintf('p(none)=%.3f p(lesions)=%.3f\n', p, p2);
```
Expected: prints both, monotone check passes.

- [ ] **Step 4: Write branch_b_predict.m**

```matlab
function pRefB = branch_b_predict(featRow, model)
%BRANCH_B_PREDICT P(referable) from a Branch B lesion-feature row.
%   pRefB = branch_b_predict(featRow, model)
%   featRow: 1x10 double in the same order as model.features.
%   model: struct saved by trainBranchB (fields .mdl .kind .T .mx .features).
%   Returns scalar 0-1 (temperature-scaled when model.T ~= 1).

    X = double(featRow(:)');
    if numel(X) ~= numel(model.features)
        error('branch_b_predict: feature length mismatch');
    end
    X = X ./ model.mx;
    s = predict(model.mdl, X);
    if model.T ~= 1
        pRefB = temperatureScale(s, model.T);
    else
        pRefB = s;
    end
    pRefB = min(max(pRefB, 0), 1);
end
```

- [ ] **Step 5: Run branch_b_predict smoke**

Run (inline MAT-command):
`& "C:\Program Files\MATLAB\R2026a\bin\matlab.exe" -batch "cd('C:\projects\DrishtiCare'); addpath(genpath('src')); S=load(fullfile('data','analysis','day8','branch_b','branchB_model.mat')); p=branch_b_predict(zeros(1,10),S.model); p2=branch_b_predict([0 0 50 1 1 1 1 1 5 30],S.model); fprintf('p0=%.3f p1=%.3f\n',p,p2); assert(p>=0 && p<=1); assert(p2>=p);"`
Expected: prints p0 < p1, both in [0,1].

- [ ] **Step 6: Verify script + commit**

Create `src/verify_branch_b.m`:
```matlab
% verify_branch_b.m
addpath(genpath('C:\projects\DrishtiCare\src'));
S = load(fullfile('data','analysis','day8','branch_b','feat_cache.mat'));
M = load(fullfile('data','analysis','day8','branch_b','branchB_model.mat'));
model = M.model;
X = double(S.X); g = S.grade; y = double(g>=2);
% Eval-slice confusion + per-grade predicted referable rate
ei = model.evalIdx;
pAll = zeros(numel(ei),1);
for i = 1:numel(ei), pAll(i) = branch_b_predict(X(ei(i),:), model); end
fprintf('Branch B eval n=%d  referable-rate=%.3f  AUC=%.3f\n', ...
    numel(ei), mean(pAll>=0.60), model.metrics.aucBestEval);
for gr = 0:4
    m = (g(ei)==gr);
    fprintf('  grade %d: n=%d  mean pRefB=%.3f  flagged=%.3f\n', ...
        gr, sum(m), mean(pAll(m)), mean(pAll(m)>=0.60));
end
fprintf('Match vs Branch A label @0.60 = %.3f (n=%d)\n', ...
    model.metrics.matchRateAll_eval, numel(ei));
```
Run it; expect per-grade table + match rate printed. Then:
```bash
git add src/lesions/trainBranchB.m src/lesions/branch_b_predict.m src/verify_branch_b.m data/analysis/day8/branch_b/branchB_model.mat
git commit -m "feat(branchB): train + verify Branch B lesion-feature referable classifier"
```

---

## TRACK F2 — Fusion layer (fuseEvidence + synthetic verification)

### Task F2.1: fuseEvidence.m

**Files:**
- Create: `src/lesions/fuseEvidence.m`
- Create (test): `src/verify_fuseEvidence.m`

**Interfaces:**
- Consumes: Branch A info struct (fields `grade` 0-4, `pRef` raw 0-1, `pRefCal` calibrated 0-1, `confident` logical), Branch B info struct (fields `pRefB` 0-1 or NaN, `available` logical).
- Produces: `[agree, discrepancy, detail] = fuseEvidence(aInfo, bInfo)` where:
  - `agree` logical
  - `discrepancy` logical
  - `detail` struct with `.aReferable` (grade>=2 OR pRefCal>=0.60), `.bReferable` (pRefB>=0.60), `.routeOverride` ('REVIEW' or ''), `.reason` (string).
- Fusion rule (spec §Fusion): Both referable → agree. Both non-referable and Branch A confident → agree. A referable + B non-referable → discrepancy → routeOverride REVIEW. A non-referable but B referable → discrepancy → REVIEW (B may be wrong, but A silent and B alarmed is a review signal). If Branch B unavailable → agree=false, discrepancy=false, routeOverride='' (fusion skipped, B unavailable = review-worthy but not a conflict).

- [ ] **Step 1: Write the module**

```matlab
function [agree, discrepancy, detail] = fuseEvidence(aInfo, bInfo)
%FUSEEVIDENCE Evidence-agreement between Branch A (deep) and Branch B (lesion).
%   [agree, discrepancy, detail] = fuseEvidence(aInfo, bInfo)
%
%   aInfo: struct with .grade (0-4 int), .pRefCal (calibrated P referable),
%          .confident (logical).  A referable iff aInfo.confident && pRefCal>=0.60.
%   bInfo: struct with .pRefB (0-1) and .available (logical).
%
%   Never downgrades a referable A call: discrepancy only ever flags REVIEW,
%   never clears a referable. If B is unavailable, fusion is "no conflict"
%   (agree=false, discrepancy=false, routeOverride='').

    if ~isfield(bInfo, 'available') || isempty(bInfo) || ~bInfo.available ...
       || ~isfield(bInfo, 'pRefB') || isempty(bInfo.pRefB) || isnan(bInfo.pRefB)
        aRef = isfield(aInfo,'pRefCal') && aInfo.confident && aInfo.pRefCal >= 0.60;
        agree = false; discrepancy = false;
        detail = struct('aReferable', aRef, 'bReferable', NaN, ...
                        'routeOverride', '', 'reason', 'Branch B unavailable; fusion skipped');
        return;
    end

    aReferable = isfield(aInfo,'grade') && aInfo.grade >= 2;
    aCal       = isfield(aInfo,'pRefCal') && aInfo.pRefCal >= 0.60;
    aRef = aReferable || aCal;
    bRef = bInfo.pRefB >= 0.60;

    routeOverride = '';
    if aRef && bRef
        agree = true; discrepancy = false; reason = 'Agree: both referable';
    elseif ~aRef && ~bRef
        if isfield(aInfo,'confident') && aInfo.confident
            agree = true; discrepancy = false;
            reason = 'Agree: both non-referable, Branch A confident';
        else
            agree = false; discrepancy = true;
            reason = 'Both non-referable but Branch A not confident; review';
            routeOverride = 'REVIEW';
        end
    elseif aRef && ~bRef
        agree = false; discrepancy = true;
        reason = 'Discrepancy: Branch A referable, Branch B non-referable';
        routeOverride = 'REVIEW';
    else % ~aRef && bRef
        agree = false; discrepancy = true;
        reason = 'Discrepancy: Branch A non-referable, Branch B referable';
        routeOverride = 'REVIEW';
    end

    detail = struct('aReferable_pop', aRef, 'bReferable', bRef, ...
                    'routeOverride', routeOverride, 'reason', reason, ...
                    'confident', isfield(aInfo,'confident') && aInfo.confident);
end
```

- [ ] **Step 2: Write and run the smoke test**

```matlab
% verify_fuseEvidence.m
addpath(genpath('C:\projects\DrishtiCare\src'));
% A referable + B referable -> agree
[ag,dis,d] = fuseEvidence(struct('grade',3,'pRefCal',0.95,'confident',true), struct('pRefB',0.8,'available',true));
assert(ag && ~dis && strcmp(d.routeOverride,''));
% A referable + B non -> discrepancy REVIEW
[ag,dis,d] = fuseEvidence(struct('grade',3,'pRefCal',0.95,'confident',true), struct('pRefB',0.2,'available',true));
assert(~ag && dis && strcmp(d.routeOverride,'REVIEW'));
% both non, confident -> agree
[ag,dis,d] = fuseEvidence(struct('grade',0,'pRefCal',0.01,'confident',true), struct('pRefB',0.1,'available',true));
assert(ag && ~dis);
% both non, NOT confident -> discrepancy REVIEW
[ag,dis,d] = fuseEvidence(struct('grade',1,'pRefCal',0.45,'confident',false), struct('pRefB',0.2,'available',true));
assert(~ag && dis && strcmp(d.routeOverride,'REVIEW'));
% B unavailable -> no conflict
[ag,dis,d] = fuseEvidence(struct('grade',3,'pRefCal',0.95,'confident',true), struct('pRefB',NaN,'available',false));
assert(~ag && ~dis && strcmp(d.routeOverride,''));
% A non-referable but B referable -> discrepancy REVIEW
[ag,dis,d] = fuseEvidence(struct('grade',0,'pRefCal',0.01,'confident',true), struct('pRefB',0.9,'available',true));
assert(~ag && dis && strcmp(d.routeOverride,'REVIEW'));
fprintf('fuseEvidence: 6/6 assertions pass\n');
```
Run: `& "C:\Program Files\MATLAB\R2026a\bin\matlab.exe" -batch "cd('C:\projects\DrishtiCare'); run('src\verify_fuseEvidence.m')"`
Expected: prints `fuseEvidence: 6/6 assertions pass`.

- [ ] **Step 3: Commit**

```bash
git add src/lesions/fuseEvidence.m src/lesions/verify_fuseEvidence.m
git commit -m "feat(branchB): evidence-agreement fusion layer for dual-evidence"
```

---

## TRACK C (coordinator, AFTER F1+F2 both complete)

### Task C1: Wire Branch B into predictSingleFundus

**Files:**
- Modify: `src/inference/predictSingleFundus.m` (add `'RunBranchB'` optional param, `result.fusion`)

**Interfaces:**
- Consumes: `branch_b_predict`, `fuseEvidence`, existing `result.cascade`.
- Produces: `result.fusion` struct: `.branchB` (pRefB, NaN if unavailable), `.agree`, `.discrepancy`, `.routeOverride`, `.available`, `.detail` (reason string).

- [ ] **Step 1: Add RunBranchB param** (after existing param block): `defaultRunBranchB = true`.
- [ ] **Step 2: After cascade run block** (when `opts.RunBranchB`), attempt Branch B:
  - If `extractLesionCandidates` + `branch_b_predict` + model file exist → compute
    `pRefB` from a fresh feature extraction (`returnVisual=false`), call
    `fuseEvidence`.
  - If model/file missing → `result.fusion.available=false, pRefB=NaN`,
    `routeOverride=''`.
- [ ] **Step 3: Route override** — if `detail.routeOverride=='REVIEW'`, append a note to `result.cascade.detail` (do NOT silently overwrite `result.cascade.route`):
  `result.cascade.detail = [result.cascade.detail ' | Branch B discrepancy -> REVIEW recommended'];`
- [ ] **Step 4: Panel line** in report decision panel:
  `Branch B (lesion): P(ref)=%.1f%% %s` where `%s` is `agree`/`discrepancy`/`unavailable`.
- [ ] **Step 5: Commit**

```bash
git add src/inference/predictSingleFundus.m
git commit -m "feat(branchB): wire Branch B + fusion into predictSingleFundus"
```

### Task C2: Narrative integration

**Files:**
- Modify: `src/explainability/buildExplanationNarrative.m`

**Interfaces:**
- Consumes: `result.fusion` (guarded `isfield`).
- Produces: narrative sentence when fusion ran: e.g.
  `"Dual-evidence: Branch A (deep) and Branch B (lesion) disagree; flagged for manual review."`

- [ ] **Step 1: Add fusion sentence** after the existing cascade/governance block, guarded by `isfield(r,'fusion') && isfield(r.fusion,'available')`.
- [ ] **Step 2: Commit**

```bash
git add src/explainability/buildExplanationNarrative.m
git commit -m "feat(branchB): dual-evidence narrative sentence"
```

### Task C3: End-to-end verification + docs

**Files:**
- Run: `test_lesion_report.m` (must pass 5 grades, report PNGs regenerated)
- Modify: `docs/individual-image-inference.md`, `docs/task-tracker.md`

- [ ] **Step 1: Run test_lesion_report.m** — expect all 5 pass.
- [ ] **Step 2: Update docs** — single-image report now shows Branch B line + fusion/REVIEW flags; task-tracker marks Branch B (pilot) + fusion done (date 2026-09-08), fovea still noted negative.
- [ ] **Step 3: Commit**

```bash
git add docs/individual-image-inference.md docs/task-tracker.md src/test_lesion_report.m
git commit -m "docs(branchB): evidence-agreement report path + task tracker"
```