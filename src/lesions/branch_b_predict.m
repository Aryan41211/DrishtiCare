function pRefB = branch_b_predict(featRow, model)
%BRANCH_B_PREDICT P(referable) from a Branch B lesion-feature row.
%   pRefB = branch_b_predict(featRow, model)
%   featRow: 1x10 double in the same order as model.features.
%   model: struct saved by trainBranchB (fields .mdl .kind .T .mx .features).
%   Returns scalar 0-1 (temperature-scaled when model.T ~= 1).

    X = double(featRow(:)');
    if numel(X) ~= numel(model.features)
        error('branch_b_predict: feature length mismatch');
    end
    X = X ./ model.mx;
    [~, sc] = predict(model.mdl, X);
    s = sc(:, double(model.mdl.ClassNames)==1);
    if numel(s) > 1
        % predict returned a column of scores per row; caller should pass
        % one row, but keep scalar output contract
        s = s(:)';
    end
    if ~isscalar(s)
        s = max(s, [], 2);
    end
    if model.T ~= 1
        pRefB = temperatureScale(s, model.T);
    else
        pRefB = s;
    end
    pRefB = min(max(pRefB, 0), 1);
    if numel(pRefB) > 1
        pRefB = pRefB(1);
    end
end