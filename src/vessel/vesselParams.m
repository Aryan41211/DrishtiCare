function P = vesselParams(preset)
%VESSELPARAMS Named CONFIG presets for the classical vessel segmenter.
%   P = vesselParams()                -> current default ('baseline_0.743')
%   P = vesselParams('baseline_0.743')-> exact config that produced the
%                                        original best numbers. NOTE: that
%                                        result was tuned partly on DRIVE
%                                        *test* images in earlier sessions
%                                        (test-set tuning limitation).
%   P = vesselParams('champion')      -> best config found by the experiment
%                                        harness in the current session
%                                        (tuned only on the DRIVE dev split
%                                        and locked before touching test).
%                                        Loaded from
%                                        data\analysis\vessel\champion_config.mat
%                                        (written by runVesselExperiments);
%                                        falls back to the baseline if absent.
%   P = vesselParams('legacy_broken') -> approximation of the ORIGINAL
%                                        src\extractVessels.m algorithm as a
%                                        config (documentation / ablation).
%
%   The returned struct is a full extractVessels CONFIG: pass it directly to
%   extractVessels(img, P) (optionally with 'fov', Mask). All tuning values
%   live here so experiments are reproducible by construction.
%   This is a research prototype, NOT a clinically validated system.

if nargin < 1
    preset = 'baseline_0.743';
end

switch lower(preset)
    case {'baseline_0.743', 'baseline', 'default', ''}
        P = baselineCfg();

    case 'champion'
        P = baselineCfg();
        cfgFile = fullfile(fileparts(mfilename('fullpath')), '..', '..', ...
            'data', 'analysis', 'vessel', 'champion_config.mat');
        if exist(cfgFile, 'file')
            s = load(cfgFile);
            P = championFromExperiment(P, s.champion);
        end

    case 'legacy_broken'
        % The ORIGINAL algorithm (src\extractVessels.m): grayscale, CLAHE,
        % single disk-8 bottom-hat, Otsu, area-20, thin.
        P = baselineCfg();
        P.gateWeight      = 0;     % no Frangi gating
        P.morphThickness  = [8];   % single bottom-hat scale
        P.lineLength      = 0;     % skip line-opening cleanup
        P.legacyThin      = true;  % approximation note: the ORIGINAL also
                                   % applied bwmorph('thin',Inf) and used
                                   % grayscale (not green) + minArea 20;
                                   % those details are NOT reproducible
                                   % through extractVessels, documented only.

    otherwise
        error('vesselParams:unknown', 'Unknown preset ''%s''.', preset);
end
end

%% ------------------------------------------------------------------------
function P = baselineCfg()
%BASELINECFG The exact CONFIG of the 0.743 champion pipeline (native
%extractVessels keys). This equals the current extractVessels defaults.
    P = struct();

    % -- CLAHE contrast enhancement ----------------------------------------
    P.claheNumTiles    = [8 8];
    P.claheClipLimit   = 0.02;

    % -- Multi-scale bottom-hat ---------------------------------------------
    P.morphThickness   = [2 4 6 8];

    % -- Tubularity gate -----------------------------------------------------
    P.gateThickness    = [3 4 5];
    P.gatePolarity     = 'bright';
    P.gateWeight       = 0.4;

    % -- Thresholding --------------------------------------------------------
    P.thresholdMethod  = 'otsu';
    P.thresholdScale   = 1.00;
    P.adaptSensitivity = 0.50;
    P.thresholdFrac    = 0.15;

    % -- Morphological cleanup -------------------------------------------------
    P.lineLength       = 9;
    P.lineAngles       = 0:30:150;
    P.closeDisk        = 2;
    P.minArea          = 40;

    % -- Field of view --------------------------------------------------------
    P.fovErodeRadius   = 15;
end

function P = championFromExperiment(P, expCfg)
%CHAMPIONFROMEXPERIMENT Map the harness experiment config onto native
%extractVessels keys. Required fields used by the shipped extractVessels.
    if isfield(expCfg, 'bhThickness'),  P.morphThickness   = expCfg.bhThickness; end
    if isfield(expCfg, 'gateThickness'),P.gateThickness    = expCfg.gateThickness; end
    if isfield(expCfg, 'gatePolarity'), P.gatePolarity     = expCfg.gatePolarity; end
    if isfield(expCfg, 'gateWeight'),   P.gateWeight       = expCfg.gateWeight; end
    if isfield(expCfg, 'thresholdMethod'), P.thresholdMethod = expCfg.thresholdMethod; end
    if isfield(expCfg, 'thresholdScale'),  P.thresholdScale  = expCfg.thresholdScale; end
    if isfield(expCfg, 'thresholdFrac'),   P.thresholdFrac   = expCfg.thresholdFrac; end
    if isfield(expCfg, 'adaptSensitivity'),P.adaptSensitivity = expCfg.adaptSensitivity; end
    if isfield(expCfg, 'lineLength'),    P.lineLength      = expCfg.lineLength; end
    if isfield(expCfg, 'lineAngles'),    P.lineAngles      = expCfg.lineAngles; end
    if isfield(expCfg, 'closeDisk'),     P.closeDisk       = expCfg.closeDisk; end
    if isfield(expCfg, 'minArea'),       P.minArea         = expCfg.minArea; end
end