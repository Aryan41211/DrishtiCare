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
    rgb = reshape(double(sscanf(h(2:end), '%2x%2x%2x')) / 255, 1, 3);
end
