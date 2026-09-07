function pcal = temperatureScale(pRef, T)
%TEMPERATURESCALE Constrained temperature scaling for referable probability.
%   pcal = temperatureScale(pRef)        — identity (T=1)
%   pcal = temperatureScale(pRef, T)     — scaled with temperature T
%
%   Engineering calibration tool, NOT a clinical device. Applies constrained
%   temperature scaling to a referable probability pRef using temperature T.
%
%   Implementation:
%     z   = clip(logit(pRef), -40, 40)
%     pcal = sigmoid(z / T)
%
%   where logit(p) = log(p / (1-p)), sigmoid(x) = 1/(1+exp(-x)).
%
%   Inputs:
%     pRef — scalar or array of raw referable probabilities in [0,1]
%     T    — scalar temperature parameter (T>0). T=1 is identity (no change).
%            Default T=1 if empty or omitted.
%
%   Output:
%     pcal — calibrated probabilities, same size as pRef

    if nargin < 2 || isempty(T)
        T = 1.0;
    end

    if T <= 0
        error('temperatureScale:invalidT', ...
              'Temperature T must be positive. Got %.4f.', T);
    end

    p = pRef(:);

    % Clip p into [1e-6, 1-1e-6] to avoid inf in logit
    p = max(p, 1e-6);
    p = min(p, 1 - 1e-6);

    % Logit, clipped to [-40, 40] for numerical safety
    z = log(p ./ (1 - p));
    z = max(z, -40);
    z = min(z,  40);

    % Temperature-scaled sigmoid
    pcal = 1 ./ (1 + exp(-z / T));

    % Reshape to match input
    pcal = reshape(pcal, size(pRef));
end
