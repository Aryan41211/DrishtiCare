# DrishtiCare Hardening — Phase 17: Model-File Immutability Regression

Date: 2026-09-10. **8/8 PASS.**

## Contract verified
1. **Locked champions unmodified** — full-program SHA-256 identical to
   `audit/improvement_baseline/baseline_manifest.md`:
   - 5-class (`day7_pretrained_resnet18_5class_stage2.mat`):
     `DD152C917689146F6DEC4687B263EC5E5F237ECF60EC719A59F9FCEEFF737C1B`
   - binary (`day7_pretrained_resnet18_binary_stage2.mat`):
     `43E8DF33B429231EE5BD60A775FDB3629AD81F287617AFAA9308EA87D311F9A0`
2. **Git immutability during the hardening program** —
   `git status --porcelain` for `data/analysis, data/models, data/splits*,
   data/aptos2019` shows **no modified/deleted committed files** (only `??`
   untracked = new `data/analysis/day10/` program outputs, which are allowed).
3. **All 17 committed result artifacts present and non-empty** (existence +
   hashing), all 14 experimental models present.

## Findings / disclosures
- **Model files are NOT git-tracked** (`git ls-files data/models` → empty).
  The manifest SHA-256s are therefore the only integrity anchor for the
  champions. Recommendation (P25): keep the hash snapshot
   `data/analysis/day10/phase17/phase17_hash_snapshot.json` as the standing
   drift baseline, and optionally re-evaluate whether ~500 MB of models should
   be tracked (e.g. via a separate LFS/archive disposition).
- **Pre-existing manifest drift (NOT caused by hardening) — disposition
  executed at P25:** `baseline_manifest.md` previously listed
  `data/models/day8_5class_v2a_stage1.mat`, but only
  `day8_5class_v2a_stage2.mat` exists on disk (confirmed by directory listing;
  no stage1 file was ever committed). This file is explicitly *not promoted /
  not locked*, so stage1 was **not** an immutability-relevant artifact and its
  absence **does not** violate the immutability contract — the contract covers
  the two locked champions in check 1, both verified byte-identical by
  SHA-256. The recommended Phase 25 correction has since been applied as a
  documentation fix: the manifest now records
  `audit/improvement_baseline/baseline_manifest.md:28` — *"Task 5(a), not
  promoted; stage1 checkpoint was NOT committed — manifest corrected at P25"*.
  No model file was created, deleted or modified to achieve this.
- `.NET SHA-256` had one fix during development (`System.IO.File.Open` needed
  `System.IO.FileMode.Open`, not string literals); the git check also needed to
  distinguish untracked (allowed) from modified (forbidden).

## Artifacts
- `src/phase17_model_immutability.m`
- `data/analysis/day10/phase17/phase17_model_immutability.mat`
- `data/analysis/day10/phase17/phase17_hash_snapshot.json` (full-program hash
  snapshot: champions + 15 models + 17 artifacts + drift record)

Engineering demo, NOT a clinical device: all cited metrics are engineering measurements on validation-set artifacts from the frozen protocol (Phase 10); no clinical validation is claimed.
