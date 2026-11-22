function t = drishtiTokensDark()
%DRISHTITOKENSDARK Dark presentation theme for the DrishtiCare DRISHTI + Lesion desktop UI.
%   t = drishtiTokensDark()
%
%   Mirrors drishtiTokens.m field-for-field but with the dark desktop palette
%   taken from the DRISHTI + Lesion reference:
%     canvas   #202020  (main background)
%     header   #15365F  (navy-blue header)
%     surface  #202020  (panel background)
%     border   #666666  (panel borders / separators)
%     heading  #174A80  (section headings)
%     primary  #0866A5  (primary button)
%     secondary#555555  (secondary button)
%     success  #00B52B
%     warning  #FF9900
%     danger   #E53935
%     ink      #F0F0F0  (primary text)
%     inkMuted #A0A0A0  (secondary text)
%
%   drishtiThemeDark() is a thin facade over this file, so the dark desktop app
%   and the light PDF report cannot drift apart. The PDF report keeps reading
%   drishtiTokens() (light) and is unaffected.
%
%   The theme only owns PRESENTATION. It never changes model outputs, quality
%   thresholds, referral decisions or any engineering value.
%
%   ENGINEERING prototype styling. NOT a clinical device.

    t = struct();

    %% ---- surfaces -------------------------------------------------------
    t.canvas    = hex2rgb('#202020');   % figure / main background
    t.surface   = hex2rgb('#202020');   % panels, cards
    t.sunken    = hex2rgb('#2A2A2A');   % axes wells, advice box (slightly lighter than surface)
    t.header    = hex2rgb('#15365F');   % navy-blue application header
    % hairline border, one documented colour
    t.hairline  = hex2rgb('#666666');   % panel borders

    %% ---- ink ------------------------------------------------------------
    t.ink       = hex2rgb('#F0F0F0');   % primary text
    t.inkMuted  = hex2rgb('#A0A0A0');   % secondary text
    t.inkFaint  = hex2rgb('#707070');   % reserved non-text (ticks, rules)

    %% ---- decision tones -------------------------------------------------
    t.danger     = hex2rgb('#E53935');  % referable / FAIL / reject
    t.success    = hex2rgb('#00B52B');  % accept / not-referable
    t.primary    = hex2rgb('#0866A5');  % the single accent (primary button)
    t.secondary  = hex2rgb('#555555');  % secondary button
    t.heading    = hex2rgb('#174A80');  % section headings
    t.dangerBg   = hex2rgb('#2A1B1B');  % tinted fill (danger text on this)
    t.successBg  = hex2rgb('#1B2A1B');  % tinted fill (success text on this)
    t.warningFill = hex2rgb('#3A2A00'); % tinted fill (warning ink on this)
    t.warningInk  = hex2rgb('#FFB347'); % warning text on warningFill

    %% ---- typographic scale ----------------------------------------------
    t.type = struct( ...
        'display', 18, ...  % application title
        'metric',  15, ...  % headline values
        'body',    12, ...  % values, table text
        'label',   11, ...  % labels and section titles (uppercase)
        'caption',  9);     % disclaimers, units, footnotes

    %% ---- spacing: 4px progression ----------------------------------------
    t.spacing = struct('s1', 4, 's2', 8, 's3', 12, 's4', 16, 's5', 24);

end

% -------------------------------------------------------------------------
function rgb = hex2rgb(h)
%HEX2RGB '#RRGGBB' -> 1x3 double in [0 1].
    rgb = reshape(double(sscanf(h(2:end), '%2x%2x%2x')) / 255, 1, 3);
end
