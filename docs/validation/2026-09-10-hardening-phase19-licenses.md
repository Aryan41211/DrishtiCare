# DrishtiCare Hardening — Phase 19: Third-Party & License Audit

Date: 2026-09-10. **5/5 PASS.**

## Deliverable
`docs/licenses/license-inventory.md` — full inventory of pretrained-model
sources, every dataset's access/license terms + compliance status, and the
pinned software dependency list.

## Verified
1. **Inventory coverage** — contains entries for all datasets in use or planned
   (APTOS 2019, IDRiD, DRIVE, EyePACS, EyeQ, e-ophtha, DIARETDB1, STARE,
   CHASE_DB1, HRF, DRIMDB, Messidor-2, Sin-NP DR 2019) plus the resnet18
   pretrained source.
2. **Single architecture** — only `resnet18` (MathWorks Deep Learning Toolbox
   supported network) is called anywhere in `src`; no densenet/vgg/alexnet/
   inception/googlenet/mobilenet/xception/efficientnet call-sites (scan
   requires call syntax so doc/literal mentions don't false-positive).
3. **No third-party MATLAB add-ons** — the 28 installed add-ons are all
   MathWorks-licensed products (incl. `RESNET18` support network); identifier
   set checked against the known MathWorks list → **zero File-Exchange /
   3rd-party**.
4. **No rogue image stores** — every image-bearing `data/*` directory sits
   under a known dataset root (`aptos2019`, `idrid`, `drimdb`, `drive`,
   `splits*`, `analysis`, `models`); no unexplained image copies.
5. **Messidor-2 obligations pinned** — acknowledgment ("Kindly provided by the
   Messidor program partners …") + both required citations (Decencière 2014,
   Abràmoff 2013) recorded in the inventory (Phase 16 depends on this).

## Check corrections (each found by the check itself)
- `matlab.addons.installedAddons` returns **28 MathWorks products**, not zero —
  the original "no add-ons" premise was wrong; corrected to "all installed
  add-ons are MathWorks-licensed, zero third-party".
- Architecture scan self-matched this audit's own literal pattern string →
  switched to call-syntax regex.
- Path-separator bug: `data/splits` (backslash) vs `data/splits` (slash) made
  `startsWith` fail; normalized separators before matching.

## Artifacts
- `docs/licenses/license-inventory.md`
- `src/phase19_license_audit.m`
- `data/analysis/day10/phase19/phase19_license_audit.mat`