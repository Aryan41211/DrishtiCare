# Retinal Blood Vessel Segmentation (classical prototype)

Status: research prototype — **not** a clinically validated system.

## Summary

Three classical Image Processing Toolbox pipelines have been evaluated on the
DRIVE dataset:

| method | DRIVE test Dice | Sens | Spec | Acc | Prec | AUC (FOV) |
|---|---|---|---|---|---|---|
| original `src\extractVessels.m` | 0.312 | 0.203 | 0.987 | 0.885 | 0.763 | — |
| phase-1 champion (`baseline_0.743`) | **0.7428** | 0.6829 | 0.9777 | 0.9390 | 0.8249 | 0.9029 |
| session champion (`champion` preset) | **0.7535** | 0.6947 | 0.9784 | 0.9413 | 0.8272 | 0.9029 |

Dice vs the 2nd manual observer: phase-1 0.7573, session champion 0.7713.
Human inter-observer Dice is ~0.790.

All numbers above come from the REAL `extractVessels` ran on the 20 DRIVE test
images, scored inside the field of view eroded by 5 px (primary GT =
`1st_manual`). They are reproducible:

```matlab
addpath('src\vessel');
img = imread('data\drive\DRIVE\test\images\05_test.tif');
fov = imerode(imread('data\drive\DRIVE\test\mask\05_test_mask.gif') > 0, ...
              strel('disk', 5));
vessels = extractVessels(img, vesselParams('champion'), 'fov', fov);
```

`vesselParams('baseline_0.743')` reproduces the phase-1 champion,
`vesselParams('champion')` the session champion.

## Two limitations you must know

1. **Test-set tuning limitation (phase-1).** The 0.743 phase-1 champion was
   tuned partly on DRIVE **test** images during earlier sessions. Its reported
   test numbers therefore likely overstate its generalization.

2. **Clean protocol (this session).** All optimization was done on the DRIVE
   **training** split (images 21–40, n = 20) used as a dev set. The champion
   config was locked using only dev metrics, then evaluated **once**
   on the DRIVE test split (images 01–20). No test image was used for tuning.

## Session experiment procedure

- Harness: `src\vessel\runVesselExperiments.m` (run with `runVesselExperiments()`;
  `runVesselExperiments(true)` is a 2-image smoke test).
- 43 round-1 experiments (preprocessing × enhancement/response channels ×
  threshold × cleanup × ensembles) + 21 round-2 refinements around the
  round-1 winner, all on the dev split.
- Champion rule: Dice -> Sensitivity -> Precision -> Specificity -> runtime.
- One locked evaluation on test.
- Cached per-image response "bank": multi-scale bottom-hat (radii 1–12),
  fibermetric (Frangi) thickness sets, a Chaudhuri-style matched filter
  (sigma 1.0/1.5/2.0, 12 orientations, own implementation), and a multi-
  orientation line operator (length 9/13).
- Outputs: `data\analysis\vessel\experiment_results.csv|.mat`,
  `vessel_ablation_table.csv`, `best_vessel_montage.png`,
  `vessel_error_analysis.png`, `metrics.txt`, `champion_config.mat`.
- `champion_config.mat` is read by `vesselParams('champion')`.

### What won

The winning change is **not** a new enhancement channel: the multi-scale
bottom-hat + Frangi-gate response (the phase-1 core) stayed best. Two small
changes lifted dev Dice from 0.7138 to 0.7276 (test 0.7428 → 0.7535):

1. **Density-based thresholding:** keep the brightest 15% of FOV pixels
   (`thresholdMethod = 'percentile'`, `thresholdFrac = 0.15`) instead of Otsu.
   More robust than a global intensity threshold because it is normalized by
   image content.
2. **Finer orientation sampling** in the noise-removing line opening:
   12 angles at 15° steps (`lineAngles = 0:15:165`) instead of 6 at 30°,
   which preserves a few more thin vessels.

Single-response makers did not beat the bottom-hat + Frangi-gate response:
matched filter alone ~0.55 Dice, line operator ~0.69, pure Frangi ~0.66.
Ensembles of these channels matched the baseline at best (0.7175 dev).

### AUC conventions (reconciliation)

The AUC of the segmentation response depends on which pixels are scored:

| convention | phase-1 (ev) | session |
|---|---|---|
| label pixels = eroded-FOV GT, scores = whole image | 0.9268 | — |
| labels and scores restricted to eroded FOV | — | 0.9029 |

Phase-1 reported 0.927 (its exact convention reproduces as 0.9268 here). The
harness reports 0.9029 (FOV-consistent, the same region used for every other
metric). Both are reported in `metrics.txt`; the response itself is identical
between the phase-1 and session champions, so the AUC is the same for both.

## Champion config (reproducible)

`vesselParams('champion')`:

- CLAHE: 8×8 tiles, clip 0.02 (green channel)
- multi-scale bottom-hat: disks [2 4 6 8]
- Frangi gate: thickness [3 4 5], polarity bright, weight 0.4
- threshold: `percentile`, FOV fraction 0.15
- cleanup: line opening length 9 at 0:15:165, close disk 2, minArea 40
- FOV: supplied mask or automatic (erode 15)

Phase-1 baseline differs only in: Otsu threshold (scale 1.0) and line angles
0:30:150.

## Files

- `src\vessel\extractVessels.m` — shipped segmenter (new: `percentile`
  threshold mode + `thresholdFrac`). Defaults unchanged = phase-1 baseline.
- `src\vessel\vesselParams.m` — named configs (`baseline_0.743`,
  `champion`, `legacy_broken`).
- `src\vessel\runVesselExperiments.m` — experiment harness.
- `src\vessel\evaluateVessels.m` — phase-1 DRIVE test evaluator (unchanged).
- `src\vessel\viewVessels.m` — interactive viewer (unchanged).
- `src\extractVessels.m` — original broken prototype (kept for reference).
- `data\analysis\vessel\*` — all outputs.

## Limitations

- Classical, CPU-only; ~2 s/image at 584×565.
- Does not segment capillaries that are below the resolution/contrast of the
  imaging (Sensitivity ~0.69; the GT observers mark them, classical methods
  cannot).
- `percentile` threshold assumes a well-defined FOV mask is available (DRIVE
  supplies one); with the automatic FOV the fraction is applied to that mask.
- DRIVE is a 20-image benchmark; no pathology diversity. Not validated for
  clinical use.

## Phase 3: visual-precision candidate (`extractVessels3`)

Goal: the session champion (~0.75 test Dice) still **looks** wrong on eyeballed
fundus stills - over-segmented around the optic disc, bright lesions/highlights
and illumination shading, even though area-weighted Dice stays high because
those FP clusters are a tiny pixel share. Phase 3 built a dedicated candidate
that attacks exactly those sources while keeping thin vessels, plus a root-cause
analysis to verify the assumption.

### Pipeline

`src\vessel\extractVessels3.m` = champion-equivalent enhancement (green ->
CLAHE -> multi-scale bottom-hat `[2 3 4 6 8]` -> mild Frangi gate
`[2 3 4 5 6]` @ 0.5) PLUS:

1. **FOV first** - every stage runs inside the retinal FOV, so the 
   threshold and the evaluation never see the black border.
2. **Safe flat-field** (leak-free Gaussian background + `regionfill`
   extrapolation; `flatFieldEnable`). Default **off**: experiments proved a
   strong global flat-field over-subtracts the low-contrast vessel band
   (dev Dice ~0.31 vs ~0.72 without it). Kept for extreme vignetting on
   non-DRIVE stills.
3. **Optic-disc-rim suppression** (`odEnable`): OD = largest bright, central
   blob (percentile + circularity + size/centre checks); the dilated rim
   **ring** is attenuated strongly (`odRingAtten = 0.05`), the disc interior
   only mildly (`odInteriorAtten = 0.85`) so the central retinal vessels
   survive.
4. **Bright-lesion / highlight suppression** (`brightEnable`): bright blobs
   above the 99th in-FOV percentile (excluding the OD) are dilated 3 px and
   the response beneath them attenuated to 5% (bottom-hat fires on the
   dark border of bright lesions).
5. **Percentile / adaptive threshold** (never one global level) then
   line-opening + closing + area cleanup (+ optional thin-vessel short
   line-opening and `bwmorph bridge`).

Config surface: `src\vessel\vesselParams3.m` (`'phase3'` /
`'phase3_default'`, `'phase3_locked'`). The runner is
`src\vessel\evaluatePhase3.m` (`evaluatePhase3()` = full run over the 20+20
DRIVE splits; `evaluatePhase3(true)` = 2+2 smoke).

### Results (locked, evaluated once on test)

Lock rule (dev-only): among candidates within 0.003 Dice of the strict best
(Dice -> Sens -> Prec -> Spec), pick the highest **precision** - the explicit
goal of this phase is fewer concentrated false positives. Dev best:
`p3_od_off` (0.7207 Dice; strict Dice-first pick agrees).

| method | test Dice | Sens | Spec | Acc | Prec | AUC (FOV) | AUC (full FOV) |
|---|---|---|---|---|---|---|---|
| session champion (`champion` preset) | **0.7549** | 0.7009 | 0.9774 | 0.9412 | 0.8220 | 0.9029 | 0.9223 |
| Phase-3 locked (`phase3_locked`) | 0.7438 | 0.6640 | **0.9826** | 0.9409 | **0.8498** | 0.8923 | 0.9117 |

2nd-manual observer Dice: locked 0.7278, champion 0.7573 (human ~0.790).

**Honest verdict:** on DRIVE the Phase-3 candidate does **not** beat the
champion's Dice (0.7438 vs 0.7549) - it trades ~0.011 Dice for +2.8 precision
(0.8498 vs 0.8220) and +0.5 specificity, i.e. it is visually cleaner but
less sensitive (misses more faint vessels). The OD suppression, tested on dev,
removed about as many *true* central vessels as the FP it killed, so the
locked config leaves that stage off. The full candidate (suppression on,
`phase3_default`) is available; its diagnostics figure shows the suppression
layers so the OD-ring effect can be judged directly.

### Root cause: why does the champion over-segment visually? (dev, n = 20)

False positives of the champion measured inside the eroded FOV, bucketed by
the Phase-3 candidate's OWN suppression regions:

| bucket | FP rate | lift vs overall | share of total FP |
|---|---|---|---|
| OD-region (disc + rim ring) | 0.0254 | **1.58x** | 16% |
| bright-lesion neighbourhood | 0.0128 | 0.80x | 0% |
| FOV rim band | 0.0085 | 0.53x | 4% |
| rest (diffuse background) | 0.0156 | 0.97x | 80% |

Conclusions:

- The optic-disc **edge** is a real, 1.58x-concentrated FP source - it matches
  the visual complaint and the OD-rim suppression is mechanistically the right
  fix for eyeballed stills (even though DRIVE metrics only weakly reward it).
- Bright lesions and the FOV rim are already cheap (0.80x / 0.53x) - those do
  **not** drive the DRIVE FP.
- ~80% of the champion's FP are **diffuse** background texture spread over the
  whole FOV, which no localised suppression can remove; that residual is the
  gap between Dice and visual judgement.

### Phase-3 files

- `src\vessel\extractVessels3.m` - candidate segmenter (champion untouched).
- `src\vessel\vesselParams3.m` - candidate presets (`phase3_default`,
  `phase3`, `phase3_locked`).
- `src\vessel\evaluatePhase3.m` - dev sweep -> lock -> single test eval,
  montages, diagnostics, FP root-cause analysis.
- `data\analysis\vessel\phase3\` - `phase3_dev_table.csv`,
  `phase3_results.csv|.mat`, `phase3_montage.png`,
  `phase3_error_analysis.png`, `phase3_diagnostics.png`, `fp_analysis.png|csv`,
  `phase3_locked_config.mat`, `metrics.txt`.

### Reproduce the Phase-3 candidate on one image

```matlab
addpath('src\vessel');
cfg  = vesselParams3('phase3_locked');
img  = imread('data\drive\DRIVE\test\images\05_test.tif');
fov  = imread('data\drive\DRIVE\test\mask\05_test_mask.gif') > 0;
[vessels, response, fovUsed, dbg] = extractVessels3(img, cfg, 'fov', fov);
imshow(imoverlay(img, vessels, [1 0 0]));
```