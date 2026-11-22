function th = drishtiThemeDark()
%DRISHTITHEMEDARK Dark presentation theme for the DrishtiCare DRISHTI + Lesion desktop UI.
%   th = drishtiThemeDark()
%
%   Mirrors drishtiTheme() field-for-field (the frozen legacy interface the
%   dashboard/report callers read) but maps every colour onto the dark desktop
%   palette from drishtiTokensDark(). The light PDF report keeps reading
%   drishtiTheme() / drishtiTokens() and is unaffected.
%
%   The theme only owns PRESENTATION. It never changes model outputs, quality
%   thresholds, referral decisions or any engineering value.
%
%   Palette intent (dark desktop):
%     canvas/surface/sunken  three surface levels plus ONE hairline border
%     ink/inkMuted           the two text colours
%     header                 navy-blue application header
%     primary                the single accent (primary button); primaryDark its hover tone
%     success                green  (PASS / non-referable)
%     warning                amber ink on an amber fill (WARNING / review)
%     danger                 red   (FAIL / referable / blocked)
%     heading                section heading colour
%
%   ENGINEERING prototype styling. NOT a clinical device.

    th = struct();
    tk = drishtiTokensDark();

    %% ---- surfaces (dark desktop; three levels + one border) ----
    th.background   = tk.canvas;
    th.header       = tk.header;
    th.panel        = tk.surface;
    th.panelAlt     = tk.sunken;
    th.panelDeep    = tk.sunken;
    th.border       = tk.hairline;
    th.borderLight  = tk.hairline;

    %% ---- semantic accent colours ----
    th.primary      = tk.primary;
    th.primaryDark  = th.primary * 0.70;   % hover/pressed tone
    th.primaryBg    = tk.sunken;
    th.success      = tk.success;
    th.warning      = tk.warningInk;
    th.danger       = tk.danger;
    th.info         = tk.inkMuted;
    th.heading      = tk.heading;
    th.secondary    = tk.secondary;

    th.successBg    = tk.successBg;
    th.warningBg    = tk.warningFill;
    th.dangerBg     = tk.dangerBg;

    %% ---- text colours ----
    th.text         = tk.ink;
    th.textMuted    = tk.inkMuted;
    th.textFaint    = tk.inkFaint;

    %% ---- token-name aliases ----
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
        'appTitle',     20, ...
        'sectionTitle', tk.type.label, ...
        'panelTitle',   tk.type.label, ...
        'label',        tk.type.body, ...
        'labelSmall',   tk.type.label, ...
        'value',        tk.type.body, ...
        'valueLarge',   tk.type.metric, ...
        'valueHero',    tk.type.metric, ...
        'support',      tk.type.caption, ...
        'tiny',         tk.type.caption);

    %% ---- Grad-CAM rendering config (shared with light theme where sensible) ----
    g = struct();
    g.colormap   = 'parula';
    g.alphaLo    = 0.32;
    g.alphaHi    = 0.50;
    g.limits     = [0 1];
    g.interp     = 'bicubic';
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
%HEXDARK Darken an accent for hover/pressed states, for the dark theme.
    rgb = c * 0.70;
end
