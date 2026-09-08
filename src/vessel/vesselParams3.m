function cfg = vesselParams3(preset)
%VESSELPARAMS3 Named parameter presets for extractVessels3 (Phase-3 candidate).
%
%   vesselParams3            -> default candidate config (struct).
%   vesselParams3('name')    -> named preset from the table below.
%
%   The returned struct is passed to extractVessels3 as `Params`:
%       cfg  = vesselParams3('phase3');
%       [V, R, F, D] = extractVessels3(img, cfg, 'fov', fovMask);
%
%   Presets:
%     'phase3_default' - default candidate. Champion-equivalent enhancement
%                        (CLAHE -> multi-scale bottom-hat -> mild Frangi
%                        gate) PLUS surgical optic-disc-rim and bright-
%                        lesion suppression, percentile thresholding and
%                        thin-vessel-preserving cleanup. Flat-field stage
%                        present but OFF (strong global flat-fielding
%                        destroyed vessel contrast in tests).
%     'phase3'         - alias of 'phase3_default'.
%     'phase3_locked'  - LOCKED candidate (same as default minus the OD
%                        stage; dev-selected highest precision within the
%                        Dice band). Use this for the release command.
%
%   NOTE: this configures extractVessels3 ONLY. The session champion
%   (extractVessels.m + vesselParams('champion')) is intentionally separate
%   and unchanged.

    if nargin < 1 || isempty(preset)
        preset = 'phase3_default';
    end

    s = struct();

    switch lower(preset)
        case {'phase3', 'phase3_default'}
            s.greenChannel      = true;
            s.fovErodeRadius    = 15;
            s.flatFieldEnable   = false;
            s.bgSigma           = 30;
            s.bgErodeFrac       = 6;
            s.bgClampLo         = 0;
            s.bgClampHi         = 1;
            s.claheNumTiles     = [8 8];
            s.claheClipLimit    = 0.02;
            s.morphThickness    = [2 3 4 6 8];
            s.gateThickness     = [2 3 4 5 6];
            s.gatePolarity      = 'bright';
            s.gateWeight        = 0.5;
            s.odEnable          = true;
            s.odBrightPerc      = 96;
            s.odMinSize         = 2000;
            s.odMaxFrac         = 0.10;
            s.odNearCenter      = 0.55;
            s.odDilateFrac      = 1.5;
            s.odRingFrac        = 0.55;
            s.odRingAtten       = 0.05;
            s.odInteriorAtten   = 0.85;
            s.brightEnable      = true;
            s.brightPerc        = 99;
            s.brightMinSize     = 30;
            s.brightDilate      = 3;
            s.brightAtten       = 0.05;
            s.brightMaxFrac     = 0.05;
            s.thresholdMethod   = 'percentile';
            s.thresholdFrac     = 0.13;
            s.adaptSensitivity  = 0.50;
            s.thresholdScale    = 1.00;
            s.lineLength        = 9;
            s.lineAngles        = 0:15:165;
            s.thinPreserve      = false;
            s.closeDisk         = 2;
            s.minArea           = 40;
            s.doBridge          = true;
        case 'phase3_locked'
            % LOCKED Phase-3 candidate (dev-selected on DRIVE training 21-40,
            % evaluated exactly once on DRIVE test 01-20). Same as
            % 'phase3_default' but with the optic-disc stage DISABLED: on
            % DRIVE dev the OD suppression removed ~as many true central
            % vessels as the FP it killed, so the locked config (highest
            % precision within 0.003 Dice of best) keeps it off. The OD
            % stage remains available via odEnable=true.
            s.greenChannel      = true;
            s.fovErodeRadius    = 15;
            s.flatFieldEnable   = false;
            s.bgSigma           = 30;
            s.bgErodeFrac       = 6;
            s.bgClampLo         = 0;
            s.bgClampHi         = 1;
            s.claheNumTiles     = [8 8];
            s.claheClipLimit    = 0.02;
            s.morphThickness    = [2 3 4 6 8];
            s.gateThickness     = [2 3 4 5 6];
            s.gatePolarity      = 'bright';
            s.gateWeight        = 0.5;
            s.odEnable          = false;
            s.odBrightPerc      = 96;
            s.odMinSize         = 2000;
            s.odMaxFrac         = 0.10;
            s.odNearCenter      = 0.55;
            s.odDilateFrac      = 1.5;
            s.odRingFrac        = 0.55;
            s.odRingAtten       = 0.05;
            s.odInteriorAtten   = 0.85;
            s.brightEnable      = true;
            s.brightPerc        = 99;
            s.brightMinSize     = 30;
            s.brightDilate      = 3;
            s.brightAtten       = 0.05;
            s.brightMaxFrac     = 0.05;
            s.thresholdMethod   = 'percentile';
            s.thresholdFrac     = 0.13;
            s.adaptSensitivity  = 0.50;
            s.thresholdScale    = 1.00;
            s.lineLength        = 9;
            s.lineAngles        = 0:15:165;
            s.thinPreserve      = false;
            s.closeDisk         = 2;
            s.minArea           = 40;
            s.doBridge          = true;
        otherwise
            error('vesselParams3:badPreset', ...
                'Unknown preset ''%s''.', preset);
    end

    cfg = s;
end