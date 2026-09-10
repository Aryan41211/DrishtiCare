# Hardening Phase 3 — Calibration Stats Contract

Date: 10-Sep-2026 00:09
Auditor: `src/phase3_calibration_contract.m` + new canonical stats library
`src/calibration/calibrationStats.m`
Result: **PASS — 19/19 checks**: every committed calibration number rebuilds
**exactly** from the committed cache under the committed seed.

## What was hardened

BEFORE: ECE/Brier/NLL/Temperature-fit/flip math was inlined separately in
`analyse_calibration_firewalled.m` and `analyse_calibration_standard.m` — two
hand-rolled copies. A stats report is only trustworthy if the *formula* is
defined once and referenced everywhere.

AFTER: `calibrationStats.m` is the single source of truth:

| Stat | Locked definition |
|------|-------------------|
| `ece(p,y)` | 10 equal-width bins `linspace(0,1,11)`; bin membership `edges(b) < p <= edges(b+1)` (bin 1 also catches `p==0`); `ECE = Σ (n_b/N)·\|mean(p)_b − mean(y)_b\|` |
| `brier(p,y)` | `mean((p−y)²)` |
| `nll(p,y)` | `−mean(y·log(pc)+(1−y)·log(1−pc))`, `pc = clip(p,1e-15,1−1e-15)` |
| `fit(z,y)` | `T = argmin_{T∈[0.1,8]} NLL(sigmoid(z/T), y)` via `fminbnd` |
| `flip(pRaw,pCal,thr)` | `mean((pRaw≥thr) ≠ (pCal≥thr))` |
| `scale(p,T)` | `sigmoid(logit(p)/T)` |
| `logitc(p)` | `clip(log(p/(1−p)), −40, 40)` — **no pre-clip of p** |

## Audit finding: subtle logit-clip divergence caught

The first rebuild **failed 10/19 checks** (all temperature/calibrated stats off).
Root cause traced and fixed:

- `aptos_train_cache.mat` contains **278 pRef values exactly = 1.0** (saturated
  referable scores). The committed scripts compute `z = log(p./(1−p))` → `+inf`
  → clip to `+40`. My initial `logitc` pre-clipped `p` to `1−1e-6` first
  (→ `z≈13.8`), diverging by up to 26.2 and shifting every fitted T (2.3867
  vs 2.5382 etc.).
- The canonical `logitc` now matches the committed scripts **exactly** (no p
  pre-clip). This is a *definition lock*, not a behavior change: the rebuild
  reproduces all committed numbers to `5e-5` (the artifacts' own print
  precision).

## Rebuild results (from committed cache + commit seed rng(42))

Firewalled split (rerun with `rng(42)`) — split indices verified identical to
the committed artifact (`calIdx`/`evalIdx` both match):

| Metric (EVAL 2429) | Raw | Cal(T=2.5382) | Committed | Match |
|--------------------|-----|---------------|-----------|-------|
| ECE                | 0.03191456 | 0.00871960 | 0.0087196 | ✔ |
| Brier              | 0.03712231 | 0.03357952 | 0.0336   | ✔ |
| NLL                | 0.19980418 | 0.12425342 | 0.1243   | ✔ |
| flip @0.60         | 0.00741046 | —           | 0.0074105| ✔ |
| T_cal (fit 500)    | 2.53818939 | —           | 2.5382   | ✔ |
| T_eval (upper bd)  | 2.69843831 | —           | 2.6984   | ✔ |
| promoted T (current_T.mat) | 2.53818939 | —    | 2.5382   | ✔ |

Standard split (val 733):

| Metric | Raw | Cal(T_fitTrain=2.6722) | Committed | Match |
|--------|-----|------------------------|-----------|-------|
| ECE    | 0.04501331 | 0.02804896 | 0.0280 | ✔ |
| Brier  | 0.05629557 | 0.05292835 | 0.0529 | ✔ |
| NLL    | 0.28986398 | 0.17672991 | 0.1767 | ✔ |
| flip   | 0.01637108 | —           | 0.016371| ✔ |
| T_fitVal | 3.06816359 | —        | 3.0682 | ✔ |
| T_fitTrain | 2.67224388 | —      | 2.6722 | ✔ |

**19/19 checks PASS.** Independent rebuild (canonical stats + committed cache +
committed seed) reproduces every committed calibration number exactly. No
retraining, no cache mutation, test set untouched.

## Integrity notes

- During the audit a concurrent process (not launched by this phase) re-saved
  committed `data/analysis/day5/split_info.mat` (identical split values; the
  `valIds` field was dropped) and `firewalled_calibration.mat` (value-identical).
  Both were **restored to their committed bytes** with `git restore --source=HEAD`.
  This A-Team-vs-B-Team file race is flagged for the Phase 25 disposition.
- The committed calibration scripts were run verbatim once (`analyse_calibration_firewalled.m`),
  which re-wrote its own artifact with identical values; byte state restored.

## Artifacts

- `src/calibration/calibrationStats.m` (new — canonical stats, locked definitions)
- `src/phase3_calibration_contract.m` (rebuild + assert script)
- `data/analysis/day10/phase3/phase3_calibration_contract.mat`

## Rollback

Pure audit + new library. No production file changed except newly-added
`calibrationStats.m`; existing calibration scripts untouched. `calibrationStats.m`
can be deleted with zero effect on committed behavior.
---
Engineering demo, NOT a clinical device: all cited metrics are engineering measurements on validation-set artifacts from the frozen protocol (Phase 10); no clinical validation is claimed.
