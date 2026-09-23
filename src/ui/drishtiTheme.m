function th = drishtiTheme()
%DRISHTITHEME Centralized visual theme for the DrishtiCare DRISHTI screening UI.
%   th = drishtiTheme()
%
%   Single source of truth for every colour, status colour, typography size
%   and Grad-CAM rendering parameter used by the RetinaAIApp dashboard and the
%   generateDrishtiReport PDF. Dashboard and report therefore render with the
%   IDENTICAL visual rules (colours, Grad-CAM colormap/alpha, terminology).
%
%   The theme only owns PRESENTATION. It never changes model outputs, quality
%   thresholds, referral decisions or any engineering value.
%
%   Palette intent:
%     background  deep navy / charcoal
%     panels      slightly lighter charcoal-navy
%     primary     professional blue (one strong accent)
%     success     green (PASS / non-referable)
%     warning     amber (WARNING / review)
%     danger      red  (FAIL / referable / blocked)
%     info        cyan-blue reserved for technical readouts
%
%   ENGINEERING prototype styling. NOT a clinical device.

    th = struct();

    %% ---- surfaces (deep navy / charcoal, light-neutral text) ----
    th.background   = [0.043 0.051 0.086];   % window  (#0B0D16)
    th.panel        = [0.078 0.094 0.145];   % panels  (#141825)
    th.panelAlt     = [0.106 0.127 0.192];   % cards   (#1B2131)
    th.panelDeep    = [0.055 0.067 0.110];   % wells   (#0E111C)
    th.border       = [0.170 0.200 0.290];   % (#2B334A)
    th.borderLight  = [0.270 0.310 0.420];   % (#454F6B)

    %% ---- semantic accent colours ----
    th.primary      = [0.160 0.420 0.950];   % professional blue  (#296AF2)
    th.primaryDark  = [0.080 0.250 0.690];   % (#1440B0)
    th.primaryBg    = [0.100 0.180 0.320];   % selected-chip fill (#1A2E52)
    th.success      = [0.235 0.710 0.415];   % green  (#3CB56A)
    th.warning      = [0.960 0.620 0.160];   % amber  (#F59E29)
    th.danger       = [0.920 0.310 0.300];   % red    (#EB4F4D)
    th.info         = [0.240 0.650 0.920];   % cyan-blue (#3DA6EB)

    th.successBg    = [0.085 0.205 0.140];   % card fills for status tones
    th.warningBg    = [0.270 0.205 0.075];
    th.dangerBg     = [0.300 0.095 0.095];

    %% ---- text colours ----
    th.text         = [0.930 0.950 0.970];   % (#EDF1F7)
    th.textMuted    = [0.650 0.705 0.790];   % (#A6B4C9)
    th.textFaint    = [0.475 0.535 0.645];   % (#7988A5)

    %% ---- status colour maps (PASS / WARNING / FAIL) ----
    th.status = struct('PASS', th.success, 'WARNING', th.warning, 'FAIL', th.danger);
    th.statusBg = struct('PASS', th.successBg, 'WARNING', th.warningBg, 'FAIL', th.dangerBg);

    %% ---- typographic scale (presentation-consistent hierarchy) ----
    ty = struct();
    ty.appTitle      = 20;   % application title
    ty.sectionTitle  = 11;   % section titles
    ty.panelTitle    = 12;   % panel titles
    ty.label         = 10;   % metric labels
    ty.labelSmall    = 9;    % supporting labels
    ty.value         = 13;   % metric values
    ty.valueLarge    = 16;   % headline values
    ty.valueHero     = 18;   % referral verdict
    ty.support       = 9;    % sub-notes / disclaimers
    ty.tiny          = 8;    % catch-lines
    th.type = ty;

    %% ---- Grad-CAM rendering config (single source of truth) ----
    g = struct();
    g.colormap   = 'turbo';        % turbo > inferno > parula (all in R2026a)
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