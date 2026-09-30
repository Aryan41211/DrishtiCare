# Layout and lesion-evidence audit — 2026-09-30

**Scope.** Two open Phase-B items in
[`EXECUTION_CHECKLIST.md`](../project-management/EXECUTION_CHECKLIST.md) —
"Audit current UI" and "Verify responsive layout" — plus a wording review of
how lesion evidence is presented.

**Artifacts.**

| Artifact | Role |
|----------|------|
| `src/dashboard/verify_app_layout.m` | new headless geometry audit (4 checks) |
| `src/reporting/generateDrishtiReport.m` | one presentation fix (lesion qualifier) |

**Constraints honoured.** No model, weight, threshold, temperature, calibration
constant, metric or quality decision was read, written or retrained.
`predictSingleFundus.m` is untouched. The frozen contract
(`FROZEN_CONTRACT.md`) is unchanged and both champion hashes still match.

**Machine.** MATLAB R2026a, primary screen 1600×900.

---

## 1. "Verify responsive layout" — not applicable, not merely untested

The checklist note claimed the check was open because no test "asserts layout at
more than one window size". That framing turned out to be wrong about the
software, and it is worth stating precisely:

- `RetinaAIApp.m:157` sets `'Resize', 'off'` on the `uifigure`.
- The figure is created at a hard-coded `'Position', [40 8 1360 760]`.
- Every component is absolutely positioned against that canvas. There is **no
  `uigridlayout` anywhere in the class** (0 call sites).

So the app is a **fixed-canvas** application. It does not resize, and there is
no second layout to test. Multi-size responsive layout is therefore *not
applicable* rather than *untested*, and no amount of additional testing would
make the current box honest. The box has been rewritten to say that.

The audit verifies what is actually verifiable: the geometry at the design size.

## 2. Layout audit results — 4/4 PASS

`matlab -batch "run('src/dashboard/verify_app_layout.m')"` → exit 0,
terminator `ALL DRISHTI APP LAYOUT CHECKS PASS`.

### 2.1 Nothing is clipped — 217/217 components

The audit walks every descendant, sums each parent chain to figure-relative
coordinates, and checks the rectangle against the canvas.

```
INFO figure Position      = [40 8 1360 760]
INFO figure Resize        = off
INFO primary screen       = [1600 900]
INFO descendants measured = 217
INFO clipped by figure    = 0
INFO zero-extent          = 0
OK  1. all 217 components lie inside the 1360x760 canvas
```

Two component families are excluded deliberately, and this is stated rather than
left silent: a `matlab.ui.container.ContextMenu` and a
`matlab.ui.control.WebComponent` carry 2-element `Position` values and are not
measurable as rectangles. They carry no visible layout.

### 2.2 The bands tile without overlap

Direct-child panels are classified structurally — flush with the top edge is the
header; the lowest remaining band is the bottom bar; the rest are content:

```
INFO layout bands         = 1 header, 3 content, 1 bottom
INFO content panel 1     [8 144 330 564]
INFO content panel 2     [346 144 420 564]
INFO content panel 3     [774 144 578 564]
OK  2. 3 content panels share one band and are ordered left to right
OK  3. content panels clear the header band (y<=716) and bottom bar (y>=136)
```

| Band | Rectangle (canvas-relative) |
|------|----------------------------|
| Header | `[0 716 1360 44]` |
| Content 1 (image) | `[8 144 330 564]` |
| Content 2 (AI result) | `[346 144 420 564]` |
| Content 3 (visual evidence) | `[774 144 578 564]` |
| Bottom bar | `[0 48 1360 88]` |
| Footer strip (labels, not a panel) | below `y = 48` |

Gaps of 8 px separate the three content panels, and the two outer margins are
8 px. The header/footer asymmetry (8 px inset for content, 0 px for the bands)
is the existing design and was left alone.

Note the bottom bar does **not** sit flush with the canvas: a label-only footer
strip occupies `y < 48`. An earlier revision of the audit assumed flush-to-zero
and misclassified all 16 nested panels; the classification above is the corrected
one.

### 2.3 The default window fits the audited screen

`[40 8 1360 760]` → right edge 1400, top edge 768, against a 1600×900 screen.
Fits, with 200 px of horizontal and 132 px of vertical margin.

**Carried-forward risk, not fixed.** The window position is hard-coded to
`[40 8 …]`, so on a **1366×768** laptop — still a common demo machine — the right
edge lands at 1400 and about **34 px of the window is off-screen**. The audit
reports this as information rather than asserting a pass, because the outcome
depends on the machine. Two options, both deferred to a human decision because
each is a visible change:

- centre the window on the primary screen at launch, or
- clamp the size to the screen when it is smaller than the design canvas.

Neither was applied unilaterally. `pitch/video-plan.md` should record the demo
machine's resolution before recording.

### 2.4 Method note

The layout containers are declared `properties (Access = private)`
(`RetinaAIApp.m:24`), so the audit identifies the bands **structurally** from the
figure's direct `uipanel` children rather than by reading `app.LeftPanel` etc.
Weakening the app's encapsulation so a test could reach private handles would be
a design change made for test convenience; it was not done.

---

## 3. Lesion-evidence wording — one real gap, now fixed

### 3.1 What was already compliant

| Surface | Qualifier | Status |
|---------|-----------|--------|
| `buildExplanationNarrative.m:64` | "These are automated candidate counts (not clinical-grade measurements) and serve as supportive evidence only." | present |
| `generateDrishtiReport.m:100` | `disclaimerTop` = "ENGINEERING DEMO - NOT a clinical device." | present |
| `generateDrishtiReport.m:176-179` | footer: "NOT a clinical device and must not be used alone to make treatment decisions." | present |
| `RetinaAIApp.m:463` | "Model attention visualization - not validated lesion localization." | present |
| `RetinaAIApp.m:646` | "APTOS held-out validation - Prototype, not clinically validated" | present |

Honest negative statements are also preserved rather than smoothed over: the
narrative discloses when the optic disc was not located (so counts near the disc
may include disc tissue) and when fovea localization is unreliable (so
exudate-to-fovea distance is unavailable).

### 3.2 The gap

`generateDrishtiReport.m` rendered **only** `r.explanation.paragraph` into
section 5 (`explanationParagraph`, line 290). The qualifier lives in
`r.explanation.evidence` — a *different* field — and was never emitted.

A reader of the PDF alone therefore saw a readout row labelled
"Lesion candidates" with bare `MA n · HE n · EX n` values, with the
"not clinical-grade / supportive evidence only" sentence missing. The overall
"not a clinical device" disclaimer was present, but nothing tied the specific
numbers to their experimental status. Given the standing requirement that lesion
evidence be labelled supplementary, this was a genuine defect in the
deliverable, not a stylistic preference.

### 3.3 The fix

One text block added after the readouts in section 5, restating the qualifier:

> Lesion candidates above are automated, experimental counts from a
> supplementary second-opinion branch. They are not clinical-grade measurements,
> are not a validated detection of any lesion type, and do not by themselves
> establish a diagnosis.

Presentation only. No count, score, threshold, route or decision is touched;
`predictSingleFundus.m` is unchanged.

**Verified.** `verify_drishti_report_extended` still passes (exit 0,
`ALL EXTENDED DRISHTI PDF REPORT CHECKS PASS`), and the rendered artifact grows by
exactly **1004 bytes** — the size delta of the added sentence alone, confirming
nothing else in the document moved. The qualifier is present in the emitted
output.

### 3.4 Not verified, and why

The MA detector's own numbers are unchanged and remain as documented: patch-level
ROC-AUC 0.976 with recall 0.113, and Grad-CAM localization measured at 3.1%
saliency-in-lesion, 7.4% pointing game, IoU 0.035. This audit did **not**
re-measure them — the source values live in binary `.mat` artifacts and were not
re-derived here. They are reported unchanged, not re-confirmed.

---

## 4. Verdict

| Check | Result |
|-------|--------|
| Nothing clipped at the design size | PASS — 217/217, 0 clipped, 0 zero-extent |
| Bands tile without overlap | PASS — 3 content panels, one band, header/footer clear |
| Default window fits the audited screen | PASS on 1600×900; **34 px off-screen risk on 1366×768** |
| Multi-size responsive layout | **N/A** — fixed-canvas by design, `Resize` off |
| Lesion counts qualified in the PDF | **FIXED** — was missing, now verified in output |
| Lesion counts qualified elsewhere (narrative, app, report disclaimers) | PASS |
| Frozen ML contract | PASS — untouched, hashes match |

**No submission-blocking defect was found in this audit.** One presentation
defect (the missing lesion qualifier) was found and fixed. One presentational
risk (fixed window position on small screens) is documented and left for a human
decision, because resolving it changes what the demo looks like.
