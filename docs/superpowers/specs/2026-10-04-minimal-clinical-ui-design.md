# Minimal Clinical UI — Design Spec

**Date:** 2026-10-04
**Status:** Approved in chat (all four sections), pending written review
**Scope:** `RetinaAIApp` (user-facing app), `DRScreeningDashboard` (ops dashboard),
shared theme, PDF report, and the three UI-dependent verification gates.

## Problem

The screening app, dashboard and PDF report do not read as minimal or
professional. Concretely: `drishtiTheme.m` defines four surface levels and two
border weights; ten type sizes; the dashboard (`DRScreeningDashboard.m`) is
entirely unthemed and uses `Consolas` for every text block; both apps place
~60 components by hand against a fixed 1360x760 canvas; and
`run_drishti_visual_qa.m:59` identifies the fundus axes by a positional
coincidence (`p.Position(1) < 50`).

## Goals

1. A light clinical visual system, minimal in the sense of *visual restraint
   plus content simplification*: fewer surfaces, fewer type sizes, colour
   reserved for decisions.
2. A responsive app that survives window resizing, replacing the fixed canvas.
3. One source of truth for the visual system across app, dashboard and report.
4. Every existing verification gate still passes, except the three explicitly
   rewritten here.

## Non-goals

No change to inference, models, thresholds, splits, metrics or the demo
contract suite. Locked rules 6 (traceable numbers), 7 (disclaimer on every
report), 9 (UI must not alter inference behavior) and 10 (explainability must
not imply lesion localization) hold by construction.

---

## 1. Design tokens

New file `src/ui/drishtiTokens.m` owns every visual decision. `drishtiTheme()`
remains a public façade returning the same field names, reimplemented over the
tokens, so `generateDrishtiReport.m` and `verify_gradcam_rendering.m` need no
call-site changes.

### Surfaces — four levels + two border weights collapse to three + one

| token | value | replaces | used for |
|---|---|---|---|
| `canvas` | `#F7F8FA` | `background` | figure background |
| `surface` | `#FFFFFF` | `panel` | panels, cards |
| `sunken` | `#F1F3F6` | `panelAlt`, `panelDeep` | axes wells, advice box |
| `hairline` | `#E3E6EB` | `border`, `borderLight` | the only border colour, 1px |

`panelAlt` and `panelDeep` merge into one `sunken`: "card" and "well" were not
visually distinct enough to justify two values. Off-white `canvas` rather than
pure white, so the fundus preview does not glow.

### Ink — two text levels, plus one non-text level

Contrast ratios below are **measured** (WCAG 2.1 relative luminance), not
estimated. The worst case is `sunken`, the darkest surface.

| token | value | surface | canvas | sunken | used for |
|---|---|---|---|---|---|
| `ink` | `#10151C` | 18.32:1 | 17.24:1 | 16.48:1 | values, headings |
| `inkMuted` | `#5A6473` | 5.99:1 | 5.64:1 | 5.39:1 | **all body text, labels and disclaimers** |
| `inkFaint` | `#7C8695` | 3.68:1 | 3.47:1 | 3.31:1 | non-text marks only: axis tick labels, colourbar numerals, inactive/disabled states |

**Disclaimers use `inkMuted`, not `inkFaint`.** The originally proposed
`inkFaint` `#8A93A1` measured 2.79:1 on `sunken` — below even the 3:1 non-text
floor — so it cannot carry text on the advice box or axes wells. Darkening it
to `#666F7D` does reach 4.57:1 on `sunken`, but at 5.08:1 on `surface` it is
visually indistinguishable from `inkMuted`'s 5.99:1. Three *visually distinct*
ink levels that all clear AA for text are not achievable in that narrow band
between "dark enough to read" and "reads as disabled", so the scale is two text
levels plus one non-text level. This is a simplification, not a compromise.

### Status — saturated fill reserved for one thing

| token | value | rule |
|---|---|---|
| `danger` | `#C0392B` | referable / FAIL / reject; text on surface (5.44:1) or white on fill (5.44:1) |
| `success` | `#1E7A46` | accept / not-referable; text on surface (5.35:1) |
| `warning` | fill `#FDF0D5`, ink `#7A5200` (6.13:1) | amber is never text on white |
| `primary` | `#14539E` | the single accent: ANALYZE, Generate Report, active view (7.61:1) |

Amber `#F59E29` on white is ~2.0:1 and unreadable as text, which is why it
currently works only as a dot. The fix is a tinted fill with dark ink: passes
contrast and still reads as caution. `primary` appears at most twice on screen
at once; everything else is neutral.

### Type — ten sizes collapse to five

| token | size | replaces |
|---|---|---|
| `display` | 18 bold | `appTitle` (20), `valueHero` (18) |
| `metric` | 15 bold | `valueLarge` (16) |
| `body` | 11 | `value` (13) |
| `label` | 10 | `sectionTitle`, `panelTitle`, `label`, `labelSmall` |
| `caption` | 9 | `support`, `tiny` |

Section titles become `label` in uppercase. **Uppercase only, no letter
spacing** — `matlab.ui.control.Label` has no letter-spacing property, so
tracking is not implementable and is not attempted. Spacing uses a 4px scale
(4/8/12/16/24) instead of today's arbitrary 5/14/18/22.

One UI sans family throughout, left unset so MATLAB's platform default applies
(no hardcoded font, so the app does not regress on Linux or macOS). The single
exception is monospace for machine-output readouts, where it is conventional
rather than decorative: the dashboard's Inspector textarea and Workload label.
Both are retained, restyled from tokens.

### Grad-CAM: `turbo` -> `parula`

Measured against the gate's own budgets:

| map | endpoint fraction (budget <10%) | alpha conditioning (floor >20%) | verdict |
|---|---|---|---|
| `turbo` (current) | 3.125% | 83.3% | rainbow, not colourblind-safe |
| `parula` | 3.125% | 86.5% | selected |
| `bone` | 9.375% | 70.8% | passes, margin too thin |
| `hot` | 203% | 90.1% | fails |
| `copper` | 28.125% | 69.8% | fails |

`parula` is perceptually uniform and colour-vision-deficiency-friendly.
`alphaLo`/`alphaHi` stay at 0.32/0.50.

Measurement method: replicated `verify_gradcam_rendering.m`'s fixture
(`linspace(-3,5,32)` ramp, mid-grey 48x64x3 base) and its endpoint and
conditioning accounting. Alpha-policy recovery was *not* faithfully replicated;
the authoritative check is running the gate.

### Two corrections to currently-false code

- `drishtiTheme.m:72` claims `"turbo > inferno > parula (all in R2026a)"`.
  Measured on this R2026a install, `inferno`, `magma`, `plasma`, `viridis`
  and `cividis` are **all absent**. Comment corrected to the measured truth.
- `drishtiColormap.m:4` advertises `drishtiColormap('inferno')` as a usage
  example, and the `'inferno'` branch at lines 21-22 would **hard-error**.
  Branch removed; only maps verified present on this install are offered.

No gate pins surface or ink colours: `verify_gradcam_rendering` reads only
`gradcam.colormap`, `alphaLo`, `alphaHi`, `disclaimer`, and
`verify_drishti_report_extended` has no theme references. Only the colormap
swap touches an asserted field.

---

## 2. Responsive layout architecture

Figure becomes `Resize: 'on'` (currently `'off'` at `[40 8 1360 760]`), still
defaulting to 1360x760 and centred. A **1120x680 minimum** is enforced by a
`SizeChangedFcn` on the figure that clamps `Position` back up to the floor
rather than letting the window shrink into unreadable columns; the clamp is
asserted by check 7 below.

```
UIFigure (Resize on)
└── root : uigridlayout [4 1]
    ├── [1] HeaderPanel              fixed 48
    ├── [2]  body : uigridlayout [1 3]   '1x'   <- fills
    │          ├── LeftPanel    '1x'
    │          ├── MiddlePanel  '1.3x'
    │          └── RightPanel   '1.75x'
    ├── [3]  BottomBar                fixed 96
    └── [4]  footer labels            fixed 28   (uilabels, not a panel)
```

Columns are weighted `'1x'`, preserving the current 330/420/578 proportion
rather than holding fixed widths. Footer stays labels so it never becomes a band
competing with the bottom bar.

Per-panel interiors each get their own `uigridlayout`:

- **LeftPanel** `[5 1]`: meta (28) / image axes (`1x`) / resolution line (20) /
  Upload+Analyze (44) / sample dropdown (24)
- **MiddlePanel** `[7 1]`: DR severity / ICDR grade / referral card /
  confidence / P(referable) / model info / advice (`1x`)
- **RightPanel** `[2 4]`: view switcher + view title spanning, then canvas
  (`1x`) beside a 14px colorbar column, disclaimer beneath
- **BottomBar** `[1 3]`: quality row (`1x`) / pipeline progress (`1x`) /
  Generate Report (320)

**Why tractable:** `RetinaAIApp.m` contains zero `.Position =` assignments.
Callbacks mutate only `Text`, `FontColor`, `BackgroundColor`, `Enable`,
`Visible`. Geometry is set once at construction, so the conversion touches only
the five `create*` functions.

### Rewritten `verify_app_layout.m`

The current gate reads `fig.Children` (direct children only, line 90), so
nested grids hide every band and it fails at line 96
(`assert(~isempty(rects))`). A responsive app *cannot* leave this gate
untouched. The rewrite walks the tree and asserts:

1. root container is a `uigridlayout`; figure `Resize` is `'on'`
2. exactly one header band flush to the figure top
3. exactly one bottom bar, the lowest band
4. >=3 content panels sharing one vertical band, ordered left-to-right,
   non-overlapping
5. content panels clear the header and bottom bar
6. no component clipped, no zero/negative extent
7. **new** — repeat 2-6 at **1120x680, 1360x760, 1920x1080**
8. **new** — regression guard that no component sets an absolute `Position`

Assertions 2-6 preserve the original intent. Documented as a deliberate change
under locked rule 5. Check 7 closes the box `EXECUTION_CHECKLIST.md` Phase B
left unticked, and removes the reason the app previously had to disclaim
responsive layout at all.

---

## 3. Content simplification and the dashboard

### Quality: four nested cards -> one strip

`FocusCard`/`IllumCard`/`FovCard`/`OverallChip`
(`RetinaAIApp.m:504-526`) are four separately-bordered panels, each with a tiny
label, a value and a check glyph. They merge into one bordered well with four
cells divided by 1px hairlines, reusing the divider idiom already at
`RetinaAIApp.m:187-189`:

```
FOCUS        ILLUMINATION  FIELD OF VIEW    │ OVERALL
0.87 ✓       0.79 ✓        0.92 ✓           │  ACCEPT
```

Per-metric glyphs stay small, in `success`/`danger`. `OVERALL` becomes the only
saturated fill in the bar.

### Pipeline: five bordered chips -> one progress track

`createBottomBar` (542-571) builds five 79px chips with two-line wrapped
labels; `getStyles` (1196-1246) returns five per-step fields across five
states. These become one hairline track with five dots, short labels and a
state word. `getStyles` collapses to 3 fields (`dot`, `dotColor`,
`labelColor`). All five states remain expressible; `blocked` still marks steps
2-5 as failures.

### Retained verbatim (contractual)

Header `DRISHTI` wordmark; the `ENGINEERING PROTOTYPE - NOT A CLINICAL DEVICE`
tag; the footer human-in-the-loop line; the frozen VALIDATION metrics string;
all disclaimer text. The advice block keeps its prominence but becomes
left-aligned at `metric` weight — `valueLarge` bold centred in a 148px empty
well (`373-381`) currently reads as an unfilled placeholder.

### Dashboard

`DRScreeningDashboard.m` is unthemed and uses `Consolas` throughout. It becomes
token-themed:

| Tab | Now | After |
|---|---|---|
| Overview | 3 Consolas 12pt blobs | KPI tile row + themed pie |
| Performance | 2 `uitable` (absolute `Position`) + Consolas | themed tables; metrics block -> definition list |
| Quality | 2 axes (absolute `Position`) + Consolas | themed charts; status colours from tokens |
| Workload | Consolas 13pt ASCII table with `----` rules | themed `uitable` driven by the slider |
| Inspector | Consolas textarea | **kept monospace**, restyled from tokens |

The hardcoded pie colormap at `DRScreeningDashboard.m:84`
(`[0.35 0.7 0.35; 0.95 0.8 0.35; 0.85 0.32 0.32]`) becomes the token status
colours.

**Monospace is deliberately kept in two places.** The Inspector textarea and
the Workload label: monospace for machine output is conventional, not
unprofessional. The Workload label *must* remain a top-aligned `uilabel`
regardless, because `verify_dashboard.m:46-53` locates it by
`VerticalAlignment:'top'`. The themed table is added alongside it, and no other
top-aligned label is introduced anywhere in the dashboard.

Also converted: the 13 absolute `Position` overrides that fight the dashboard's
own `uigridlayout` (lines 78, 81, 96, 114, 121, 128, 138, 152, 162, 171, 197,
201, 254). Line 138 is a 1220px-wide label inside a narrower panel — an
existing overflow.

### Report

Inherits the light tokens, which is strictly better for print on white paper.
Locked metrics, the non-clinical disclaimer (rule 7) and the Grad-CAM block
content are untouched. One reference PDF is regenerated into `results/` as
evidence the light report renders correctly.

---

## 4. Gates and verification

### Must pass with zero edits

| Gate | Why it survives |
|---|---|
| `verify_retinaai.m` | Text/behavior only. Needs figure name containing `DRISHTI`, one dropdown with placeholder `'(no samples)'`, button text `ANALYZE IMAGE`, the four view-button strings, report lines containing `'DRISHTI Analysis Report'` and one of `ACCEPT/WARNING/REJECT`, the hidden judge-terms badge, a populated recommendation, and the withheld FAIL path. All kept verbatim. |
| `verify_gradcam_rendering.m` | Reads only `gradcam.colormap/alphaLo/alphaHi/disclaimer`. Validates the `parula` swap. |
| `verify_drishti_report_extended.m` | No theme references. |
| `verify_dashboard.m` | Figure name, exactly 5 tabs, 1 slider, 1 dropdown with `NoDR` first, 1 listbox — all preserved. |
| `src/demo/tests/` | Inference contract, untouched. |

### Three gate edits — each replaces fragility with explicit identity

None weakens an assertion.

1. **`verify_app_layout.m`** — rewritten per section 2.
2. **`run_drishti_visual_qa.m:55-63`** — the `p.Position(1) < 50` fundus-axes
   heuristic dies under gridlayout. Replaced with `'Tag','fundusAxes'` and
   selection by tag.
3. **`verify_dashboard.m:45-47`** — selects the *first* label with
   `VerticalAlignment:'top'` and assumes it is the workload output; today this
   works only by luck of `findobj` ordering. Replaced with a tag-based lookup
   that keeps every existing assertion.

### Phases, each independently verifiable

1. `drishtiTokens.m` + `drishtiTheme()` façade + `parula` + the two
   false-comment fixes. No UI touched; proves the token layer alone.
   -> `verify_gradcam_rendering`, `verify_drishti_report_extended`
2. Light repaint of `RetinaAIApp` on today's fixed canvas, geometry untouched.
   Shippable checkpoint. -> old `verify_app_layout`, `verify_retinaai`, visual QA
3. Grid conversion + fundus-axes tag + visual-QA heuristic fix +
   `verify_app_layout` rewrite. -> all gates
4. Content simplification (quality strip, pipeline track, advice block). ->
   `verify_app_layout`, `verify_retinaai`, visual QA
5. Dashboard theming and simplification. -> `verify_dashboard`, visual QA
6. Report light retheme + regenerate one reference PDF into `results/`. ->
   `verify_drishti_report_extended`
7. Docs: `docs/ARCHITECTURE.md`, README, decision log,
   `EXECUTION_CHECKLIST` responsive box, and regenerated
   `results/visual_qa/` screenshots as the evidence record.

Phase 2 is not wasted despite phase 3 replacing its geometry: the colours are
token-driven and carry over unchanged. It is early verification of the palette.

### Silent-failure traps that constrain the work

- `run_drishti_visual_qa.m:122,143,154` drives the app by matching literal
  button strings `'ANALYZE IMAGE'`, `'Save PDF Report'` and the four view
  names. Renaming a button does not raise an error — the harness simply stops
  driving the app. These strings stay verbatim.
- `verify_dashboard.m:46` is addressed by edit 3 above.
- `verify_app_layout.m:91` filters `fig.Children` for
  `isa(c,'matlab.ui.container.Panel')`; a `uigridlayout` is not a Panel, so
  grid containers are invisible to the original filter. Addressed by the
  rewrite.

### Risks

- At 1120x680 the three weighted columns plus fixed rows may not fit, and grid
  components clip rather than refuse. The multi-size assertions prove this
  rather than assume it; if 1120x680 fails, the floor is raised rather than
  the assertion weakened.
- `run_drishti_visual_qa` screenshots rely on `getframe` under headless
  `-batch`, untested at non-default sizes. Committed screenshots are captured
  at the design size; `verify_app_layout` asserts geometry numerically at all
  three sizes.

### Verification limit

The implementer cannot view rendered images. Geometry, contrast ratios and
gate output are verifiable; "looks minimal and professional" is a human
judgement. A visual pass on `results/visual_qa/` is required after phases 2
and 5, and gate output must be reported verbatim rather than summarised as
success.

## Scope note for planning

Seven phases, three surfaces and three gate edits is too large for one
undifferentiated unit of work. Phases 1-2 form the first independently
shippable increment — the new light visual system with every gate still green
and the layout untouched. Phases 3-4 (responsive app) and 5-6 (dashboard and
report) are the second and third increments. The plan must treat each phase as
a separate verified commit rather than one branch-wide change.

## Open items resolved during self-review

- `inkFaint` `#8A93A1` failed contrast on `sunken` (2.79:1) and was replaced
  with `#7C8695`, restricted to non-text marks. Disclaimers moved to
  `inkMuted`.
- Claimed contrast ratios in the first draft were estimates and three were
  wrong (`ink` 17.4 -> 18.32, `inkMuted` 6.4 -> 5.99, `inkFaint` 3.2 -> 3.10).
  All are now measured.
- "Uppercase with letter-spacing" was dropped: `uilabel` has no letter-spacing
  property.
- "One font family throughout" contradicted the two retained monospace
  readouts; the rule is now stated as one UI sans plus monospace for machine
  output only.
- The minimum-window mechanism was unspecified; it is now a figure
  `SizeChangedFcn` clamp, asserted by check 7.