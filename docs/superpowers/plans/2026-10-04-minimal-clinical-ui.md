# Minimal Clinical UI Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the deep-navy DrishtiCare UI with a light clinical visual system, make the screening app responsive, simplify its content, and theme the ops dashboard — with every verification gate green.

**Architecture:** A new `src/ui/drishtiTokens.m` owns every visual decision. `drishtiTheme()` becomes a thin façade over it, keeping all 15 legacy field names so `generateDrishtiReport.m` needs no call-site changes. `RetinaAIApp` converts from absolute positioning on a fixed 1360x760 canvas to nested `uigridlayout`, which is tractable because the class contains zero `.Position =` assignments. `verify_app_layout.m` is rewritten to assert the same band invariants in grid-native terms plus multi-size checks.

**Tech Stack:** MATLAB R2026a (`matlab.apps.AppBase`, `uigridlayout`, `uifigure`), mlreportgen/Edge for the PDF.

**Spec:** `docs/superpowers/specs/2026-10-04-minimal-clinical-ui-design.md`

## Global Constraints

- **Gate invocation** is always, from the repo root: `matlab -batch "run('<repo-relative path>')"`. Every gate is self-contained (computes its own project root and calls `addpath`).
- **`drishtiTheme()` field names are a frozen interface.** `generateDrishtiReport.m` reads exactly these 15: `background`, `panel`, `panelAlt`, `border`, `text`, `textMuted`, `textFaint`, `primary`, `primaryDark`, `success`, `warning`, `danger`, `successBg`, `warningBg`, `dangerBg`. Plus `gradcam.{colormap,alphaLo,alphaHi,limits,interp,colorbarLabel,disclaimer}`, `type.*`, `terms.*`. The façade must keep all of them.
- **Contrast floors:** text ≥ 4.5:1, non-text ≥ 3:1, measured worst-case on `sunken` (the darkest surface). All token values below are pre-verified; worst measured ratio is **4.59:1**.
- **Colormaps available on this R2026a install:** `turbo`, `parula`, `hot`, `gray`, `bone`, `copper`, `jet`, `hsv`, `colorcube`. **`inferno`, `magma`, `plasma`, `viridis`, `cividis` are ABSENT** — referencing them hard-errors.
- **Strings that must not change** (silent-failure contracts): `'ANALYZE IMAGE'`, `'Save PDF Report'`, view names `'Original'`, `'Enhanced'`, `'Grad-CAM'`, `'Overlay'`, dropdown placeholder `'(no samples)'`, figure name containing `'DRISHTI'`, dashboard figure name `'DrishtiCare Screening Dashboard'`, report header `'DRISHTI Analysis Report'`, and `ACCEPT`/`WARNING`/`REJECT` in report text.
- **`th.gradcam.disclaimer` must keep the substring `'not validated lesion localization'`** (`verify_gradcam_rendering.m:200`).
- **Locked, never touched:** threshold 0.60, T=2.5382, model weights and SHA-256 hashes, splits, frozen metrics, `predictSingleFundus`, `src/demo/tests/`.
- **Presentation only.** No change to model outputs, quality thresholds or referral decisions.
- **Monospace is retained** in exactly two machine-output places: the dashboard Inspector textarea and the dashboard Workload label. Everything else uses the platform UI sans (`FontName` left unset).
- Commit after every task. The only exceptions are the two gates that deliberately land red (Tasks 6 and 9), each labelled `EXPECTED RED` and each turned green by the following task. Every other commit lands green.

## File Map

| File | Action | Responsibility |
|---|---|---|
| `src/ui/drishtiTokens.m` | create | Light clinical token source of truth |
| `src/verify/verify_ui_tokens.m` | create | Token contract gate: field presence, contrast floors, colormap availability |
| `src/ui/drishtiTheme.m` | modify | Façade over tokens; frozen field names; `parula` |
| `src/ui/drishtiColormap.m` | modify | Drop dead `inferno` branch; correct docstring |
| `src/reporting/generateDrishtiReport.m` | modify | Three CSS contrast fixes (`.amber`, `.brand`, `th`) |
| `RetinaAIApp.m` | modify | Grid conversion, tags, content simplification |
| `src/dashboard/verify_app_layout.m` | rewrite | Grid-native band invariants + multi-size + Position guard |
| `src/dashboard/run_drishti_visual_qa.m` | modify | Select fundus axes by tag, not `Position(1) < 50` |
| `src/dashboard/DRScreeningDashboard.m` | modify | Theme from tokens; drop 13 absolute Positions; Consolas → components |
| `src/dashboard/verify_dashboard.m` | modify | Tag-based workload-label lookup |
| `docs/project-management/EXECUTION_CHECKLIST.md` | modify | Line 38 claims responsive "not applicable" — now false |
| `docs/project-management/DECISION_LOG.md` | modify | Record the redesign |
| `docs/ARCHITECTURE.md`, `README.md` | modify | Reflect new structure |

---

## Increment 1 — Light token layer

### Task 1: Token contract gate + `drishtiTokens.m`

**Files:**
- Create: `src/verify/verify_ui_tokens.m`
- Create: `src/ui/drishtiTokens.m`

**Interfaces:**
- Produces: `t = drishtiTokens()` returning fields `canvas`, `surface`, `sunken`, `hairline`, `ink`, `inkMuted`, `inkFaint`, `danger`, `success`, `warningFill`, `warningInk`, `primary`, `successBg`, `dangerBg`, `type` (struct with `display`,`metric`,`body`,`label`,`caption`), `spacing` (struct with `s1..s5`).

- [ ] **Step 1: Write the gate**

Create `src/verify/verify_ui_tokens.m`:

```matlab
% verify_ui_tokens.m
% Contract gate for the DrishtiCare light clinical token layer.
%
% Asserts: every token field exists; every text pair clears WCAG AA 4.5:1 and
% every non-text pair clears 3:1, measured worst-case on the darkest surface;
% the theme Grad-CAM colormap actually exists on this MATLAB install.
%
% SCOPE: read-only. Presentation only - touches no model, threshold or metric.
% Run from the repo root:
%   matlab -batch "run('src/verify/verify_ui_tokens.m')"
%
% Terminator on success: ALL UI TOKEN CHECKS PASS

projectRoot = fileparts(fileparts(fileparts(mfilename('fullpath'))));
addpath(projectRoot);
addpath(fullfile(projectRoot, 'src', 'ui'));

fprintf('== UI token contract audit ==\n');
nPass = 0;
t = drishtiTokens();

%% 1. Field presence
required = {'canvas','surface','sunken','hairline','ink','inkMuted','inkFaint', ...
    'danger','success','warningFill','warningInk','primary', ...
    'successBg','dangerBg','type','spacing'};
for k = 1:numel(required)
    assert(isfield(t, required{k}), sprintf('token field missing: %s', required{k}));
    v = t.(required{k});
    if ~isstruct(v)
        assert(isequal(size(v), [1 3]), sprintf('%s must be 1x3 RGB', required{k}));
        assert(all(v >= 0 & v <= 1), sprintf('%s must be within [0 1]', required{k}));
    end
end
for k = 1:5
    assert(isfield(t.type, sprintf('t%d', k)) || ...
           isfield(t.type, {'display','metric','body','label','caption'}{k}), ...
           'type scale incomplete');
end
fprintf('OK  1. all %d token fields present and in range\n', numel(required));
nPass = nPass + 1;

%% 2. Contrast floors - text >= 4.5:1, non-text >= 3:1
textPairs = { ...
    'ink',        t.ink,        'surface', ...
    'ink',        t.ink,        'sunken', ...
    'ink',        t.ink,        'canvas', ...
    'inkMuted',   t.inkMuted,   'surface', ...
    'inkMuted',   t.inkMuted,   'sunken', ...
    'inkMuted',   t.inkMuted,   'canvas', ...
    'inkMuted',   t.inkMuted,   'successBg', ...
    'inkMuted',   t.inkMuted,   'dangerBg', ...
    'danger',     t.danger,     'surface', ...
    'danger',     t.danger,     'sunken', ...
    'danger',     t.danger,     'dangerBg', ...
    'success',    t.success,    'surface', ...
    'success',    t.success,    'successBg', ...
    'warningInk', t.warningInk, t.warningFill, ...
    'primary',    t.primary,    'surface', ...
    'primary',    t.primary,    'sunken'};
worst = Inf;
for k = 1:size(textPairs, 1)
    fg = textPairs{k, 2}; bgv = textPairs{k, 4};
    r = ratio(fg, bgv);
    worst = min(worst, r);
    assert(r >= 4.5, sprintf('%s on %s = %.2f:1, below AA 4.5:1', ...
        textPairs{k,1}, textPairs{k,3}, r));
end
fprintf('OK  2a. %d text pairs clear AA 4.5:1 (worst %.2f:1)\n', size(textPairs,1), worst);
nPass = nPass + 1;

nonTextPairs = {'inkFaint', t.inkFaint, 'surface'; ...
                'inkFaint', t.inkFaint, 'sunken'; ...
                'inkFaint', t.inkFaint, 'canvas'};
worstN = Inf;
for k = 1:size(nonTextPairs, 1)
    r = ratio(nonTextPairs{k,2}, nonTextPairs{k,3});
    worstN = min(worstN, r);
    assert(r >= 3.0, sprintf('inkFaint on surface = %.2f:1, below 3:1 non-text floor', r));
end
fprintf('OK  2b. inkFaint clears 3:1 on every surface (worst %.2f:1)\n', worstN);
nPass = nPass + 1;

%% 3. White on primary (button label)
r = ratio([1 1 1], t.primary);
assert(r >= 4.5, sprintf('white on primary = %.2f:1, below 4.5:1', r));
fprintf('OK  3. white on primary %.2f:1\n', r);
nPass = nPass + 1;

%% 4. The Grad-CAM colormap named by the theme must exist on THIS install
th = drishtiTheme();
cm = th.gradcam.colormap;
assert(exist(cm, 'file') == 2 || exist(cm, 'builtin') == 5, ...
    sprintf('theme colormap "%s" is not available in this MATLAB install', cm));
fprintf('OK  4. theme colormap "%s" resolves on this install\n', cm);
nPass = nPass + 1;

%% 5. Spacing scale is a 4px progression
sp = [t.spacing.s1 t.spacing.s2 t.spacing.s3 t.spacing.s4 t.spacing.s5];
assert(all(diff(sp) > 0), 'spacing scale must increase');
assert(all(mod(sp, 4) == 0), 'spacing scale must be a multiple of 4');
fprintf('OK  5. spacing scale [%s] is a 4px progression\n', num2str(sp));
nPass = nPass + 1;

fprintf('\nCHECKS: %d\n', nPass);
fprintf('ALL UI TOKEN CHECKS PASS\n');

% -------------------------------------------------------------------------
function r = ratio(a, b)
L1 = relLum(a); L2 = relLum(b);
hi = max(L1, L2); lo = min(L1, L2);
r = (hi + 0.05) / (lo + 0.05);
end

function L = relLum(rgb)
v = double(rgb);
lo = v <= 0.03928;
v(lo) = v(lo) / 12.92;
hi = ~lo;
v(hi) = ((v(hi) + 0.055) / 1.055) .^ 2.4;
L = 0.2126 * v(1) + 0.7152 * v(2) + 0.0722 * v(3);
end
```

- [ ] **Step 2: Run it to verify it fails**

Run: `matlab -batch "run('src/verify/verify_ui_tokens.m')"`
Expected: FAIL — `Unrecognized function or variable 'drishtiTokens'`

- [ ] **Step 3: Write `src/ui/drishtiTokens.m`**

```matlab
function t = drishtiTokens()
%DRISHTITOKENS Single source of truth for the DrishtiCare light clinical UI.
%   t = drishtiTokens()
%
%   Every colour, type size and spacing step used by the RetinaAIApp dashboard,
%   the DRScreeningDashboard and the generateDrishtiReport PDF. drishtiTheme()
%   is a thin facade over this file, so the app and the printed report cannot
%   drift apart.
%
%   Palette intent (light clinical):
%     canvas/surface/sunken  three surface levels plus ONE border colour
%     ink/inkMuted           all text; inkFaint is NON-TEXT ONLY
%     danger/success/warning the three decision tones
%     primary                the single accent, used at most twice on screen
%
%   All colour pairs are verified by src/verify/verify_ui_tokens.m against
%   WCAG AA (text >= 4.5:1, non-text >= 3:1), worst case on `sunken`.
%
%   The theme only owns PRESENTATION. It never changes model outputs, quality
%   thresholds, referral decisions or any engineering value.
%
%   ENGINEERING prototype styling. NOT a clinical device.

    t = struct();

    %% ---- surfaces -------------------------------------------------------
    t.canvas    = hex2rgb('#F7F8FA');   % figure background
    t.surface   = hex2rgb('#FFFFFF');   % panels, cards
    t.sunken    = hex2rgb('#F1F3F6');   % axes wells, advice box
    t.hairline  = hex2rgb('#E3E6EB');   % the ONLY border colour, 1px

    %% ---- ink ------------------------------------------------------------
    t.ink       = hex2rgb('#10151C');   % 18.32:1 on surface - values, headings
    t.inkMuted  = hex2rgb('#5A6473');   %  5.99:1 - ALL body text, labels, DISCLAIMERS
    t.inkFaint  = hex2rgb('#7C8695');   %  3.68:1 - NON-TEXT ONLY (ticks, numerals)

    %% ---- decision tones -------------------------------------------------
    t.danger     = hex2rgb('#C0392B');  % referable / FAIL / reject
    t.success    = hex2rgb('#1E7A46');  % accept / not-referable
    t.primary    = hex2rgb('#14539E');  % the single accent
    t.dangerBg   = hex2rgb('#FAEAE8');  % tinted fills (danger text on this: 4.66:1)
    t.successBg  = hex2rgb('#E4F1E8');  % tinted fills (success text on this: 4.59:1)
    % Amber is never used as text on a light surface (~2:1). It is a tinted
    % fill with dark ink instead.
    t.warningFill = hex2rgb('#FDF0D5');
    t.warningInk  = hex2rgb('#7A5200');  % 6.13:1 on warningFill

    %% ---- typographic scale: ten sizes collapsed to five -------------------
    t.type = struct( ...
        'display', 18, ...  % application title
        'metric',  15, ...  % headline values (replaces valueHero + valueLarge)
        'body',    11, ...  % values, table text
        'label',   10, ...  % labels and section titles (uppercase)
        'caption',  9);     % disclaimers, units, footnotes

    %% ---- spacing: 4px progression ----------------------------------------
    t.spacing = struct('s1', 4, 's2', 8, 's3', 12, 's4', 16, 's5', 24);

end

% -------------------------------------------------------------------------
function rgb = hex2rgb(h)
%HEX2RGB '#RRGGBB' -> 1x3 double in [0 1].
    rgb = double(sscanf(h(2:end), '%2x%2x%2x')) / 255;
end
```

- [ ] **Step 4: Run it to verify it passes**

Run: `matlab -batch "run('src/verify/verify_ui_tokens.m')"`
Expected: may still fail on check 4 because `drishtiTheme()` has not been
converted yet and still reports `turbo`; `turbo` resolves, so this passes.
Expected final line: `ALL UI TOKEN CHECKS PASS`

- [ ] **Step 5: Commit**

```powershell
git add src/ui/drishtiTokens.m src/verify/verify_ui_tokens.m
git commit -m "feat(ui): add the light clinical token layer with an AA contrast gate"
```

---

### Task 2: `drishtiTheme()` as a façade over the tokens

**Files:**
- Modify: `src/ui/drishtiTheme.m` (rewrite lines 24-90, keep the signature)

**Interfaces:**
- Consumes: `drishtiTokens()` from Task 1
- Produces: unchanged 15 legacy field names plus `gradcam`, `type`, `terms`

- [ ] **Step 1: Replace the colour block (lines 26-68) with facade assignments**

In `src/ui/drishtiTheme.m`, replace everything from `th = struct();` through the
end of the `%% ---- typographic scale` block with:

```matlab
    th = struct();
    tk = drishtiTokens();

    %% ---- surfaces (light clinical; three levels + one border) ----
    th.background   = tk.canvas;
    th.panel        = tk.surface;
    th.panelAlt     = tk.surface;
    th.panelDeep    = tk.sunken;
    th.border       = tk.hairline;
    th.borderLight  = tk.hairline;

    %% ---- semantic accent colours ----
    th.primary      = tk.primary;
    th.primaryDark  = hexdark(tk.primary);
    th.primaryBg    = tk.sunken;
    th.success      = tk.success;
    th.warning      = tk.warningInk;
    th.danger       = tk.danger;
    th.info         = tk.inkMuted;

    th.successBg    = tk.successBg;
    th.warningBg    = tk.warningFill;
    th.dangerBg     = tk.dangerBg;

    %% ---- text colours ----
    th.text         = tk.ink;
    th.textMuted    = tk.inkMuted;
    th.textFaint    = tk.inkFaint;

    %% ---- token-name aliases ----
    % The app and dashboard code read the palette by its token name, so expose
    % the token vocabulary alongside the legacy one. Purely additive: none of
    % these shadow a legacy field.
    th.surface      = tk.surface;
    th.sunken       = tk.sunken;
    th.hairline     = tk.hairline;
    th.ink          = tk.ink;
    th.spacing      = tk.spacing;

    %% ---- status colour maps (PASS / WARNING / FAIL) ----
    th.status = struct('PASS', th.success, 'WARNING', th.warning, 'FAIL', th.danger);
    th.statusBg = struct('PASS', th.successBg, 'WARNING', th.warningBg, 'FAIL', th.dangerBg);

    %% ---- typographic scale (presentation-consistent hierarchy) ----
    th.type = struct( ...
        'appTitle',     tk.type.display, ...
        'sectionTitle', tk.type.label, ...
        'panelTitle',   tk.type.label, ...
        'label',        tk.type.body, ...
        'labelSmall',   tk.type.label, ...
        'value',        tk.type.body, ...
        'valueLarge',   tk.type.metric, ...
        'valueHero',    tk.type.metric, ...
        'support',      tk.type.caption, ...
        'tiny',         tk.type.caption);
```

- [ ] **Step 2: Add the `hexdark` local function before the final `end`**

```matlab
% -------------------------------------------------------------------------
function rgb = hexdark(c)
%HEXDARK Darken an accent for hover/pressed states, for the light theme.
    rgb = c * 0.75;
end
```

- [ ] **Step 3: Run both gates**

Run: `matlab -batch "run('src/verify/verify_ui_tokens.m')"`
Expected: `ALL UI TOKEN CHECKS PASS`

Run: `matlab -batch "run('src/verify/verify_gradcam_rendering.m')"`
Expected: `ALL GRADCAM RENDERING AUDIT CHECKS PASS` — the `alphaLo`/`alphaHi`/
`disclaimer` contract is untouched.

- [ ] **Step 4: Commit**

```powershell
git add src/ui/drishtiTheme.m
git commit -m "refactor(ui): make drishtiTheme a facade over drishtiTokens"
```

---

### Task 3: `parula` Grad-CAM map and the two false colormap claims

**Files:**
- Modify: `src/ui/drishtiTheme.m:72` (the `g.colormap` line)
- Modify: `src/ui/drishtiColormap.m:4` (docstring) and `:21-22` (dead branch)

- [ ] **Step 1: Swap the colormap and correct the claim**

In `src/ui/drishtiTheme.m`, replace the `g.colormap` line and its comment:

```matlab
    % Colormaps verified present in this R2026a install: turbo, parula, hot,
    % gray, bone, copper, jet, hsv, colorcube. inferno/magma/plasma/viridis/
    % cividis are ABSENT and referencing them hard-errors. parula is chosen
    % over turbo because it is perceptually uniform and colour-vision-
    % deficiency-friendly, and it clears verify_gradcam_rendering's endpoint
    % budget (3.13% of 10%) and alpha-conditioning floor (86.5% of 20%).
    g.colormap   = 'parula';
```

- [ ] **Step 2: Remove the dead `inferno` branch and fix the docstring**

In `src/ui/drishtiColormap.m`, delete the two `inferno` lines (the
`case 'inferno'` branch occupies lines 20-21; deleting lines 20-22 would orphan
`map = parula(256);`) so the switch reads:

```matlab
    switch lower(name)
        case 'parula'
            map = parula(256);
        case 'hot'
            map = hot(256);
        otherwise
            map = turbo(256);
    end
```

Do not add a `bone` or `copper` branch: copper is a documented 28.125%
endpoint fail and bone's 9.375% leaves a 0.6pp margin, and the gate resolves
only the theme colormap so it would never catch either.

And replace the docstring example on line 4:

```matlab
%   map = drishtiColormap('hot')
```

- [ ] **Step 3: Run the Grad-CAM gate**

Run: `matlab -batch "run('src/verify/verify_gradcam_rendering.m')"`
Expected: `OK  0. colormap parula is 256 x 3, low->high` and final line
`ALL GRADCAM RENDERING AUDIT CHECKS PASS`

- [ ] **Step 4: Commit**

```powershell
git add src/ui/drishtiTheme.m src/ui/drishtiColormap.m
git commit -m "fix(ui): swap the Grad-CAM map to parula and drop the dead inferno branch

turbo is a rainbow map. parula is perceptually uniform and CVD-friendly, and
measures inside verify_gradcam_rendering's budgets (endpoint 3.13% of 10%,
alpha conditioning 86.5% of 20%). hot (203%) and copper (28%) fail.

The theme claimed inferno was available in R2026a; it is not, and
drishtiColormap advertised it as a usage example while its branch would
hard-error."
```

---

### Task 4: Report CSS contrast fixes

**Files:**
- Modify: `src/reporting/generateDrishtiReport.m:482,488,496`

**Interfaces:**
- Consumes: the `warning` -> `warningInk` and `background` -> `canvas` remapping from Task 2

Without this the report inverts into unreadable pairs: `.amber` would render
light-amber text on a light-amber fill, and `.brand` would render dark text on
the off-white canvas.

- [ ] **Step 1: Fix the `.amber` rule (line 488)**

```matlab
fprintf(h, '.amber{background:%s;color:%s;}\n', hex(th.warningBg), hex(th.warning));
```

becomes:

```matlab
fprintf(h, '.amber{background:%s;color:%s;}\n', hex(th.warningBg), hex(th.text));
```

`th.warning` is now the dark amber ink on the amber fill; `th.text` is the
neutral ink, which reads correctly on every status fill including amber.

- [ ] **Step 2: Fix the `.brand` rule (line 482)**

```matlab
fprintf(h, '.brand{background:%s;color:%s;padding:14px 18px;border-radius:6px;}\n', hex(th.background), hex(th.text));
```

becomes:

```matlab
fprintf(h, '.brand{background:%s;color:%s;border-left:3px solid %s;padding:14px 18px;border-radius:6px;}\n', hex(th.sunken), hex(th.text), hex(th.primary));
```

- [ ] **Step 3: Fix the table header rule (line 496)**

```matlab
fprintf(h, 'th{background:%s;color:%s;}\n', hex(th.panel), hex(th.text));
```

becomes:

```matlab
fprintf(h, 'th{background:%s;color:%s;}\n', hex(th.sunken), hex(th.textMuted));
```

- [ ] **Step 4: Run the report gate**

Run: `matlab -batch "run('src/reporting/verify_drishti_report_extended.m')"`
Expected: `ALL DRISHTI REPORT EXTENDED CHECKS PASS`

- [ ] **Step 5: Commit**

```powershell
git add src/reporting/generateDrishtiReport.m
git commit -m "fix(report): keep status fills readable under the light theme

Inverting the palette turns .amber into light-amber-on-light-amber and .brand
into dark-on-off-white. All three rules now pair a tinted fill with the
neutral ink, and .brand carries the accent as a left rule."
```

---

## Increment 2 — Responsive app

### Task 5: Tag the fundus axes; fix the visual-QA heuristic

**Files:**
- Modify: `RetinaAIApp.m:237-242` (add `'Tag','fundusAxes'`)
- Modify: `src/dashboard/run_drishti_visual_qa.m:55-63`

`run_drishti_visual_qa.m:59` finds the fundus axes by `p.Position(1) < 50`,
which is a positional coincidence that cannot survive a layout change.

- [ ] **Step 1: Tag the axes in `RetinaAIApp.m`**

Add `'Tag', 'fundusAxes', ...` to the `uiaxes` property list at line 237.

- [ ] **Step 2: Select by tag in `run_drishti_visual_qa.m`**

Replace lines 55-63 with:

```matlab
    fundusAx = findobj(a.UIFigure, 'Type', 'axes', 'Tag', 'fundusAxes');
    if ~isempty(fundusAx)
        saveShot(fundusAx, qaDir, sprintf('04_%s_fundus.png', tag), []);
    end
```

- [ ] **Step 3: Run the existing gates**

Run: `matlab -batch "run('src/dashboard/verify_app_layout.m')"`
Expected: `ALL DRISHTI APP LAYOUT CHECKS PASS` (the tag is additive; geometry is
unchanged)

- [ ] **Step 4: Commit**

```powershell
git add RetinaAIApp.m src/dashboard/run_drishti_visual_qa.m
git commit -m "refactor(qa): find the fundus axes by tag instead of by position

The harness located it with p.Position(1) < 50, a coincidence of the current
fixed layout that would silently screenshot the wrong axes after any relayout."
```

---

### Task 6: Rewrite `verify_app_layout.m` for grid traversal (expect RED)

**Files:**
- Modify: `src/dashboard/verify_app_layout.m` (rewrite)

The new gate must be written and committed while it still **fails** against the
current absolute-positioned app. That red run is the proof the gate detects the
problem; it is turned green in Task 7. This is the one intentional red commit
in the plan, and it is labelled as such.

- [ ] **Step 1: Rewrite the gate**

Replace **only** the band-discovery section — the current `%% 3. The layout
bands must tile without overlap` block at lines 84-143. The `%% 2. Walk every
descendant` traversal above it stays as it is; the block below must not repeat it.
After the band checks, insert the new `%% 4` grid check, and renumber the
existing screen-fit section from `%% 4` to `%% 6` (Task 8's multi-size loop later
lands as `%% 5`, between them).

Replacement band section:

```matlab
%% 3. The layout bands must tile without overlap
% Bands are the app's top-level bands, not every nested panel: they are found by
% walking down at most two grid levels from the figure. `fig.Children` is not
% usable - it returns only the root container once the bands are nested inside
% uigridlayout, and a uigridlayout is deliberately not a
% matlab.ui.container.Panel, so the Panel filter over fig.Children matched
% nothing at all. The panel interiors in turn contain nested panels (the quality
% well, the pipeline track) which are deliberately EXCLUDED here: they are not
% bands, and counting them would break the shared-band assertion below.
rects = bandRects(fig);
assert(~isempty(rects), 'the figure exposes at least one layout band');
fprintf('INFO bands discovered      = %d\n', size(rects, 1));

topY   = rects(:, 2) + rects(:, 4);
isHead = abs(topY - figT) < 0.5;    % flush with the top of the canvas
nHead  = sum(isHead);
assert(nHead == 1, 'exactly one header band sits flush with the top');

rest   = rects(~isHead, :);
minY   = min(rest(:, 2));
isFoot = ~isHead & abs(rects(:, 2) - minY) < 0.5;
nFoot  = sum(isFoot);
assert(nFoot == 1, 'exactly one bottom bar is the lowest band');

isBody = ~isHead & ~isFoot;
nBody  = sum(isBody);
fprintf('INFO layout bands         = %d header, %d content, %d bottom\n', ...
    nHead, nBody, nFoot);
assert(nBody >= 3, 'at least three content panels tile the middle of the canvas');

head = rects(isHead, :);
foot = rects(isFoot, :);
body = sortrows(rects(isBody, :), 1);
for i = 1:nBody
    fprintf('INFO content panel %d     [%g %g %g %g]\n', i, body(i,1), body(i,2), body(i,3), body(i,4));
end
for i = 1:nBody-1
    a = body(i, :); b = body(i+1, :);
    assert(a(2) == b(2) && a(4) == b(4), ...
        'content panels %d and %d share the same vertical band', i, i+1);
    assert(a(1) + a(3) <= b(1) + 0.5, ...
        'content panel %d ends before panel %d begins (no overlap)', i, i+1);
end
fprintf('OK  2. %d content panels share one band and are ordered left to right\n', nBody);
nPass = nPass + 1;

footTop = foot(2) + foot(4);
headBot = head(2);
for i = 1:nBody
    q = body(i, :);
    assert(q(2) >= footTop - 0.5, 'content panel %d clears the bottom bar', i);
    assert(q(2) + q(4) <= headBot + 0.5, 'content panel %d clears the header band', i);
end
fprintf('OK  3. content panels clear the header band (y<=%g) and bottom bar (y>=%g)\n', ...
    headBot, footTop);
nPass = nPass + 1;
```

Then insert the new grid check immediately after that block, still **before** the
screen-fit section:

```matlab
%% 4. The app must be grid-driven and resizable
grids = findall(fig, 'Type', 'uigridlayout');
assert(~isempty(grids), 'the app must be built on a uigridlayout root');
isFixed = strcmpi(char(fig.Resize), 'off');
assert(~isFixed, 'the figure must be resizable (Resize on), not a fixed canvas');
fprintf('OK  4. grid-driven root (%d uigridlayout containers), Resize=%s\n', ...
    numel(grids), char(fig.Resize));
nPass = nPass + 1;
```

And add the band-discovery helper alongside the other local functions:

```matlab
% -------------------------------------------------------------------------
function rects = bandRects(fig)
%BANDRECTS Absolute rectangles of the app's top-level layout bands.
%   A band is a uipanel sitting directly on the root grid, or directly on a grid
%   that sits directly on the root grid. Panels nested deeper (inside a band) are
%   interiors, not bands.
grids = findall(fig, 'Type', 'uigridlayout');
rects = [];
for g = 1:numel(grids)
    kids = findall(grids(g));
    kids = kids(arrayfun(@(c) isa(c, 'matlab.ui.container.Panel') && ...
        ~isa(c, 'matlab.ui.container.GridLayout'), kids));
    % keep only direct children of this grid
    kids = kids(cellfun(@(c) isequal(c.Parent, grids(g)), num2cell(kids)));
    for i = 1:numel(kids)
        rects(end+1, :) = absPos(kids(i), fig); %#ok<AGROW>
    end
end
end
```

Rename the existing `%% 4. Does the default window fit the current screen?`
heading to `%% 6. ...`.

Also delete the now-unused local function `overlaps` (current lines 215-217).

- [ ] **Step 2: Run it — expect RED**

Run: `matlab -batch "run('src/dashboard/verify_app_layout.m')"`
Expected: FAIL at check 4 with
`the app must be built on a uigridlayout root`. Checks 1-3 should pass, proving
the band traversal now works over the top-level bands.

- [ ] **Step 3: Commit the red gate with an explicit message**

```powershell
git add src/dashboard/verify_app_layout.m
git commit -m "test(gate): require a grid-driven, resizable app layout

EXPECTED RED until the RetinaAIApp grid conversion lands. The band assertions
are unchanged in intent; what changes is discovery. The old gate read
fig.Children, which returns only the root container once the bands are nested
inside uigridlayout - and a uigridlayout is deliberately not a
matlab.ui.container.Panel, so the Panel filter over fig.Children matched
nothing. Bands are now discovered with findall over the whole tree.

Also adds check 4: the app must be grid-driven with Resize on."
```

---

### Task 7: Root grid layout + header + footer

**Files:**
- Modify: `RetinaAIApp.m:151-167` (`createComponents`), `:169-208` (`createHeader`), `:635-650` (`createFooter`), `:32-36` and `:112` (properties)

**Interfaces:**
- Consumes: `drishtiTokens()`; produces the band structure Task 6's gate asserts

- [ ] **Step 1: Add the root grid property**

Add after the `BottomBar` property (line 36):

```matlab
        RootGrid           matlab.ui.container.GridLayout
```

and add `BodyGrid` beside it. Both are `Access = private`, consistent with the
existing layout-container properties.

- [ ] **Step 2: Replace `createComponents`**

```matlab
        function createComponents(app)
            % Window: resizable. Root grid owns the bands; every panel interior
            % is its own grid (see createImageSection et al).
            th = drishtiTheme();
            app.UIFigure = uifigure('Name', 'DRISHTI - Explainable AI for DR Screening', ...
                'Position', [40 60 1360 760], ...
                'Color', th.background, ...
                'Resize', 'on');

            app.RootGrid = uigridlayout(app.UIFigure, [4 1]);
            app.RootGrid.RowHeight = {48, '1x', 96, 28};
            app.RootGrid.Padding = [0 0 0 0];
            app.RootGrid.RowSpacing = 0;
            app.RootGrid.BackgroundColor = th.background;

            app.BodyGrid = uigridlayout(app.RootGrid, [1 3]);
            app.BodyGrid.ColumnWidth = {'1x', '1.3x', '1.75x'};
            app.BodyGrid.Padding = [0 0 0 0];
            app.BodyGrid.RowSpacing = 0;
            app.BodyGrid.BackgroundColor = th.background;

            createHeader(app);
            createImageSection(app);
            createResultSection(app);
            createEvidenceSection(app);
            createBottomBar(app);
            createFooter(app);
            app.setStatus('System Ready', 'ok');
            app.setPipelineState('idle');
            app.enforceMinSize();
        end
```

- [ ] **Step 3: Reparent `createHeader`**

Change the `uipanel` parent from `app.UIFigure` to `app.RootGrid`, delete its
`'Position'` argument, and add the layout row:

```matlab
            app.HeaderPanel = uipanel(app.RootGrid, ...
                'BackgroundColor', th.panelDeep, ...
                'BorderType', 'line', 'BorderColor', th.border, 'BorderWidth', 1);
```

All child positions inside the header stay as they are — the header keeps its
own internal pixel layout, which is legitimate because it has a fixed 48px row
height.

- [ ] **Step 4: Reparent the three content panels**

In `createImageSection`, `createResultSection` and `createEvidenceSection`,
change the parent from `app.UIFigure` to `app.BodyGrid` and delete each
`'Position'` argument. Add `Padding` so panel titles are not flush:

```matlab
            app.LeftPanel = uipanel(app.BodyGrid, ...
                'Title', ' RETINAL IMAGE ', ...
                'FontSize', th.type.sectionTitle, 'FontWeight', 'bold', ...
                'ForegroundColor', th.textMuted, ...
                'BackgroundColor', th.panel, ...
                'BorderType', 'line', 'BorderColor', th.border);
```

The internal child positions remain valid because `BodyGrid` allocates each
panel its full grid cell and the panel's own coordinate origin is unchanged.

- [ ] **Step 5: Reparent `createBottomBar` and `createFooter`**

Change `createBottomBar`'s parent to `app.RootGrid`, delete its `'Position'`.
Change `createFooter`'s labels to live in a transparent grid rather than the
figure, so they do not overlap the root grid:

```matlab
        function createFooter(app)
            th = drishtiTheme();
            fg = uigridlayout(app.RootGrid, [1 2]);
            fg.ColumnWidth = {'1x', '1x'};
            fg.Padding = [8 0 8 0];
            fg.BackgroundColor = th.background;

            app.FooterLabel = uilabel(fg, ...
                'Text', 'Human-in-the-loop: final clinical decision by a qualified ophthalmologist.', ...
                'FontSize', th.type.support, ...
                'FontColor', th.textMuted, 'HorizontalAlignment', 'left');

            app.MetricsLabel = uilabel(fg, ...
                'Text', ['VALIDATION  ·  Accuracy 82.81%  ·  ' ...
                         'Referable sensitivity 90.60%  ·  Specificity 94.71%  ·  ' ...
                         'APTOS held-out validation  ·  Prototype, not clinically validated'], ...
                'FontSize', th.type.support, ...
                'FontColor', th.textMuted, 'HorizontalAlignment', 'right');
        end
```

- [ ] **Step 6: Add the minimum-size clamp**

Add as a new private method, and call it from `createComponents` (Step 2):

```matlab
        function enforceMinSize(app)
            % Clamp the window to the documented 1120x680 floor rather than
            % letting the three weighted columns collapse into each other.
            if ~isvalid(app.UIFigure), return; end
            p = app.UIFigure.Position;
            w = max(p(3), 1120);
            h = max(p(4), 680);
            if w ~= p(3) || h ~= p(4)
                app.UIFigure.Position = [p(1) + (p(3) - w) / 2, ...
                                         p(2) + (p(4) - h) / 2, w, h];
            end
        end
```

- [ ] **Step 7: Run the gate — expect GREEN**

Run: `matlab -batch "run('src/dashboard/verify_app_layout.m')"`
Expected: `OK  4. grid-driven root, Resize=on` and
`ALL DRISHTI APP LAYOUT CHECKS PASS`

If check 2 fails with more or fewer than three content panels, a panel was not
reparented — check that each of the three content panels is a child of
`BodyGrid`, not of the figure.

- [ ] **Step 8: Run the app gate too**

Run: `matlab -batch "run('src/dashboard/verify_retinaai.m')"`
Expected: `ALL RETINAAI CHECKS PASS` — this drives the real callbacks, so it
confirms nothing broke functionally.

- [ ] **Step 9: Commit**

```powershell
git add RetinaAIApp.m src/dashboard/verify_app_layout.m
git commit -m "feat(app): drive the band structure from a resizable root grid

The app had zero .Position assignments outside construction, so the five
create* functions were the only place geometry was decided. Bands are now
allocated by nested uigridlayout; the header and footer keep fixed row heights,
and the three content columns are weighted 1x/1.3x/1.75x to hold the previous
330/420/578 proportion at any window size.

Adds a SizeChangedFcn-free clamp (enforceMinSize) that refuses to shrink below
1120x680. Turns the layout gate green."
```

---

### Task 8: Multi-size assertions

**Files:**
- Modify: `src/dashboard/verify_app_layout.m` (add a section before cleanup)

- [ ] **Step 1: Add the multi-size loop**

Insert before the screen-fit section (the one headed
`%% 6. Does the default window fit the current screen?`, after Task 6's
renumbering):

```matlab
%% 5. The band structure must survive resizing
% This is the assertion EXECUTION_CHECKLIST.md Phase B could previously not
% make: the old app was fixed-canvas, so multi-size behaviour was reported as
% "not applicable" rather than untested.
sizes = {[1120 680], [1360 760], [1920 1080]};
nSizePass = 0;
for s = 1:numel(sizes)
    target = sizes{s};
    app.UIFigure.Position = [40 60 target(1) target(2)];
    drawnow;
    got = app.UIFigure.Position;
    fprintf('INFO requested %dx%d -> actual %gx%g\n', ...
        target(1), target(2), got(3), got(4));
    assert(got(3) >= 1120 - 0.5 && got(4) >= 680 - 0.5, ...
        sprintf('window %dx%d was clamped below the 1120x680 floor', got(3), got(4)));

    its = collect(fig, 0, 0);
    bad = 0;
    for k = 1:numel(its)
        p = its(k).pos;
        if p(3) <= 0 || p(4) <= 0
            bad = bad + 1;
            continue;
        end
        if p(1) < -0.5 || p(2) < -0.5 || ...
           p(1) + p(3) > got(3) + 0.5 || p(2) + p(4) > got(4) + 0.5
            bad = bad + 1;
            if bad <= 5
                fprintf('WARN %s outside canvas at %dx%d: [%g %g %g %g]\n', ...
                    its(k).name, got(3), got(4), p(1), p(2), p(3), p(4));
            end
        end
    end
    assert(bad == 0, sprintf('%d components escape the canvas at %gx%g', bad, got(3), got(4)));

    % Same band definition as check 2: top-level bands only, so the nested
    % panels inside the content panels and the bottom bar are not counted.
    rr = bandRects(fig);
    tY = rr(:, 2) + rr(:, 4);
    iH = abs(tY - got(4)) < 0.5;
    assert(sum(iH) == 1, sprintf('expected 1 header band at %dx%d, found %d', ...
        got(3), got(4), sum(iH)));
    r2 = rr(~iH, :);
    mY = min(r2(:, 2));
    iF = ~iH & abs(rr(:, 2) - mY) < 0.5;
    assert(sum(iF) == 1, sprintf('expected 1 bottom band at %dx%d, found %d', ...
        got(3), got(4), sum(iF)));
    bB = sortrows(rr(~iH & ~iF, :), 1);
    assert(size(bB, 1) >= 3, sprintf('expected >=3 content panels at %dx%d', got(3), got(4)));
    for i = 1:size(bB, 1)-1
        assert(bB(i, 2) == bB(i+1, 2) && bB(i, 4) == bB(i+1, 4), ...
            sprintf('content panels %d/%d lose their shared band at %dx%d', ...
            i, i+1, got(3), got(4)));
        assert(bB(i, 1) + bB(i, 3) <= bB(i+1, 1) + 0.5, ...
            sprintf('content panels %d/%d overlap at %dx%d', i, i+1, got(3), got(4)));
    end
    fprintf('OK  5.%d. bands hold at %gx%g (%d descendants, 0 escaping)\n', ...
        s, got(3), got(4), numel(its));
    nSizePass = nSizePass + 1;
end
fprintf('OK  5. band structure and clipping verified at %d window sizes\n', nSizePass);
nPass = nPass + 1;

% restore the design size for the screen-fit report
app.UIFigure.Position = [40 60 1360 760];
drawnow;
```

- [ ] **Step 2: Run it**

Run: `matlab -batch "run('src/dashboard/verify_app_layout.m')"`
Expected: three `OK  5.x` lines and `ALL DRISHTI APP LAYOUT CHECKS PASS`

If the 1120x680 assertion fires, raise the floor in `enforceMinSize` and in
this test rather than relaxing the assertion.

- [ ] **Step 3: Commit**

```powershell
git add src/dashboard/verify_app_layout.m
git commit -m "test(gate): verify the band structure at three window sizes

EXECUTION_CHECKLIST.md recorded multi-size responsive layout as 'not
applicable, not merely untested' because the app was a fixed canvas. The grid
conversion makes it applicable, so it is now asserted: no component escapes
the canvas, and exactly one header band, one bottom band and >=3 ordered
content panels survive at 1120x680, 1360x760 and 1920x1080."
```

---

### Task 9: No absolute `Position` regression guard

**Files:**
- Modify: `src/dashboard/verify_app_layout.m` (add before cleanup)

The guard is a **source-level** check, not a runtime one, and that is not a
compromise — it is the only formulation that works. Every child of a
`uigridlayout` has a derived four-element `Position` and a GridLayout parent, so
a runtime probe that flags "child of a grid with a 4-element Position" flags
*every* component and can never turn green. Reading the class source is the only
way to observe what the author actually wrote.

- [ ] **Step 1: Add the guard**

```matlab
%% 7. No component constructor may set an absolute Position
% Guards the responsive property against erosion: if a future change
% reintroduces hand-placed coordinates, the grid would silently stop driving
% the layout and the app would freeze at one size again.
srcFile = fullfile(projectRoot, 'RetinaAIApp.m');
srcLines = splitlines(string(fileread(srcFile)));
% A 'Position' property-name argument to a component constructor.
isPosArg = contains(srcLines, "'Position'");
% A .Position assignment.
isPosSet = contains(srcLines, ".Position =");
% Exactly two writes are legitimate: the figure's own canvas, and the
% enforceMinSize clamp that sets it. Both are matched by literal, so a change
% to either fails the gate loudly rather than silently widening the allowlist.
allowed = false(numel(srcLines), 1);
allowed(contains(srcLines, "'Position', [40 60 1360 760]")) = true;   % createComponents
allowed(contains(srcLines, "app.UIFigure.Position =")) = true;          % enforceMinSize
offenders = find((isPosArg | isPosSet) & ~allowed);
assert(isempty(offenders), sprintf( ...
    ['RetinaAIApp.m sets an absolute Position on %d line(s); the layout is ' ...
     'no longer grid-driven:\n%s'], numel(offenders), ...
    strjoin(cellstr(srcLines(offenders)), sprintf('\n'))));
fprintf('OK  7. no component constructor sets an absolute Position (%d allowlisted)\n', ...
    sum(allowed));
nPass = nPass + 1;
```

- [ ] **Step 2: Run it — expect RED**

Run: `matlab -batch "run('src/dashboard/verify_app_layout.m')"`
Expected: FAIL, echoing the offending source lines. This is expected: the panel
interiors still pass hand-placed `'Position'` arguments.

- [ ] **Step 3: Leave it red until Task 10, and record why**

```powershell
git add src/dashboard/verify_app_layout.m
git commit -m "test(gate): forbid absolute positioning inside a grid (EXPECTED RED)

Lands ahead of the panel-interior conversion so the guard is proven to detect
the condition it exists to prevent. Turns green in the following commit.

Checked at the source level rather than at runtime: every uigridlayout child
carries a derived four-element Position, so a runtime probe cannot tell an
author-set position from a grid-computed one and would flag every component
forever."
```

---

### Task 10: Panel interiors to grids (turns Task 9 green)

**Files:**
- Modify: `RetinaAIApp.m` — `createImageSection`, `createResultSection`, `createEvidenceSection`, `createBottomBar`

Each panel gets a `uigridlayout` parent; child `'Position'` arguments are
deleted and the layout arrays become rows/columns.

- [ ] **Step 1: `createImageSection` interior**

Insert at the top of the method, after `th = drishtiTheme();`:

```matlab
            g = uigridlayout(app.LeftPanel, [5 1]);
            g.RowHeight = {28, '1x', 20, 44, 24};
            g.Padding = [12 8 12 8];
            g.RowSpacing = th.spacing.s2;
            g.BackgroundColor = th.panel;
```

Then change each child's parent from `app.LeftPanel` to `g` and delete its
`'Position'` argument, in this order: `FilenameLabel` (row 1, spanning all
columns), `ImageAxes` (row 2), `MetaLabel` (row 3), `UploadButton` and
`AnalyzeButton` (row 4 — these need a nested `[1 2]` grid so they sit side by
side), `SampleDropdown` (row 5).

For the button row:

```matlab
            bg = uigridlayout(g, [1 2]);
            bg.ColumnWidth = {'1x', '1x'};
            bg.Padding = [0 0 0 0];
            bg.BackgroundColor = th.panel;
```

- [ ] **Step 2: `createResultSection` interior**

```matlab
            g = uigridlayout(app.MiddlePanel, [7 1]);
            g.RowHeight = {14, 30, 22, 84, 14, 26, '1x'};
            g.Padding = [16 16 16 16];
            g.RowSpacing = th.spacing.s2;
            g.BackgroundColor = th.panel;
```

Rows map to the existing children in order: the three `secLabel` section
captions and their values, `ReferralPanel` (row 4, fixed 84), `ConfidenceBar`
+ `ConfChip` (row 5, via a nested `[1 2]` grid so the chip sits right), the
`P(REFERABLE)` caption (row 6), `ScoreValue`, `ModelInfoLabel`, and
`AdviceBox` (row 7, `'1x'`).

The existing local `secLabel` helper keeps working — change only its parent
from `app.MiddlePanel` to `g`.

- [ ] **Step 3: `createEvidenceSection` interior**

```matlab
            g = uigridlayout(app.RightPanel, [3 4]);
            g.RowHeight = {30, 22, '1x'};
            g.ColumnWidth = {'1x', 14, 14, 14};
            g.Padding = [16 12 16 12];
            g.RowSpacing = th.spacing.s2;
            g.BackgroundColor = th.panel;
```

`ViewButtons` occupy row 1 across all four columns (nested `[1 4]` grid),
`VizTitle` row 2 spanning, `GradCAMAxes` row 3 columns 1-3, and `ColorbarAxes`
row 3 column 4. `DisclaimerLabel` moves into a nested row-4 strip, so make the
outer grid `[4 4]` with `RowHeight = {30, 22, '1x', 16}`.

- [ ] **Step 4: `createBottomBar` interior**

```matlab
            g = uigridlayout(app.BottomBar, [1 3]);
            g.ColumnWidth = {'1x', '1x', 320};
            g.Padding = [16 8 16 8];
            g.BackgroundColor = th.panel;
```

Column 1 holds the quality section, column 2 the pipeline section, column 3 the
report button. Each becomes a nested grid. Keep the existing local helper
`panLabel` working by passing `g` instead of `app.BottomBar`.

**Column 1 is built here, not added later.** Task 11 originally created a
*second* grid directly on `app.BottomBar` to hold the quality strip, which would
have competed with this one for the same region. The strip is therefore built
here as part of the conversion, and Task 11 is left with only the dynamic
behaviour to wire up. The corrected strip (the plan's original `[1 3]` grid took
five children in three columns, and its `BorderType','none'` dividers rendered
nothing at all):

```matlab
            % ---- quality strip: one well, four cells, hairline dividers ----
            % 7 columns, 7 children: three cells, three 1px rules, OVERALL.
            qg = uigridlayout(g, [1 7]);
            qg.ColumnWidth = {'1x', 1, '1x', 1, '1.5x', 1, '1.2x'};
            qg.Padding = [10 6 10 6];
            qg.BackgroundColor = th.surface;

            [app.FocusValue, app.FocusCheck] = qualityCell(qg, 'FOCUS');
            divider(qg);
            [app.IllumValue, app.IllumCheck] = qualityCell(qg, 'ILLUMINATION');
            divider(qg);
            [app.FovValue,   app.FovCheck]   = qualityCell(qg, 'FIELD OF VIEW');
            divider(qg);

            % OVERALL keeps its own property handle: displayQualityRows writes
            % app.OverallChip.BackgroundColor and .BorderColor, and it becomes
            % the only saturated fill in the bar.
            app.OverallChip = uipanel(qg, ...
                'BackgroundColor', th.panelAlt, ...
                'BorderType', 'line', 'BorderColor', th.borderLight, 'BorderWidth', 1);
            og = uigridlayout(app.OverallChip, [2 1]);
            og.RowHeight = {12, '1x'};
            og.Padding = [8 4 8 4];
            og.BackgroundColor = th.panelAlt;
            uilabel(og, 'Text', 'OVERALL', ...
                'FontSize', th.type.caption, 'FontWeight', 'bold', ...
                'FontColor', th.textMuted, 'BackgroundColor', th.panelAlt);
            app.OverallValue = uilabel(og, 'Text', '—', ...
                'FontSize', th.type.metric, 'FontWeight', 'bold', ...
                'FontColor', th.textMuted, 'BackgroundColor', th.panelAlt, ...
                'HorizontalAlignment', 'left', 'VerticalAlignment', 'bottom');
```

with the two local helpers:

```matlab
            function [valueLbl, checkLbl] = qualityCell(parent, titleTxt)
                cg = uigridlayout(parent, [2 2]);
                cg.ColumnWidth = {'1x', 18};
                cg.RowHeight = {12, 22};
                cg.Padding = [0 0 0 0];
                cg.BackgroundColor = th.surface;
                % Placed explicitly: three children in a [2 2] grid auto-place
                % title/(1,1), value/(1,2), check/(2,1), not the intended shape.
                titleLbl = uilabel(cg, 'Text', titleTxt, ...
                    'FontSize', th.type.caption, 'FontWeight', 'bold', ...
                    'FontColor', th.textFaint);
                titleLbl.Layout.Row = 1;
                titleLbl.Layout.Column = [1 2];
                valueLbl = uilabel(cg, 'Text', '—', ...
                    'FontSize', th.type.body, 'FontWeight', 'bold', ...
                    'FontColor', th.text, 'VerticalAlignment', 'bottom');
                valueLbl.Layout.Row = 2;
                valueLbl.Layout.Column = 1;
                checkLbl = uilabel(cg, 'Text', '—', ...
                    'FontSize', th.type.body, 'FontWeight', 'bold', ...
                    'FontColor', th.textFaint, ...
                    'HorizontalAlignment', 'center');
                checkLbl.Layout.Row = 2;
                checkLbl.Layout.Column = 2;
            end

            function divider(parent)
                % A 1px rule. BorderType 'none' suppresses the BORDER, not the
                % fill, so a panel with an explicit BackgroundColor is the
                % reliable divider; the plan's original version inherited the
                % parent background and rendered nothing at all.
                uipanel(parent, 'BorderType', 'none', ...
                    'BackgroundColor', th.hairline);
            end
```

`metricCard` is now unused — delete it in this step rather than in Task 11.
`app.FocusCard`, `app.IllumCard` and `app.FovCard` are likewise no longer
created; Task 11 drops the assignments that write to them.

- [ ] **Step 5: Run the layout gate — expect GREEN**

Run: `matlab -batch "run('src/dashboard/verify_app_layout.m')"`
Expected: `OK  7. no component constructor sets an absolute Position` and
`ALL DRISHTI APP LAYOUT CHECKS PASS`

- [ ] **Step 6: Run the app gate**

Run: `matlab -batch "run('src/dashboard/verify_retinaai.m')"`
Expected: `ALL RETINAAI CHECKS PASS`

- [ ] **Step 7: Commit**

```powershell
git add RetinaAIApp.m
git commit -m "refactor(app): convert the four panel interiors to grid layouts

Completes the grid conversion and turns the absolute-position guard green.
Each panel now owns a grid whose rows encode the visual hierarchy: fixed rows
for metadata and actions, 1x for the image, the canvas and the advice block."
```

---

## Increment 3 — Content, dashboard, docs

### Task 11: Drop the dead quality-card properties

**Files:**
- Modify: `RetinaAIApp.m` — the property declarations for `FocusCard`,
  `IllumCard` and `FovCard` only.

The quality strip itself was **built in Task 10 Step 4**, not here. The plan
originally had this task create a second grid directly on `app.BottomBar`, which
would have competed with the bottom-bar interior grid for the same region. What
remains after Task 10 is a small, honest cleanup.

- [ ] **Step 1: Delete the dead property declarations**

Remove the `FocusCard`, `IllumCard` and `FovCard` property declarations. They
were assigned once in `createBottomBar` and never written again —
`displayQualityRows` (lines 990-1059) only ever sets `.Text` on
`FocusValue`/`FocusCheck`/`IllumValue`/`IllumCheck`/`FovValue`/`FovCheck`, plus
`OverallValue.FontColor` and `OverallChip.BackgroundColor`/`.BorderColor`. All
four of those properties still exist after Task 10.

- [ ] **Step 2: Confirm nothing else references them**

Run: `matlab -batch "checkcode('RetinaAIApp.m')"` and grep the class for
`FocusCard`, `IllumCard`, `FovCard`. Expect no remaining references. A leftover
reference surfaces as an undefined-property error in the app gate, not as a
checkcode note, so the app gate in Step 3 is the real test.

- [ ] **Step 3: Run the gates**

Run: `matlab -batch "run('src/dashboard/verify_app_layout.m')"`
Run: `matlab -batch "run('src/dashboard/verify_retinaai.m')"`
Expected: both PASS

- [ ] **Step 4: Commit**

```powershell
git add RetinaAIApp.m
git commit -m "refactor(app): drop the dead quality-card properties

FocusCard, IllumCard and FovCard were assigned once in createBottomBar and never
written again - displayQualityRows only ever set .Text on the value and check
labels. Removing the four separately-bordered cards for the hairline strip is
the visual change; this is the leftover bookkeeping.

app.OverallChip stays: displayQualityRows writes its BackgroundColor and
BorderColor at lines 1046-1047, and it is now the only saturated fill in the
bar - colour marks the one number that changes a decision rather than three
that merely inform."
```

---

### Task 12: Pipeline progress track

**Files:**
- Modify: `RetinaAIApp.m` — the chip construction in `createBottomBar`
  (lines 542-571) and `setPipelineState` + its nested `getStyles`
  (lines 1183-1246). Also drop the now-dead `PipelineChips` property.

The track is built into **column 2 of the bottom-bar interior grid created in
Task 10 Step 4**, not as a second grid on `app.BottomBar`, for the same reason
the quality strip moved.

- [ ] **Step 1: Replace five chips with one track**

```matlab
            % ---- pipeline progress: one track, five dots ----
            % Column 2 of the bottom-bar interior grid from Task 10 Step 4.
            stepNames = {'Image', 'Quality', 'Screening', 'Evidence', 'Report'};
            pg = uigridlayout(g, [2 1]);      % g is the bottom-bar interior grid
            pg.RowHeight = {14, '1x'};
            pg.Padding = [0 0 0 0];
            pg.BackgroundColor = th.panel;
            uilabel(pg, 'Text', 'PIPELINE STATUS', ...
                'FontSize', th.type.caption, 'FontWeight', 'bold', ...
                'FontColor', th.textFaint);

            % Dots and rules share one 9-column grid: 5 dots on the odd columns,
            % 4 rules on the even ones. (The plan's original declared 5 widths
            % for 9 columns and crammed 14 children into a single row.)
            dg = uigridlayout(pg, [1 9]);
            dg.ColumnWidth = {'1x', 10, '1x', 10, '1x', 10, '1x', 10, '1x'};
            dg.Padding = [0 0 0 0];
            dg.BackgroundColor = th.panel;

            % Names get their own 5-column grid so they align to the dots.
            ng = uigridlayout(pg, [1 5]);
            ng.ColumnWidth = repmat({'1x'}, 1, 5);
            ng.Padding = [0 0 0 0];
            ng.BackgroundColor = th.panel;

            app.PipelineDots  = gobjects(1, 5);
            app.PipelineNames = gobjects(1, 5);
            app.PipelineRules = gobjects(1, 4);
            for k = 1:5
                app.PipelineDots(k) = uilabel(dg, ...
                    'Text', char(9675), ...
                    'FontSize', 11, 'FontColor', th.textFaint, ...
                    'HorizontalAlignment', 'center');
                app.PipelineDots(k).Layout.Column = 2*k - 1;
                app.PipelineNames(k) = uilabel(ng, ...
                    'Text', stepNames{k}, ...
                    'FontSize', th.type.caption, ...
                    'FontColor', th.textMuted, ...
                    'HorizontalAlignment', 'center');
                if k < 5
                    app.PipelineRules(k) = uipanel(dg, ...
                        'BackgroundColor', th.hairline, 'BorderType', 'none');
                    app.PipelineRules(k).Layout.Column = 2*k;
                end
            end
```

The rules are `uipanel`s, not `uilabel`s: `uilabel` has no `BorderType`
property (the plan's original passed one, which errors), and a borderless panel
with an explicit `BackgroundColor` reliably paints its fill.

- [ ] **Step 2: Collapse `getStyles` from five fields to three**

Keep the existing nested-function shape and assign fields directly. The plan's
original routed the assignments through
`done = @(varargin) setk(styles, varargin{:})`, which cannot possibly work: a
MATLAB anonymous function cannot mutate a variable it captured.

```matlab
            function styles = getStyles()
                % 1x5 struct: dot, dotColor, labelColor
                styles = repmat(struct('dot', '', 'dotColor', [], ...
                    'labelColor', []), 1, 5);
                for k = 1:5
                    styles(k).dot = char(9675);
                    styles(k).dotColor = th.textFaint;
                    styles(k).labelColor = th.textMuted;
                end
                switch state
                    case 'loading'
                        styles(1).dot = char(10003);
                        styles(1).dotColor = th.success;
                        styles(1).labelColor = th.text;
                    case 'analyzing'
                        styles(1).dot = char(10003);
                        styles(1).dotColor = th.success;
                        styles(1).labelColor = th.text;
                        styles(2).dot = char(9679);
                        styles(2).dotColor = th.warning;
                        styles(2).labelColor = th.text;
                    case 'complete'
                        for k = 1:5
                            styles(k).dot = char(10003);
                            styles(k).dotColor = th.success;
                            styles(k).labelColor = th.text;
                        end
                    case 'blocked'
                        styles(1).dot = char(10003);
                        styles(1).dotColor = th.success;
                        styles(1).labelColor = th.text;
                        for k = 2:5
                            styles(k).dot = char(10007);
                            styles(k).dotColor = th.danger;
                            styles(k).labelColor = th.text;
                        end
                end
            end
```

- [ ] **Step 3: Update `setPipelineState` to drive dots, labels and rules**

Drop the per-chip `BackgroundColor`/`BorderColor` writes, rename `nameColor` to
`labelColor` at the read site, and light the rules:

```matlab
        function setPipelineState(app, state)
            th = drishtiTheme();
            % one style per stage for a given overall state
            styles = getStyles();   % 1x5 struct: dot, dotColor, labelColor
            for k = 1:5
                s = styles(k);
                app.PipelineDots(k).FontColor = s.dotColor;
                app.PipelineDots(k).Text = s.dot;
                app.PipelineNames(k).FontColor = s.labelColor;
            end

            % A rule between step k and k+1 is lit once step k+1 is reached.
            reached = struct('idle', 0, 'loading', 1, 'analyzing', 2, ...
                             'complete', 5, 'blocked', 1);
            nReached = reached.(state);
            for k = 1:4
                if k < nReached
                    app.PipelineRules(k).BackgroundColor = th.textFaint;
                else
                    app.PipelineRules(k).BackgroundColor = th.hairline;
                end
            end

            function styles = getStyles()
                ... as in Step 2 ...
            end
        end
```

Delete the `PipelineChips` property declaration — `setPipelineState` was its
only writer.

- [ ] **Step 4: Run the gates**

Run: `matlab -batch "run('src/dashboard/verify_app_layout.m')"`
Run: `matlab -batch "run('src/dashboard/verify_retinaai.m')"`
Expected: PASS both. `setStatus`/`setPipelineState` behaviour is unchanged: the
app gate drives every state, so the dot glyphs and label colours must match the
old chips' semantics exactly.

- [ ] **Step 5: Commit**

```powershell
git add RetinaAIApp.m
git commit -m "refactor(app): replace five pipeline chips with one progress track

Five bordered chips with two-line wrapped labels became a hairline track with
five dots. getStyles drops from five per-step fields to three across the same
five states, which is where most of the complexity was."
```

---

### Task 13: Advice block alignment

**Files:**
- Modify: `RetinaAIApp.m:373-381`

- [ ] **Step 1: Left-align the advice block**

```matlab
            app.AdviceBox = uilabel(app.MiddlePanel, ...
                'Text', 'Run an analysis to see the screening advice', ...
                'FontSize', th.type.metric, 'FontWeight', 'bold', ...
                'FontColor', th.textFaint, ...
                'BackgroundColor', th.panelDeep, ...
                'HorizontalAlignment', 'left', ...
                'VerticalAlignment', 'center', ...
                'WordWrap', 'on');
```

- [ ] **Step 2: Run the gates and commit**

Run: `matlab -batch "run('src/dashboard/verify_retinaai.m')"`
Expected: PASS

```powershell
git add RetinaAIApp.m
git commit -m "refactor(app): left-align the advice block

valueLarge bold centred in a 148px empty well read as an unfilled placeholder
rather than a recommendation."
```

---

### Task 14: Theme the dashboard; drop its 13 absolute Positions

**Files:**
- Modify: `src/dashboard/DRScreeningDashboard.m:52-62` (figure + tab group), plus lines 78, 81, 96, 114, 121, 128, 138, 152, 162, 171, 197, 201, 254

**Interfaces:**
- Consumes: `drishtiTokens()`

- [ ] **Step 1: Theme the figure and tab group**

```matlab
        function createComponents(app)
            th = drishtiTheme();
            app.UIFigure = uifigure('Name', 'DrishtiCare Screening Dashboard', ...
                'Position', [90 80 1280 760], 'Color', th.background);

            tg = uitabgroup(app.UIFigure, 'Position', [10 10 1260 740]);
            tg.BackgroundColor = th.background;
```

- [ ] **Step 2: Replace the hardcoded pie colormap**

Line 84:

```matlab
            colormap(ax, [0.35 0.7 0.35; 0.95 0.8 0.35; 0.85 0.32 0.32]);
```

becomes:

```matlab
            th = drishtiTheme();
            colormap(ax, [th.success; th.warning; th.danger]);
            ax.Color = th.surface;
```

- [ ] **Step 3: Give every panel an explicit surface and hairline**

Add to each `uipanel(grid, ...)` construction:

```matlab
                'BackgroundColor', th.surface, 'ForegroundColor', th.textMuted, ...
                'BorderType', 'line', 'BorderColor', th.hairline, ...
```

- [ ] **Step 4: Remove the 13 absolute `Position` overrides**

Each of these children sits inside a `uigridlayout` that already allocates
space, so the override only fights it. Delete the `'Position', [...]` argument
at lines 78, 96, 114, 121, 128, 138, 197, 201, 254, and for the four `uiaxes`
(81, 152, 162, 171) set `'Layout', {'Column', n}` or nest them in a
`uigridlayout` so they fill their cell.

- [ ] **Step 5: Set `ax.Color` on every dashboard axes**

```matlab
            ax.Color = th.surface;
            ax.XColor = th.textMuted;
            ax.YColor = th.textMuted;
```

- [ ] **Step 6: Run the dashboard gate**

Run: `matlab -batch "run('src/dashboard/verify_dashboard.m')"`
Expected: `ALL T12 DASHBOARD CHECKS PASS`

- [ ] **Step 7: Commit**

```powershell
git add src/dashboard/DRScreeningDashboard.m
git commit -m "feat(dashboard): theme the ops dashboard from the shared tokens

The dashboard was entirely unthemed: MATLAB defaults, a hardcoded pie colormap
[0.35 0.7 0.35; 0.95 0.8 0.35; 0.85 0.32 0.32], and 13 absolute Position
overrides fighting the uigridlayout that already allocated the space - one of
them a 1220px label inside a narrower panel."
```

---

### Task 15: Dashboard Overview and Performance de-Consolas

**Files:**
- Modify: `src/dashboard/DRScreeningDashboard.m:65-142`

- [ ] **Step 1: Replace the Overview Consolas blobs with KPI tiles**

```matlab
            tiles = uigridlayout(grid, [1 4]);
            tiles.ColumnWidth = repmat({'1x'}, 1, 4);
            tiles.Padding = [0 0 0 0];
            tiles.BackgroundColor = th.surface;
            statTile(tiles, 'REFERABLE (TRAIN)', sprintf('%.1f%%', D.referable.trainFrac*100), th);
            statTile(tiles, 'REFERABLE (VAL)',   sprintf('%.1f%%', D.referable.valFrac*100),   th);
            statTile(tiles, 'BINARY THRESHOLD', '0.60 (LOCKED)',                              th);
            statTile(tiles, 'IMAGES SCREENED',  sprintf('%d', D.quality.n),                   th);
```

with a local helper:

```matlab
        function statTile(parent, labelTxt, valueTxt, th)
            p = uipanel(parent, 'BorderType', 'line', 'BorderColor', th.hairline, ...
                'BackgroundColor', th.surface);
            g = uigridlayout(p, [2 1]);
            g.RowHeight = {14, '1x'};
            g.Padding = [10 6 10 6];
            g.BackgroundColor = th.surface;
            uilabel(g, 'Text', labelTxt, 'FontSize', th.type.caption, ...
                'FontWeight', 'bold', 'FontColor', th.textFaint);
            uilabel(g, 'Text', valueTxt, 'FontSize', th.type.metric, ...
                'FontWeight', 'bold', 'FontColor', th.ink);
        end
```

- [ ] **Step 2: Restyle the two `uitable`s**

```matlab
            tt = uitable(p1, 'Data', D.ablation, 'ColumnName', ...
                {'Config', 'Acc', 'macroF1', 'QWK', 'Sens(ref)', 'Spec(ref)', 'n'}, ...
                'ColumnWidth', {285, 55, 55, 55, 65, 65, 40}, ...
                'FontSize', th.type.body, 'FontName', '', ...
                'BackgroundColor', th.surface, 'ForegroundColor', th.ink, ...
                'RowStripeColor', th.sunken, ...
                'ColumnNameBackgroundColor', th.sunken, ...
                'ColumnNameFontColor', th.inkMuted);
```

- [ ] **Step 3: Replace the champion-metrics Consolas block with a definition list**

```matlab
            dl = uigridlayout(p1, [6 2]);
            dl.ColumnWidth = {150, '1x'};
            dl.Padding = [0 0 0 0];
            dl.BackgroundColor = th.surface;
            rows = { ...
                'Accuracy',            sprintf('%.4f', c.accuracy), ...
                'Macro F1',            sprintf('%.4f', c.macroF1), ...
                'QWK',                 sprintf('%.4f', c.qwk), ...
                'Referable @ 0.60',    sprintf('sens %.4f / spec %.4f', c.binarySens, c.binarySpec), ...
                'PPV / NPV',           sprintf('%.4f / %.4f', c.binaryPpv, c.binaryNpv), ...
                'Confusion',           sprintf('TP %d  FP %d  FN %d  TN %d', ...
                                              c.binaryTp, c.binaryFp, c.binaryFn, c.binaryTn)};
            for i = 1:size(rows, 1)
                uilabel(dl, 'Text', rows{i,1}, 'FontSize', th.type.caption, ...
                    'FontColor', th.textFaint);
                uilabel(dl, 'Text', rows{i,2}, 'FontSize', th.type.body, ...
                    'FontColor', th.ink, 'FontWeight', 'bold');
            end
```

- [ ] **Step 4: Run the gate and commit**

Run: `matlab -batch "run('src/dashboard/verify_dashboard.m')"`
Expected: `ALL T12 DASHBOARD CHECKS PASS`

```powershell
git add src/dashboard/DRScreeningDashboard.m
git commit -m "refactor(dashboard): replace Overview/Performance monospace blobs with components

Three Consolas text blobs and a metrics block become KPI tiles, themed
tables, and a label/value definition list. Fixed-width text was being used to
fake column alignment that layout now provides properly."
```

---

### Task 16: Dashboard Workload ASCII table to a real table

**Files:**
- Modify: `src/dashboard/DRScreeningDashboard.m:182-230` (`WorkloadTab`, `updateWorkload`)

**Interfaces:**
- The top-aligned label with `'Manual-review load (est.):'` **must survive** —
  `verify_dashboard.m:45-53` locates it by `VerticalAlignment:'top'`.

- [ ] **Step 1: Keep the contract label, add a themed table**

In `updateWorkload`, keep the existing ASCII string in the label and also
populate a table:

```matlab
            app.WorkloadTbl.Data = { ...
                'Referable (P(ref) >= 0.60)', sprintf('%d', round(nRef)),  sprintf('%.1f%%', nRef/n*100); ...
                'Quality FAIL -> recapture',   sprintf('%d', round(nFail)), sprintf('%.1f%%', fL*100); ...
                'Quality WARNING (caution)',   sprintf('%d', round(nWarn)), sprintf('%.1f%%', wP*100); ...
                'Manual-review load (est.)',   sprintf('%d', round(sr)),   sprintf('%.1f%%', sr/n*100); ...
                'Auto-clearable (est.)',       sprintf('%d', max(0, round(n-sr))), ''};
            app.WorkloadVerdict.Text = sprintf( ...
                'At ~60 reviews/hour this clears in one 8h shift: est. %.2f reviewers.', ...
                sr / (60 * 8));
```

- [ ] **Step 2: Style both**

```matlab
            app.WorkloadTbl = uitable(pg, 'Data', cell(0, 3), ...
                'ColumnName', {'Component', 'Images', 'Share'}, ...
                'ColumnWidth', {300, 90, 80}, ...
                'FontSize', th.type.body, 'BackgroundColor', th.surface, ...
                'ForegroundColor', th.ink, 'RowStripeColor', th.sunken, ...
                'ColumnNameBackgroundColor', th.sunken, ...
                'ColumnNameFontColor', th.inkMuted);

            % Contract label for verify_dashboard.m:45-53 - keep top-aligned.
            app.WorkloadOut = uilabel(pg, 'Text', '', ...
                'FontName', 'Consolas', 'FontSize', th.type.caption, ...
                'VerticalAlignment', 'top', 'Visible', 'off');
```

- [ ] **Step 3: Run the gate — this is where edit 3 becomes necessary**

Run: `matlab -batch "run('src/dashboard/verify_dashboard.m')"`
Expected: FAIL at `outLbl = findobj(...)` or on the `Manual-review load` text
assertion, because the newly-added `WorkloadVerdict` label is also
top-aligned and `findobj` returns it first.

- [ ] **Step 4: Tag the contract label and fix the gate's lookup**

In `DRScreeningDashboard.m`, add `'Tag', 'workloadOut', ...` to `WorkloadOut`.

In `verify_dashboard.m`, replace lines 45-48:

```matlab
outLbl = findobj(a.UIFigure, 'Type', 'uilabel', '-and', ...
    'VerticalAlignment', 'top');
assert(numel(outLbl) >= 1, 'workload output label');
txt = outLbl(1).Text;
```

with:

```matlab
% Selected by tag, not by VerticalAlignment ordering: the original lookup
% assumed the first top-aligned label on the figure was the workload output,
% which only held because no other top-aligned label existed.
outLbl = findobj(a.UIFigure, 'Type', 'uilabel', 'Tag', 'workloadOut');
assert(numel(outLbl) == 1, 'exactly one tagged workload output label');
txt = outLbl(1).Text;
```

- [ ] **Step 5: Run the gate again**

Run: `matlab -batch "run('src/dashboard/verify_dashboard.m')"`
Expected: `OK  3. workload math @1000 img/day` and `ALL T12 DASHBOARD CHECKS PASS`

- [ ] **Step 6: Commit**

```powershell
git add src/dashboard/DRScreeningDashboard.m src/dashboard/verify_dashboard.m
git commit -m "refactor(dashboard): replace the Workload ASCII table with a real table

A Consolas 13pt block of ---- rules became a themed uitable plus a one-line
verdict. The top-aligned label carrying 'Manual-review load (est.):' is kept
because verify_dashboard.m asserts on it, and it is now tagged rather than
located by VerticalAlignment ordering - which was a latent bug, since the
verdict label would have been picked up first."
```

---

### Task 17: Inspector monospace restyle

**Files:**
- Modify: `src/dashboard/DRScreeningDashboard.m:250-254`

Monospace is **kept** here — it is a machine-output readout.

- [ ] **Step 1: Restyle from tokens**

```matlab
            app.InspectorOut = uitextarea(outPanel, ...
                'Value', {'Select a class + image, then press Run.'}, ...
                'FontName', 'Consolas', 'FontSize', th.type.body, 'Editable', 'off', ...
                'BackgroundColor', th.sunken, 'ForegroundColor', th.ink);
```

- [ ] **Step 2: Run the gate and commit**

Run: `matlab -batch "run('src/dashboard/verify_dashboard.m')"`
Expected: PASS

```powershell
git add src/dashboard/DRScreeningDashboard.m
git commit -m "style(dashboard): theme the Inspector readout

Monospace is retained deliberately: this is machine output, where it is
conventional rather than decorative."
```

---

### Task 18: Documentation

**Files:**
- Modify: `docs/project-management/EXECUTION_CHECKLIST.md:38`
- Modify: `docs/project-management/DECISION_LOG.md`
- Modify: `docs/ARCHITECTURE.md`, `README.md`

- [ ] **Step 1: Correct the now-false responsive claim**

`EXECUTION_CHECKLIST.md:38` currently reads *"Multi-size responsive layout is
not applicable, not merely untested"*, citing `RetinaAIApp.m:157`
`'Resize','off'`. Replace with:

```
- [x] Verify layout at the design size - [`src/dashboard/verify_app_layout.m` PASS:
  bands discovered by `findall` over the whole tree, one header, one bottom bar, >=3 ordered
  content panels, 0 clipped, 0 zero-extent. **Multi-size responsive layout is now verified** at
  1120x680, 1360x760 and 1920x1080: the band structure and canvas containment hold at all three,
  and the window is clamped at a 1120x680 floor. The app is built on nested `uigridlayout` with
  `Resize` on; an added guard fails the gate if any component reintroduces an absolute `Position`
  inside a grid.]
```

- [ ] **Step 2: Add the decision-log entry**

Append to `docs/project-management/DECISION_LOG.md`:

```markdown
## 2026-10-04 - Minimal clinical UI redesign

**Decision.** Replace the deep-navy theme with a light clinical system; make
`RetinaAIApp` responsive; simplify its content; theme `DRScreeningDashboard`.

**Rationale.** Four surface levels, two border weights, ten type sizes and
monospace text blocks read as heavy rather than minimal. The fixed canvas also
meant `EXECUTION_CHECKLIST.md` had to record multi-size layout as "not
applicable".

**How tokens are owned.** `src/ui/drishtiTokens.m` is the source of truth;
`drishtiTheme()` is a facade keeping all 15 legacy field names, so the PDF
report needed no call-site changes.

**Measured, not estimated.** All colour pairs clear WCAG AA (text >= 4.5:1,
non-text >= 3:1) worst-case on `sunken`, enforced by
`src/verify/verify_ui_tokens.m`. The first draft's `inkFaint` measured 2.79:1
and was rejected.

**Grad-CAM map.** `turbo` -> `parula`. `turbo` is a rainbow map and not
colourblind-safe; `parula` measures inside `verify_gradcam_rendering`'s budgets
(endpoint 3.13% of 10%, alpha conditioning 86.5% of 20%). `hot` (203%) and
`copper` (28%) fail. `inferno` is **absent from this R2026a install** despite
the theme previously claiming it was available, and `drishtiColormap` had
advertised it while its branch would hard-error.

**Gate changes, none weakening an assertion.** `verify_app_layout` rewritten to
discover bands with `findall` (the old `fig.Children` read returns only the
root container once bands are nested, and `uigridlayout` is deliberately not a
`Panel`). `run_drishti_visual_qa` now selects the fundus axes by tag instead of
`Position(1) < 50`. `verify_dashboard` selects its workload label by tag instead
of `VerticalAlignment` ordering, which was a latent bug.

**Untouched.** Threshold 0.60, T=2.5382, champion weights and hashes, splits,
frozen metrics, `predictSingleFundus`, the demo contract suite.
```

- [ ] **Step 3: Update architecture and README**

In `docs/ARCHITECTURE.md`, change the `src/ui/` entry to name
`drishtiTokens` (source of truth), `drishtiTheme` (façade), `drishtiColormap`
and the two Grad-CAM renderers, and note the dashboard is token-themed. In
`README.md`, add `src/verify/verify_ui_tokens.m` to the Verification block:

```
verify_ui_tokens
```

- [ ] **Step 4: Verify the link checker still passes**

Run: `powershell -ExecutionPolicy Bypass -File docs\verify\check_markdown_links.ps1`
Expected: no broken links

- [ ] **Step 5: Commit**

```powershell
git add docs/
git commit -m "docs: record the minimal clinical UI redesign and correct the responsive claim

EXECUTION_CHECKLIST.md stated multi-size responsive layout was 'not applicable,
not merely untested', citing the fixed canvas. That is no longer true."
```

---

### Task 19: Full gate sweep and visual QA

**Files:**
- Modify: `results/visual_qa/*` (regenerated evidence)

- [ ] **Step 1: Run every gate in sequence**

```powershell
matlab -batch "run('src/verify/verify_ui_tokens.m')"
matlab -batch "run('src/verify/verify_gradcam_rendering.m')"
matlab -batch "run('src/dashboard/verify_app_layout.m')"
matlab -batch "run('src/dashboard/verify_retinaai.m')"
matlab -batch "run('src/dashboard/verify_dashboard.m')"
matlab -batch "run('src/reporting/verify_drishti_report_extended.m')"
matlab -batch "run('src/demo/tests/test_failure_aware_demo.m')"
```

Expected terminators: `ALL UI TOKEN CHECKS PASS`,
`ALL GRADCAM RENDERING AUDIT CHECKS PASS`,
`ALL DRISHTI APP LAYOUT CHECKS PASS`, `ALL RETINAAI CHECKS PASS`,
`ALL T12 DASHBOARD CHECKS PASS`,
`ALL DRISHTI REPORT EXTENDED CHECKS PASS`, and the demo suite's own terminator.

- [ ] **Step 2: Regenerate the visual QA evidence**

Run: `matlab -batch "run('src/dashboard/run_drishti_visual_qa.m')"`
Expected: screenshots written to `results/visual_qa/` for the idle dashboard,
each of PASS/WARNING/FAIL, all four explainability views, and the report preview.

- [ ] **Step 3: Commit the evidence**

```powershell
git add results/visual_qa/
git commit -m "chore(evidence): regenerate visual QA screenshots under the light theme"
```

- [ ] **Step 4: Human visual pass — REQUIRED, cannot be automated**

Report `results/visual_qa/` to the user and state plainly that the implementer
cannot view images. The user must confirm the result reads as minimal and
professional. Do not describe the UI as looking good on the implementer's own
authority.

- [ ] **Step 5: Push**

```powershell
git push origin main
```

---

## Self-Review

**Spec coverage.** Section 1 (tokens) → Tasks 1-4. Section 2 (responsive
layout) → Tasks 5-10. Section 3 (content simplification, dashboard, report) →
Tasks 4, 11-17. Section 4 (gates, phases, docs) → Tasks 6, 8, 9, 18, 19. Every
spec section maps to at least one task.

**Deliberate red commits.** Tasks 6 and 9 land a gate that fails on purpose,
each labelled `EXPECTED RED` in the commit message, and each turned green by the
following task. This is the only way to prove a new gate detects the condition
it exists to catch. No other commit lands red.

**Placeholder scan.** No TBD, no "similar to Task N", no unspecified error
handling. Every new file has complete code. Every mechanical edit names its
line numbers and shows the replacement.

**Type consistency.** `drishtiTokens()` field names used in Tasks 1, 2, 14-17
all match the Task 1 definition. `drishtiTheme()` legacy names used in Task 4
match the Task 2 facade. Tag names `fundusAxes` (Task 5) and `workloadOut`
(Task 16) are each defined where first used and each consumed by the matching
gate edit.

**Pre-flight scan amendments.** A conflict scan run before Task 1 amended this
plan in nine places; the rulings are recorded in the SDD ledger at
`.superpowers/sdd/2026-10-04-minimal-clinical-ui/progress.md`. The substantive
ones:

- Task 2 gained the token-name aliases (`surface`, `sunken`, `hairline`, `ink`,
  `spacing`). Six downstream tasks read the palette by token name and the
  facade only exposed legacy names.
- Task 6 replaced only the band section, not the traversal section it had pasted
  in, and band discovery now counts only panels one or two grid levels below the
  figure — Tasks 10-12 add nested panels that a blanket `findall` sweep would
  misclassify as content bands.
- Task 9's guard became a **source-level** check. As a runtime probe it could
  never pass: every `uigridlayout` child carries a derived four-element
  `Position`, so "child of a grid with a 4-element Position" is true of every
  component in the app.
- Task 10 now builds the quality strip, and Task 12 builds the pipeline track,
  into columns of the bottom-bar interior grid. As written they each added a
  second grid to `app.BottomBar`, competing with that interior grid.
- Task 11's strip grid declared 3 columns for 5 children, its dividers inherited
  the parent background and so rendered nothing, its cell title auto-placed into
  the wrong cell, and it dropped `app.OverallChip` while `displayQualityRows`
  still writes it.
- Task 12's track declared 5 widths for 9 columns and 14 children in one row,
  passed `BorderType` to a `uilabel` (which has no such property), and rewrote
  `getStyles` through an anonymous function that cannot mutate its capture.
- Task 12's `getStyles` now assigns fields directly, keeping the existing nested
  function's shape.

With those amendments every task's code is runnable as written, and the
red-then-green shape of Tasks 6/9 is preserved.