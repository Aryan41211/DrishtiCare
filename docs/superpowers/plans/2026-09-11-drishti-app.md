# DRISHTI Judge Demo App Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Upgrade `RetinaAIApp.m` (repo root) into the judge-ready DRISHTI screening demo (DRISHTI header, 4-view explainability, BORDERLINE mapping, WITHHELD reject path, report+PNG, checkpoint).

> *Path correction, 2026-09-25: this plan originally said
> `src/dashboard/RetinaAIApp.m`. The commit that added this plan (`4560f4b`)
> **also renamed the file to the repo root** (`src/dashboard/RetinaAIApp.m =>
> RetinaAIApp.m`), so every step below that names the old path is corrected
> inline. `src/dashboard/verify_retinaai.m` is unaffected and still exists.*


**Architecture:** Thin AppBase front-end calling only `predictSingleFundus()`; new view-cache state + switch buttons; `verify_retinaai.m` extended first (RED) then implementation (GREEN); checkpoint saver script writes `results/V2_DrishtiApp_checkpoint.mat`.

**Tech Stack:** MATLAB R2026a, App Designer (`matlab.apps.AppBase`), headless verify via `matlab -batch`.

**Spec:** `docs/superpowers/specs/2026-09-11-retina-ai-app-design.md` (display name is now DRISHTI, not RETINA-AI; class name `RetinaAIApp` stays to avoid breaking `launchRetinaAI.m` and verify scripts).

## Global Constraints

- Display name DRISHTI everywhere user-visible (figure title, header label, report header); class/file name `RetinaAIApp` unchanged.
- Quality badge text exactly `ACCEPT (PASS)` / `BORDERLINE (WARNING)` / `REJECT (FAIL)`.
- Wording: "Model Score", never "calibrated/confident"; "Model Attention Visualization", never "lesion detection"; thresholds labeled engineering prototypes.
- No lesion/vessel segmentation claims; no invented metrics; threshold 0.60 locked.
- REJECT path passes `'SkipModelOnFail', true` → WITHHELD, no grade, no Grad-CAM.
- Checkpoint `results/V2_DrishtiApp_checkpoint.mat` verified non-zero after save.

---

### Task 1: RED — extend headless verification with new expectations

**Files:**
- Modify: `src/dashboard/verify_retinaai.m`

**Interfaces:**
- Consumes: `RetinaAIApp` public `UIFigure`; `predictSingleFundus` result struct.
- Produces: failing assertions that Task 2 must satisfy (title `DRISHTI`; badge set `{'ACCEPT (PASS)','BORDERLINE (WARNING)','REJECT (FAIL)'}`; 4 view buttons with texts `{'Original','Enhanced','Grad-CAM','Overlay'}`; FAIL image yields `binaryDecision` starting `'WITHHELD'` and empty `gradCAM` in app result).

- [ ] **Step 1: Add title assertion**

```matlab
assert(strcmp(a.UIFigure.Name, 'DRISHTI'), 'title is DRISHTI');
```

- [ ] **Step 2: Add judge-terms badge + view-button assertions** (insert after existing section 3 badge check)

```matlab
badgeTexts = cell(numel(allLabels), 1);
for k = 1:numel(allLabels), badgeTexts{k} = char(allLabels(k).Text); end
assert(any(strcmp(badgeTexts, 'ACCEPT (PASS)') | strcmp(badgeTexts, 'BORDERLINE (WARNING)') | strcmp(badgeTexts, 'REJECT (FAIL)')), 'judge-terms quality badge');
viewBtns = findall(a.UIFigure, 'Type', 'uibutton');
viewTexts = cell(numel(viewBtns), 1);
for k = 1:numel(viewBtns), viewTexts{k} = char(viewBtns(k).Text); end
for v = {'Original', 'Enhanced', 'Grad-CAM', 'Overlay'}
    assert(any(strcmp(viewTexts, v{1})), ['view button missing: ' v{1}]);
end
```

- [ ] **Step 3: Add WITHHELD-on-FAIL contract check** (append before cleanup; uses a real FAIL image found by scanning val split, falls back to synthetic dark image)

```matlab
failPath = '';
clsDirs = {'class_0', 'class_1', 'class_2', 'class_3', 'class_4'};
for c = 1:numel(clsDirs)
    dd2 = dir(fullfile(projectRoot, 'data', 'splits', 'val', clsDirs{c}, '*.png'));
    for i = 1:min(6, numel(dd2))
        p2 = fullfile(projectRoot, 'data', 'splits', 'val', clsDirs{c}, dd2(i).name);
        q2 = assessImageQuality(imread(p2));
        if strcmp(q2.overall, 'FAIL'), failPath = p2; break; end
    end
    if ~isempty(failPath), break; end
end
assert(~isempty(failPath), 'a FAIL val image exists for the reject test');
rF = predictSingleFundus(failPath, 'ShowFigure', false, 'SkipModelOnFail', true);
assert(startsWith(rF.binaryDecision, 'WITHHELD'), 'FAIL decision withheld');
assert(isnan(rF.grade), 'FAIL grade withheld');
fprintf('OK  reject path verified on %s\n', failPath);
```

- [ ] **Step 4: Run and verify it FAILS for the right reason**

Run: `matlab -batch "run('src/dashboard/verify_retinaai.m')"` from `C:\projects\DrishtiCare`
Expected: FAIL on `title is DRISHTI` (current title is `RETINA-AI`), proving the test targets the new behavior.

- [ ] **Step 5: Commit test only**

```bash
git add src/dashboard/verify_retinaai.m
git commit -m "test(retinaai): DRISHTI title, judge-terms badge, 4-view buttons, WITHHELD reject path"
```

### Task 2: GREEN — upgrade RetinaAIApp.m to the DRISHTI demo

**Files:**
- Modify: `RetinaAIApp.m` *(repo root — was `src/dashboard/RetinaAIApp.m`; renamed in `4560f4b`)*

**Interfaces:**
- Consumes: `predictSingleFundus` fields listed in spec §3; `enhanceImage` output via pipeline `enhanced` display variable (recompute locally with `enhanceImage(raw)` for the Enhanced view — display only, never fed back to the model).
- Produces: private props `ViewOriginal`, `ViewEnhanced`, `ViewHeatmap`, `ViewOverlay` (uint8 HxWx3), `ViewButtons` (4 buttons), `EnhanceLabel`; methods `showView(name)`, `displayWithheld(r)`.

- [ ] **Step 1: Rename user-visible strings to DRISHTI**

Replace `'Name', 'RETINA-AI'` with `'Name', 'DRISHTI'`; header label `'RETINA-AI'` with `'DRISHTI'`; report header `'=== RETINA-AI Analysis Report ==='` with `'=== DRISHTI Analysis Report ==='`.

- [ ] **Step 2: Judge-terms quality badge + enhancement label**

```matlab
switch status
    case 'PASS',    badgeText = 'ACCEPT (PASS)';       badgeColor = [0.18 0.65 0.32];
    case 'WARNING', badgeText = 'BORDERLINE (WARNING)'; badgeColor = [0.85 0.65 0.13];
    case 'FAIL',    badgeText = 'REJECT (FAIL)';        badgeColor = [0.85 0.25 0.22];
end
```

Add `EnhanceLabel` under the quality panel: PASS → `'Enhancement: not required'`; WARNING → `'Adaptive enhancement: APPLIED (display aid — model input unchanged)'`; FAIL → `''`.

- [ ] **Step 3: Four-view explainability (cache + switch)**

In `analyzeCallback`, after `predictSingleFundus(..., 'SkipModelOnFail', true)`:
cache `raw` (from `imread`), `enh = enhanceImage(raw)`, heatmap `hm` recomputed via `gradcamExplain(net5...)`? NO — reuse `result.gradCAM` overlay only, and derive Grad-CAM-alone view as the red-channel-weighted map already inside overlay is not separable; instead compute `hm` with `gradCAM` on the loaded grade model for the predicted class (display only). Simpler correct approach: cache Original=raw, Enhanced=enh, Overlay=result.gradCAM, GradCAM=heatmap-only figure built with `ind2rgb`/`colormap` jet blended on black. Store all four in private props; `showView(name)` imshows the cached image on `GradCAMAxes`; default call `showView('Overlay')`.

- [ ] **Step 4: WITHHELD display path**

If `startsWith(r.binaryDecision, 'WITHHELD')`: grade labels show `'—'`, recommendation banner `'IMAGE NOT SUITABLE FOR ANALYSIS — recapture recommended'`, Grad-CAM axes text `'No Grad-CAM: analysis withheld (quality FAIL)'`, report records failure reasons + recapture advice, no grade/score lines.

- [ ] **Step 5: Report + Overlay PNG export**

`saveReportCallback` writes `.txt` as today plus `imwrite(app.ViewOverlay, [basename '_overlay.png'])` when non-empty; status line names both files.

- [ ] **Step 6: Run verification, expect PASS**

Run: `matlab -batch "run('src/dashboard/verify_retinaai.m')"` from `C:\projects\DrishtiCare`
Expected: `ALL RETINA-AI APP CHECKS PASS` with new OK lines.

- [ ] **Step 7: Commit**

```bash
git add RetinaAIApp.m
git commit -m "feat(retinaai): DRISHTI judge demo - 4-view explanation, judge-terms quality, WITHHELD reject path"
```

### Task 3: Checkpoint saver + results artifact

**Files:**
- Create: `src/dashboard/save_drishti_checkpoint.m`
- Create (generated): `results/V2_DrishtiApp_checkpoint.mat`

**Interfaces:**
- Consumes: `defaultQualityConfig()` (version string), model paths under `data/models/`, fixed threshold `0.60`, `res5b_relu` layer name.
- Produces: checkpoint `.mat` with `config` struct + `savedAt` datetime string; console line `CHECKPOINT_SAVED <bytes> bytes`.

- [ ] **Step 1: Write saver script**

```matlab
% save_drishti_checkpoint.m — write results/V2_DrishtiApp_checkpoint.mat
projectRoot = fileparts(fileparts(fileparts(mfilename('fullpath'))));
addpath(genpath(fullfile(projectRoot, 'src')));
qc = defaultQualityConfig();
config = struct('appName', 'DRISHTI', 'appClass', 'RetinaAIApp', ...
    'binaryThreshold', 0.60, 'skipModelOnFail', true, ...
    'gradcamLayer', 'res5b_relu', 'qualityConfigVersion', qc.version, ...
    'binaryModel', fullfile(projectRoot, 'data', 'models', 'day7_pretrained_resnet18_binary_stage2.mat'), ...
    'gradeModel', fullfile(projectRoot, 'data', 'models', 'day7_pretrained_resnet18_5class_stage2.mat'));
savedAt = char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'));
outDir = fullfile(projectRoot, 'results');
if ~exist(outDir, 'dir'), mkdir(outDir); end
outPath = fullfile(outDir, 'V2_DrishtiApp_checkpoint.mat');
save(outPath, 'config', 'savedAt', '-v7.3');
d = dir(outPath);
assert(d.bytes > 0, 'checkpoint non-empty');
fprintf('CHECKPOINT_SAVED %s (%d bytes)\n', outPath, d.bytes);
```

- [ ] **Step 2: Run saver, expect CHECKPOINT_SAVED with bytes > 0**

Run: `matlab -batch "run('src/dashboard/save_drishti_checkpoint.m')"`
Expected: `CHECKPOINT_SAVED ... (N bytes)`, N > 0.

- [ ] **Step 3: Commit script (not the .mat if gitignored — check .gitignore first; commit both if tracked)**

```bash
git add src/dashboard/save_drishti_checkpoint.m results/V2_DrishtiApp_checkpoint.mat
git commit -m "chore(retinaai): V2 DRISHTI app checkpoint"
```

### Task 4: Judge-flow rehearsal + packaging note

**Files:**
- Modify: `launchRetinaAI.m` (title string only: `'RETINA-AI - Screening App (demo)'` → `'DRISHTI - Screening App (demo)'`, and disp line).

- [ ] **Step 1: Rehearse 3 val images headlessly** (one PASS, one WARNING, one FAIL — reuse Task 1 scan; print quality/grade/route lines)

Run: `matlab -batch` snippet calling `predictSingleFundus` on the three images with the app's exact flags.
Expected: PASS→grade+REVIEW/CLEAR route; WARNING→grade+BORDERLINE badge data; FAIL→WITHHELD.

- [x] **Step 2: Choose and document the packaging path** (superseded 2026-09-25). The original step read: *"Document `.mlapp` packaging … open desktop MATLAB → `appdesigner('src/dashboard/RetinaAIApp.m')` → Save As `src/dashboard/RetinaAIApp.mlapp`. The `.m` remains source of truth."* **That path was not taken and the step is closed as superseded, not as unticked:** as of 2026-09-25 the repo contains **zero `.mlapp` files** (`Get-ChildItem -Recurse -Filter *.mlapp` → 0 hits), so leaving the checkbox open would have left a step that could never be completed. The packaging actually shipped is the **class file at the repo root plus the launcher**: `RetinaAIApp.m` (1,430 lines, `matlab.apps.AppBase`, the single source of truth) run via `launchRetinaAI.m`, which `addpath`s the root and `src/` recursively and instantiates the class. No App Designer Save-As step, no `.mlapp` artifact.

- [ ] **Step 3: Commit launcher string**

```bash
git add launchRetinaAI.m
git commit -m "chore(retinaai): rename demo header to DRISHTI"
```

## Self-review

Spec §2–§6 covered: T2 (layout/wording/4-view), T1+T2-Step4 (REJECT/WITHHELD), T2-Step5 (report), T3 (checkpoint), T4 (rehearsal+package). No placeholders: all code blocks concrete, paths exact, commands runnable. Type consistency: badge strings identical in T1 asserts and T2 implementation; `startsWith` used on `binaryDecision` char in both.
