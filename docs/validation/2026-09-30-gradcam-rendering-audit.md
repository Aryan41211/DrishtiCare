# DrishtiCare — Grad-CAM Rendering Audit

Date: 2026-09-30. **9/9 PASS.** MATLAB R2026a Update 5 (26.1.0.3346908).

Script: `src/verify/verify_gradcam_rendering.m`
Run: `matlab -batch "run('src/verify/verify_gradcam_rendering.m')"`
Terminator: `ALL GRADCAM RENDERING AUDIT CHECKS PASS` (exit code 0)

## Why this audit exists

`docs/project-management/EXECUTION_CHECKLIST.md` Phase C carried four unticked
boxes — *verify normalization*, *verify resize/interpolation*, *verify
colour-space conversion*, *verify alpha blending* — each annotated
"not verified as a discrete check". Rendering had been centralized in
`src/ui/renderGradCAMViews.m` and covered end-to-end by the 35-assertion app
check, but no verifier ever measured these four properties numerically. This
audit closes them by measurement rather than by inspection.

## Scope and safety

The audit is **read-only against the rendering layer**. It loads no network, no
model, and reads no metric, threshold or calibration value. It cannot and does
not alter the frozen ML contract. All fixtures are deterministic — the script
contains no RNG call.

## The four properties, as measured

Fixture: a 32×32 synthetic map spanning **−3 … 5** (deliberately out of range,
so a correct normalization must clamp it), against a 48×64×3 mid-grey base.

### 1. Normalization — PASS

Rendering against a base the *same size* as the map (so no resize occurs)
isolates the normalization step. Result: input range −3 … 5 → output
**0.000000 … 1.000000**, via `mat2gray`. Both endpoints hit exactly.

### 2. Resize / interpolation — PASS

The 32×32 map is resampled to the base's 48×64. The theme selects `bicubic`
(`src/ui/drishtiTheme.m`). The fixture genuinely exercises a resize in both
dimensions, so this is a real check, not a no-op.

### 3. Colour-space handling — PASS

All three outputs are `uint8` 3-channel RGB at the base resolution — there is
no grayscale fallback path. The decisive test: **every distinct emitted colour
is an exact entry of the 256×3 `turbo` map** (max deviation **0/255** across 64
distinct colours). This is what proves the ordering claim in the function's own
documentation — the scalar map is resized *first* and indexed into the colormap
*afterwards*. Colouring before the resize would interpolate between colours and
emit entries that are not in the map.

### 4. Alpha blending — PASS

The opacity is not read from the source; it is **recovered from the output**.
Since `overlay = α·heatRGB + (1−α)·base`, then `α = (overlay − base)/(heatRGB − base)`.
Solving that per channel over a horizontal ramp:

| Position | Recovered α | Theme bound | Deviation |
|---|---:|---:|---:|
| minimum activation | **0.3190** | 0.32 | 0.0010 |
| maximum activation | **0.5015** | 0.50 | 0.0015 |

Across 7,680 well-conditioned samples the recovered range is
**[0.3142 … 0.5028]**, and no sample escapes the theme window. The policy is
therefore genuinely *activation-modulated* (low activation stays subtly
tinted, high activation carries the colour) rather than a constant opacity.

Tolerance is derived, not chosen: the overlay is stored as `uint8`, so each
recovered α carries a quantisation error of about `(1/255)/|den|`. With the
conditioning floor at 0.15 that is ≤ 0.0311, and the assertion tolerance is set
just above it. A genuine alpha-policy fault — for example applying one constant
opacity everywhere — would displace these estimates by roughly 0.18, far
outside tolerance, so the check discriminates rather than rubber-stamps.

## Three contract checks

5. **The input map is never mutated** (`isequal` before/after). Rendering is
   presentation-only; it does not alter Grad-CAM values.
6. **Determinism** — repeated renders are bit-identical.
7. **Graceful degradation** — an empty map returns empty outputs, which is what
   makes the report omit its Visual Evidence block rather than fail the export.

## 8. Required disclaimer intact

`drishtiTheme().gradcam.disclaimer` still reads, verbatim:

> Model attention visualization - not validated lesion localization.

---

## Disclosures

These are recorded rather than fixed, because fixing them would change
presentation behaviour that is deliberate and already verified.

### D1 — `bicubic` resize rings slightly outside [0, 1] (no visual effect)

After the resize the scalar map spans **[−0.003024 … 1.003024]**, i.e. it
overshoots by about ±0.003. This is ordinary `bicubic` ringing, not a
normalization failure — normalization itself is exact (§1 above).

Consequences were checked rather than assumed:

- The two **emitted** `uint8` images are unaffected. The `im2uint8` cast absorbs
  the overshoot, and the decisive colour test in §3 still returns **0/255**
  deviation, so no colour outside the map can reach the screen.
- 3.12 % of the frame sits on colormap indices 0 and 255. These are `turbo`'s
  legitimate endpoints and a ramp spanning the full range is *expected* to
  reach them; this is not clipping of information.
- The third output (`heatmap`) is documented in the function header as
  *"double [0,1]"*. After a bicubic resize that is **not strictly true** — it
  can exceed 1 by ~0.003. The header comment is therefore slightly imprecise.
  The header was **left unchanged** because the deviation is ~0.3 %, cosmetic,
  and clamped downstream; correcting the wording without changing behaviour is
  deferred rather than done silently in a release pass.

### D2 — Two Grad-CAM rendering paths exist, only one is user-facing

The claim in `docs/task-tracker.md` S4 and in `ROADMAP.md` §7 that the dashboard
and the PDF share *one* rendering code path is **accurate for both user-facing
surfaces**:

- `RetinaAIApp.m:893` → `renderGradCAMViews(r.gradCAMMap, raw)`
- `src/reporting/generateDrishtiReport.m:230` → `renderGradCAMViews(...)`

However `predictSingleFundus.m:169-172` still computes its **own** overlay via
`imfuse(...,'blend','Scaling','joint')` and stores it in the legacy field
`result.gradCAM`. That field is consumed only by:

- `src/demo/run_failure_aware_demo.m:182` (`rec.gradcam_overlay`, demo evidence)
- `src/lesions/test_lesion_report.m:65` (a development/inspection script)
- `verify_retinaai.m:82` (a non-empty contract assertion)

So no judge-facing surface uses the legacy blend, and no scientific value
differs between the paths — only the opacity/colour policy. It was **not**
changed: it feeds an already-committed evidence artifact, and altering it would
modify historical demo evidence for no submission benefit. Recorded here so the
"single code path" claim is read precisely.

### D3 — Not verified by this audit

- The **scientific** quality of Grad-CAM is out of scope and remains weak and
  documented as such: saliency-in-lesion **3.1 %**, pointing game **7.4 %**,
  IoU **0.035**. This audit proves the *rendering* is correct and honest; it
  says nothing about localization accuracy, which remains a stated limitation.
- Live on-screen appearance in the running GUI was not re-inspected in this
  pass; see the responsive-layout item in
  `docs/project-management/FINAL_RELEASE_STATUS.md`.
