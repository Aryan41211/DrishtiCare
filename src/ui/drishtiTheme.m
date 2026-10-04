function th = drishtiTheme()
%DRISHTITHEME Presentation theme for the DrishtiCare DRISHTI screening UI.
%   th = drishtiTheme()
%
%   drishtiTokens() is the single source of truth for every colour, type size
%   and spacing step. This function maps those tokens onto the field names the
%   RetinaAIApp dashboard and the generateDrishtiReport PDF already read, and
%   owns the Grad-CAM rendering parameters, so dashboard and report render with
%   the IDENTICAL visual rules (colours, Grad-CAM colormap/alpha, terminology).
%   The palette VALUES live in drishtiTokens.m; the only colour derived here is
%   primaryDark, a hover/pressed tone. The legacy field names are a frozen
%   interface: callers depend on them, so fields may be added but never
%   renamed or removed.
%
%   The theme only owns PRESENTATION. It never changes model outputs, quality
%   thresholds, referral decisions or any engineering value.
%
%   Palette intent (light clinical):
%     canvas/surface/sunken  three surface levels plus ONE hairline border
%     ink/inkMuted           the two text colours
%     inkFaint               RESERVED for non-text (rules, ticks): it measures
%                            3.68:1, below the 4.5:1 text floor, so text must
%                            use th.textMuted or th.text, never this.
%     primary                the single accent; primaryDark is its hover tone
%     success                green (PASS / non-referable)
%     warning                dark amber ink on an amber fill (WARNING / review);
%                            amber is never used as text on a light surface
%     danger                 red  (FAIL / referable / blocked)
%     info                   alias of textMuted; there is no separate info colour
%
%   ENGINEERING prototype styling. NOT a clinical device.

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

    %% ---- Grad-CAM rendering config (single source of truth) ----
    g = struct();
    % Colormaps verified present in this R2026a install: turbo, parula, hot,
    % gray, bone, copper, jet, hsv, colorcube. inferno/magma/plasma/viridis/
    % cividis are ABSENT and referencing them hard-errors. parula is chosen
    % over turbo because it is perceptually uniform and colour-vision-
    % deficiency-friendly, and it clears verify_gradcam_rendering's endpoint
    % budget (3.12% of 10%) and alpha-conditioning floor (86.5% of 20%).
    g.colormap   = 'parula';
    g.alphaLo    = 0.32;           % opacity where activation is low
    g.alphaHi    = 0.50;           % opacity where activation is high
    g.limits     = [0 1];          % mat2gray range used everywhere
    g.interp     = 'bicubic';      % heatmap upscaling to display resolution
    g.colorbarLabel = 'Model attention';
    g.disclaimer = 'Model attention visualization - not validated lesion localization.';
    th.gradcam = g;

    %% ---- presentation terms (wording mirrors existing pipeline) ----
    t = struct();
    t.referable    = 'REFERABLE';
    t.nonreferable = 'NOT REFERABLE';
    t.review       = 'REVIEW';
    t.blocked      = 'BLOCKED';
    t.qualityPass  = 'ACCEPT';
    t.qualityWarn  = 'BORDERLINE';
    t.qualityFail  = 'REJECT';
    th.terms = t;

end

% -------------------------------------------------------------------------
function rgb = hexdark(c)
%HEXDARK Darken an accent for hover/pressed states, for the light theme.
    rgb = c * 0.75;
end