function T = loadTemperatureParams(varargin)
%LOADTEMPERATUREPARAMS Load the currently fitted temperature parameter.
%   T = loadTemperatureParams()
%   T = loadTemperatureParams('Override', 0.8)
%
%   Reads from data/analysis/day8/calibration/:
%     Priority 1: current_T.mat (variable 'T')
%     Priority 2: returns T=1.0 (identity, no calibration effect)
%
%   This is a READ of whatever exists — the coordinator decides which
%   strategy's T to promote into current_T.mat.
%
%   Inputs (Name-Value):
%     'Override' — if provided and non-empty, return this value instead
%                  of reading from disk. Useful for what-if exploration.
%
%   Output:
%     T — scalar temperature parameter (T>0), default 1.0

    p = inputParser;
    addParameter(p, 'Override', [], @(x) isnumeric(x) && isscalar(x));
    parse(p, varargin{:});

    if ~isempty(p.Results.Override)
        T = p.Results.Override;
        return;
    end

    projectRoot = pwd;
    calDir = fullfile(projectRoot, 'data', 'analysis', 'day8', 'calibration');
    candidateFile = fullfile(calDir, 'current_T.mat');

    T = 1.0;  % default identity
    if exist(candidateFile, 'file')
        try
            S = load(candidateFile, 'T');
            if isfield(S, 'T') && isscalar(S.T) && S.T > 0
                T = S.T;
            end
        catch
            % If file exists but is corrupt or T is missing, fall back to 1.0
        end
    end
end
