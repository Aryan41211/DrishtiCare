function [agree, discrepancy, detail] = fuseEvidence(aInfo, bInfo)
%FUSEEVIDENCE Evidence-agreement between Branch A (deep) and Branch B (lesion).
%   [agree, discrepancy, detail] = fuseEvidence(aInfo, bInfo)
%
%   aInfo: struct with .grade (0-4 int), .pRefCal (calibrated P referable),
%          .confident (logical).  A referable iff grade>=2 OR pRefCal>=0.60.
%   bInfo: struct with .pRefB (0-1 or NaN) and .available (logical).
%          B referable iff pRefB>=0.60.
%
%   Fusion rule: Both referable -> agree.  Both non-referable and Branch A
%   confident -> agree.  A referable + B non-referable -> discrepancy REVIEW
%   (never downgrades a referable A).  A non-referable + B referable ->
%   discrepancy REVIEW.  If B is unavailable, fusion is "no conflict"
%   (agree=false, discrepancy=false, routeOverride='').
%
%   detail fields: .aReferable_pop, .bReferable, .routeOverride, .reason,
%   .confident.

    aReferable = (isfield(aInfo,'grade') && aInfo.grade >= 2) ...
               || (isfield(aInfo,'pRefCal') && aInfo.pRefCal >= 0.60);
    aConfident = isfield(aInfo,'confident') && aInfo.confident;

    if isempty(bInfo) || ~isfield(bInfo, 'available') || ~bInfo.available ...
       || ~isfield(bInfo, 'pRefB') || isempty(bInfo.pRefB) || isnan(bInfo.pRefB)
        agree = false; discrepancy = false;
        detail = struct('aReferable_pop', aReferable, 'bReferable', NaN, ...
                        'routeOverride', '', 'reason', 'Branch B unavailable; fusion skipped', ...
                        'confident', aConfident);
        return;
    end

    bRef = bInfo.pRefB >= 0.60;

    routeOverride = '';
    if aReferable && bRef
        agree = true; discrepancy = false; reason = 'Agree: both referable';
    elseif ~aReferable && ~bRef
        if aConfident
            agree = true; discrepancy = false;
            reason = 'Agree: both non-referable, Branch A confident';
        else
            agree = false; discrepancy = true;
            reason = 'Both non-referable but Branch A not confident; review';
            routeOverride = 'REVIEW';
        end
    elseif aReferable && ~bRef
        agree = false; discrepancy = true;
        reason = 'Discrepancy: Branch A referable, Branch B non-referable';
        routeOverride = 'REVIEW';
    else % ~aReferable && bRef
        agree = false; discrepancy = true;
        reason = 'Discrepancy: Branch A non-referable, Branch B referable';
        routeOverride = 'REVIEW';
    end

    detail = struct('aReferable_pop', aReferable, 'bReferable', bRef, ...
                    'routeOverride', routeOverride, 'reason', reason, ...
                    'confident', aConfident);
end