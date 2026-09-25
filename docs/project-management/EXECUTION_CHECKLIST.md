# DrishtiCare — Execution Checklist

Use this as the working checklist. Complete items in order.

**Status snapshot: 2026-09-26 — 47 of 68 boxes ticked.**

Every ticked box carries a bracketed evidence pointer (`[tracker S5]`,
`[tracker P17]`, `[re-hashed 2026-09-26]`, …). Every unticked box carries a
short `⚠️` note saying what is missing or what is only partly done. Read the
note before treating an unticked box as "not started".

**Evidence record:** [`docs/task-tracker.md`](../task-tracker.md) — P0–P25
hardening table plus the S1–S8 post-hardening table. Governance context:
[`ROADMAP.md`](ROADMAP.md), [`FROZEN_CONTRACT.md`](FROZEN_CONTRACT.md),
[`DECISION_LOG.md`](DECISION_LOG.md), [`CURRENT_STATUS.md`](CURRENT_STATUS.md).

## Phase A — Freeze and Backup

- [x] Confirm branch is `main` — [`git rev-parse --abbrev-ref HEAD` → `main`, 2026-09-26]
- [x] `git status --short` — [run 2026-09-26 at HEAD `ec0b2cf`; no uncommitted change under `src/`, `data/` or the model files — pending entries were docs-only]
- [x] Back up both champion `.mat` files — [`C:\projects\DrishtiCare-model-backup\2026-09-26\` holds both (41,724,762 / 41,723,622 bytes)]
- [x] Verify both SHA-256 hashes — [re-hashed 2026-09-26: live files and backup both `DD152C91…` / `43E8DF33…`, matching `FROZEN_CONTRACT.md`]
- [x] Confirm sealed APTOS test remains untouched — [tracker P10 protocol freeze + P17 8/8; contract test `src/demo/tests/test_failure_aware_demo.m` TEST 9 with the signature in `src/demo/tests/aptos_test_snapshot.txt` (`1928 files, 1613745564 bytes`)]

## Phase B — Dashboard

- [ ] Audit current UI — ⚠️ no standalone UI audit artifact is committed. The redesign and its behavioural verification are recorded ([tracker S5], 35/35), but there is no pre-redesign UI audit document to point at.
- [x] Improve header — [tracker S5, commit `4ab0f13`: `HeaderPanel` + `EngTag` / `StatusDot` / `StatusLabel`]
- [x] Improve three-panel hierarchy — [tracker S5, commit `4ab0f13`: `LeftPanel` (image) / `MiddlePanel` (AI result) / `RightPanel` (visual evidence) introduced]
- [x] Improve fundus image display — [tracker S5: `ImageAxes` in `LeftPanel` with `FilenameLabel` / `MetaLabel`]
- [x] Improve AI result card — [tracker S5: `MiddlePanel` — `SeverityValue`, `IcdrValue`, `ModelInfoLabel`, `AdviceBox`]
- [x] Improve referral status — [tracker S5: `ReferralPanel` + `ReferralDot` / `ReferableValue` / `ReferralNote`]
- [x] Improve quality cards — [tracker S5: `OverallChip` / `OverallValue` / `QualityBadge` / `QualityReasonLabel` / `EnhanceLabel`]
- [x] Improve confidence display — [tracker S5: `ConfidenceBar` + `ConfChip`]
- [x] Improve Original/Enhanced/Grad-CAM/Overlay controls — [tracker S5: `ViewButtons` (`ViewOriginal`, `ViewEnhanced`, `ViewHeatmap`, `ViewOverlay`); all four asserted by the headless verifier]
- [x] Centralize theme — [tracker S3, commit `6baa02e`: `src/ui/drishtiTheme.m`, ~20 call sites in `RetinaAIApp.m`]
- [x] Centralize Grad-CAM rendering — [tracker S4, commit `d3531ae`: `src/ui/renderGradCAMViews.m` + `src/ui/gradcamColorbarStrip.m` consumed by both the app and the PDF report]
- [ ] Verify responsive layout — ⚠️ not verified. The 35/35 headless check (`results/_verify_retinaai_verdict.txt`) asserts lifecycle, `result` fields, quality badge, recommendation banner, view-button presence and the WITHHELD-on-FAIL contract — it does not assert layout at more than one window size, and no responsive-layout test exists.

## Phase C — Grad-CAM

- [ ] Verify normalization — ⚠️ not verified as a discrete check. Rendering was centralized in `src/ui/renderGradCAMViews.m` and passes the consolidated 35/35 app check, but no per-step numeric normalization check was ever run.
- [ ] Verify resize/interpolation — ⚠️ not verified as a discrete check (same reason as above; no resize/interpolation assertion exists in any verifier).
- [ ] Verify color-space conversion — ⚠️ not verified as a discrete check (no colour-space assertion in any verifier).
- [ ] Verify alpha blending — ⚠️ not verified as a discrete check. S4 centralized the alpha policy inside `renderGradCAMViews` so app and PDF share one code path, but blending itself was never asserted.
- [x] Select one consistent scientific colormap — [tracker S4: `src/ui/drishtiColormap.m` (256×3, low→high) is the single map for both app and PDF]
- [x] Consistent colorbar — [tracker S4: `src/ui/gradcamColorbarStrip.m` + `ColorbarAxes` in the app; theme-consistent]
- [x] Keep disclaimer: "Model attention visualization — not validated lesion localization." — [present in `RetinaAIApp.m:463`; `DECISION_LOG.md` D005]
- [x] Verify no scientific values changed — [tracker S3 + S4 both state "presentation only: no model, threshold or quality decision touched"; P17 8/8 hash match; demo contract TEST 6/7 hash checks; P11 decision-math invariants]

## Phase D — Report

- [x] Redesign A4 report — [tracker S6, commit `3d138d7`: `src/reporting/generateDrishtiReport.m`, 631 lines, branded A4, two-tier engine]
- [x] Add image information — [tracker S6: identity line `Patient ID` + `Generated` timestamp (`generateDrishtiReport.m:99`) and the source image embedded in §4]
- [x] Add quality section — [§3 Image Quality Assessment, incl. per-metric table, recapture advice / failure findings]
- [x] Add AI result — [§1 Screening Summary verdict + §2 Diabetic Retinopathy Grade (grade, stage, model score)]
- [x] Add referral result — [§1 and §6 verdict blocks: `REFERABLE` / `NOT REFERABLE` with model score vs threshold]
- [x] Add confidence — [§2 "Model confidence" stat + §5 Interpretation readouts]
- [x] Add original/Grad-CAM/overlay evidence — [§4 Visual Evidence built from `src/ui/renderGradCAMViews.m` → `[overlay, heatRGB, heatmap]`; omits the block gracefully if a view is missing]
- [x] Add recommendation — [§6 Recommendation (verdict + narrative `recommendation` text)]
- [x] Add non-clinical disclaimer — [`generateDrishtiReport.m:100` "ENGINEERING DEMO – NOT a clinical device." + footer disclaimer]
- [x] Verify generated PDF — [tracker S8, commit `8d344de`: `results/_verify_extended_verdict.txt` → `VERDICT: PASS`, `PDF_ENGINE: edge`, `PDF_HEADER: %PDF-1.4`, `CALLBACK_GAP:` empty, all three app callbacks driven]

## Phase E — Failure-Aware Demo

- [x] PASS case — [tracker S2: `data/analysis/failure_aware_demo/demo_cases.csv` case `case_pass_referable`; `audit_log.csv` shows `inference_executed=1`, grade 4 Proliferative]
- [x] WARNING case — [tracker S2: case `case_warning` (uneven illumination), reaches the AI stage and routes CLEAR]
- [x] FAIL case — [tracker S2: FAIL roles in `demo_cases.csv` (blur, dark, bright, illumination, FOV, contrast)]
- [x] Confirm FAIL produces no model execution — [tracker S2: FAIL images never reach the model (`predictSingleFundus` not called); contract TEST 2 and TEST 11; every FAIL row in `audit_log.csv` has `inference_executed=0`, `binary_decision=WITHHELD`]
- [x] Confirm failure reason is visible — [contract TEST 3; `audit_log.csv` carries `quality_reason`, `primary_metric/value/bound`, `primary_message` per FAIL case]
- [x] Confirm recapture/manual-review recommendation — [FAIL rows route `REVIEW` with WITHHELD; `predictSingleFundus` populates `qualityRecaptureAdvice`, rendered as "Recapture advice: …" in report §3]
- [x] Confirm no hardcoded predictions — [contract TEST 8 (no training call-sites in demo/quality code), TEST 10 (no FAIL case becomes a silent prediction), TEST 6/7 (model files and locked SHA-256 unchanged by the run)]

## Phase F — Simulink

- [x] Verify `.slx` — [tracker S1: `src/simulink/DrishtiCare_DistrictScreening.slx`, 66,405 bytes, genuine OPC/zip container (25 entries); the old 56-byte placeholder was deleted, so no placeholder remains]
- [x] Verify reference parity — [tracker S1: `matchesReference = 1`, max abs diff `0.00e+00`, 11/11 internal sanity checks PASS]
- [x] Create one presentation figure — [`results/presentation/simulink_district_summary.png` (1348×2700, 324,955 bytes) + `simulink_district_summary.txt` alt-text, generated reproducibly by `src/simulink/compose_simulink_summary_figure.m`; composes all five committed figures with an annotating header. Individual figures retained in `data/analysis/simulink_resource_simulation/figures/`]
- [x] Document assumptions — [`data/analysis/simulink_resource_simulation/README.md` §4 "Simulation Assumptions", every value explicitly labelled an assumption, §3 measured inputs kept separate]
- [x] Label output as engineering simulation — [sim README §11/§13; `DECISION_LOG.md` D009; tracker S1]
- [x] Do not present staffing output as a prescription — [`DECISION_LOG.md` D009; sim README §11 ("Specialist capacity values are assumptions unless externally sourced"); `CURRENT_STATUS.md` — keep this label in the deck]

## Phase G — Evidence

- [x] Resolve vessel Dice provenance — [**RESOLVED 2026-09-26**, `docs/validation/2026-09-26-metric-provenance-resolution.md`. DRIVE mean Dice `0.2576` is correct; `0.2541` is **not reproducible** from any committed artifact. Human `0.7881` is the task8/un-eroded-FOV value; `0.7902` is the classical vessel/eroded-FOV value — both real, different pipelines, task8 keeps `0.7881`. No headline value changed. Read-only scripts `src/verify/verify_metric_provenance.m`, `src/verify/confirm_provenance_resolutions.m`; artifacts `data/analysis/day11/provenance/`.
- [x] Resolve Day-7 scratch-baseline provenance — [**RESOLVED 2026-09-26**]. The §2 scratch-baseline row is **not** a category error: the frozen `eval_fixed` figures (sens `0.832215` / spec `0.908046`, from the *frozen authoritative split*) **supersede** the earlier pre-freeze operating point (`0.830671` / `0.866667`, computed on a different `YTrue>=2` convention). The five-class predictions are identical; only the threshold/convention differed. `docs/day7/pretrained-resnet-report.md` now records both with dates.
- [x] Source clinical impact statistics — [**SOURCED 2026-09-26**], `docs/background/clinical-statistics-sources.md` + `clinical-background.md`. (a) 77M is the IDF Diabetes Atlas 9th ed. (2019) figure and is **superseded** (74.2M in 2021; ~90M provisional 2024) — must be dated. (b) "18%" needs age framing: 18.1% (age ≥50), 14.9% (age ≥30); national survey reports **16.9%** for the same band. (c) **"1 ophthalmologist per 100,000" is NOT supported** — the defensible figure is ~**1 : 65,221** (IJO 2025); the binding constraint is retina specialists at ~1 per 1.26M. The unsupported claim is removed from the deck, not restated.
- [x] Keep unverified values labelled until sourced — [`DECISION_LOG.md` D010; label present at `pitch/deck-structure.md:12`; tracker RF-6 records unverifiable values as an open discrepancy rather than adopting a number]
- [x] Do not invent external validation — [tracker P14/P16: external validation documented as **BLOCKED** (ADCIS registration / Sin-NP request), harness 6/6 PASS and ready, APTOS official test unlabeled and excluded by firewall, no external metrics reported anywhere; `DECISION_LOG.md` D006]

## Phase H — Submission

- [x] Create actual PPT — **deck built 2026-09-26 as `pitch/deck.pdf`** (11 slides, 3,685,132 bytes, `%PDF-1.4`), source `pitch/deck.html` (self-contained, no CDN). ⚠️ **format caveat: it is PDF, not `.pptx`.** MATLAB Report Generator is installed but **unlicensed** on this machine (`license('test','Report_Generator')` = 0, so `mlreportgen.pptx` is unavailable); an editable `.pptx` needs PowerPoint/Office automation and is still open.
- [ ] Create final demo video — ⚠️ **still open — human step, blocked on tooling.** Shot-by-shot plan + word-for-word narration now exist: `pitch/video-plan.md` (9 shots, exactly 3:00; longest shot is the AI-withheld refusal) and `pitch/VOICEOVER-SCRIPT.md` (435 words, every number traced). No `ffmpeg`/`ffprobe` and no OBS/DaVinci/Clipchamp installed, so MP4 assembly + voice-over audio cannot be automated here; `video-plan.md` names OBS Studio (capture + built-in *File ▸ Remux Recordings* for MKV→MP4, no CLI ffmpeg needed) with DaVinci Resolve free / Clipchamp as GUI re-encode fallback. Requirements in [`DEMO_AND_SUBMISSION_PLAN.md`](DEMO_AND_SUBMISSION_PLAN.md) §3.
- [x] Include real app — [deck slides 2–8 embed **11 real screenshots** from the running system (`results/visual_qa/*`, `results/presentation/simulink_district_summary.png`); 0 broken image references, 11 image XObjects confirmed embedded in the PDF]
- [x] Include FAIL/refusal case — [deck slide 6 ("Refusal + rehearsal evidence") is a full slide; `pitch/video-plan.md` shot 4 is the longest at 38 s and is built around the withheld-AI moment. Refusal behaviour is real and verified ([tracker S2], contract TEST 2/11) and is now captured in submission artifacts]
- [x] Include surprise-input case — [**DONE 2026-09-26** — `docs/validation/2026-09-26-unseen-input-rehearsal.md`, `src/demo/run_unseen_rehearsal.m`, `data/analysis/day11/rehearsal/`]. 19 unseen images from three foreign cameras (DRIVE test 5, IDRiD grading test 5, DRIMDB 9): **19/19 completed, 4/4 contract checks PASS** (valid routes, FAIL withheld, no crash, locked 0.60 rule). Honest negatives recorded: quality gate withheld **42%** of unseen images (8 FAIL / 5 WARNING / 6 PASS vs 7.84% FAIL on APTOS), and `drimdb_bad (10).jpg` — human-labelled ungradable — received grade 4, `pRef` 0.9690, route **CLEAR**/REFERABLE, so the gate does **not** catch every ungradable image. High-res IDRiD inputs ran ~35.6 s median vs 11.03 s on 512×512.]
- [x] Add references — [deck slide 11 carries figure-level references with organisation, year and DOI for every clinical statistic; the IDF supersession note and the two deliberately-omitted unverifiable claims (ORNATE 2023 cost, "95% of severe vision loss preventable") are recorded]
- [x] Verify every number — [deck numbers cross-checked against `FROZEN_CONTRACT.md`; text extracted from the generated PDF and grepped for forbidden/stale claims — `80%`, `clinically validated`, `doctor-level`, `replaces`, `1 per 100,000`, `0.2541`, `0.7902` all **CLEAN**; the only `lesion localisation` hits are explicit negations. An automated clipped-content check confirms all 3,152 words across 11 pages render (it caught and I fixed two real layout defects: a dropped screenshot on slide 6 and a mid-sentence truncation on slide 8).]
- [x] Verify every link — [deck has **no external links** (fully offline, no CDN, all CSS inline); references are DOIs, not URLs, so there is no live link to rot. Nothing to re-check.]

## Phase I — Final Audit

- [x] Dashboard verifier passes — [re-run 2026-09-26 during final audit: `ALL DRISHTI APP CHECKS PASS` (terminator present). Prior run: `results/_verify_retinaai_verdict.txt`, 2026-09-25, `ASSERTIONS: 35`, `VERDICT: PASS`]
- [x] Report verifier passes — [re-run 2026-09-26: `ALL EXTENDED DRISHTI PDF REPORT CHECKS PASS (engine=edge)`, 3,119,264 bytes, header `%PDF-1.4`; also re-confirmed `ALL DRISHTI PDF REPORT CHECKS PASS (engine=edge)`. Verdict file `results/_verify_extended_verdict.txt`]
- [x] All phase checks pass — [tracker P25: **230/230 checks PASS** across P1–P24; P16 blocked on data; P14 harness 6/6. Phase 13 re-run 2026-09-26: **10 PASS, 0 FAIL**]
- [x] Model hashes unchanged — [tracker P17 8/8 against the baseline manifest. Re-hashed again during the 2026-09-26 final audit: `day7_pretrained_resnet18_5class_stage2.mat` = `DD152C91…737C1B` **MATCH**, `day7_pretrained_resnet18_binary_stage2.mat` = `43E8DF33…11F9A0` **MATCH** — byte-identical to `FROZEN_CONTRACT.md`]
- [x] Repository housekeeping — [2026-09-26: removed the stale `.kilo/worktrees/periodic-sheep` worktree (detached at `8d344de`, 5 commits behind `main`, held nothing unique; `git worktree prune` clean) reclaiming ~742 MB; deleted untracked `RetinaAIApp.m.bak` (pre-redesign, recoverable from git history); `.gitignore` updated to (a) un-ignore the submission assets `pitch/deck.pdf` + `results/presentation/*` and (b) stop new `results/_diag*`/`_dbg*`/`_green_*` scratch output accumulating. The 26 already-tracked red-phase debug `.txt` files were deliberately **left tracked** (ignoring never untracks, and deleting committed evidence is not hygiene) — flagged for a separate cleanup decision.]
- [x] Git diff reviewed — [whole-tree review performed 2026-09-26 across all staged work; no frozen model, threshold, calibration or metric was modified — confirmed by the hash re-check above. Diffstat recorded in the commit.]
- [x] Working tree clean — [achieved by the 2026-09-26 final-audit commit; the untracked `docs/project-management/` governance files and `docs/background/` sourcing work that were outstanding are now tracked]
- [ ] Final clean-session demo tested — ⚠️ **partially done.** A clean-session headless run **is** now recorded: `src/demo/run_unseen_rehearsal.m` from a fresh MATLAB process completed 19/19 unseen images with 4/4 contract checks PASS (see `docs/validation/2026-09-26-unseen-input-rehearsal.md`). Also re-verified clean-session today: app verifier, extended report verifier (incl. real PDF save through the Edge engine), and Phase 13. **Still open: a human, GUI, live run** (fresh MATLAB launch → `launchRetinaAI.m` → upload → analyze → save report) with screen capture, which is the last step before the video can be recorded. `pitch/video-plan.md` §pre-flight is the checklist for it.
