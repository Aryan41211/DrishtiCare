function [route, detail] = cascade_router(grade, s5, pRef, opts)
%CASCADEROUTER Route screening cases to CLEAR / REVIEW / ABSTAIN.
%
%   [route, detail] = cascadeRouter(grade, s5, pRef)
%   [route, detail] = cascadeRouter(grade, s5, pRef, opts)
%
%   Takes the 5-class grading output and binary screening probability, and
%   decides whether the case can be auto-answered (CLEAR), needs a human
%   look (REVIEW), or is too uncertain to even assign a direction (ABSTAIN).
%
%   INPUTS
%     grade  - integer 0-4, predicted DR grade (argmax of s5)
%     s5     - 1x5 row vector of class probabilities (sums to 1),
%              ordered [NoDR Mild Moderate Severe Proliferative]
%     pRef   - scalar P(referable) from the binary screener (locked thr=0.60)
%     opts   - (optional) struct overriding any default threshold:
%                .abstainConf   - confidence below this -> ABSTAIN (0.50)
%                .reviewConf    - confidence below this -> REVIEW (0.75)
%                .marginThr     - top1-top2 margin below this -> REVIEW (0.20)
%                .pRefBand      - half-width around 0.60 that triggers ABSTAIN (0.05)
%                .pRefLocked    - the locked binary threshold (0.60, DO NOT CHANGE)
%                .agreePRef     - screen/grade disagreement threshold on pRef (0.50)
%
%   OUTPUTS
%     route  - char: 'CLEAR', 'REVIEW', or 'ABSTAIN'
%     detail - struct with the decision metrics and applied thresholds:
%              .confidence, .margin, .grade, .gradeLabel, .pRef,
%              .adjacentAmbiguous, .screenGradeConflict,
%              .bandPRefNearThreshold, .abstainConf, .reviewConf,
%              .marginThr, .pRefBand, .pRefLocked, .agreePRef,
%              .abstainReason, .reviewReason
%
%   ROUTING RULE (priority: ABSTAIN > REVIEW > CLEAR)
%
%   ABSTAIN (too uncertain to auto-answer):
%     (a) Grade confidence < abstainConf (default 0.50): the model itself
%         is unsure of the severity. A wrong label here could send a
%         sight-threatening case home or waste clinic time on a healthy eye.
%     (b) pRef within pRefBand of the locked 0.60 threshold: this is the
%         exact decision boundary where referral errors are most costly.
%         Near 0.60 the screener is equivocal and small calibration drift
%         could flip the outcome. Flag for human review rather than risk
%         a borderline wrong call.
%
%   REVIEW (model has a lean but is not confident enough for auto-route):
%     (a) Confidence < reviewConf (default 0.75): above abstain floor but
%         still not strong enough to trust without oversight.
%     (b) Top-1 vs top-2 margin < marginThr (default 0.20): the model is
%         splitting probability between two adjacent grades (classic
%         Moderate-vs-Severe ambiguity). This is the most frequent failure
%         mode in DR grading because clinical boundaries between adjacent
%         grades are inherently fuzzy.
%     (c) Screen/grade disagreement: grade<=1 (non-referable) but pRef>0.50
%         (screener leans referable), OR grade>=2 (referable) but pRef<0.50
%         (screener leans non-referable). When the two models disagree on
%         the clinical direction, a human must arbitrate.
%
%   CLEAR (auto-answerable):
%     None of the above conditions triggered. The model is confident, the
%     margin is wide, and the two models agree on clinical direction.
%
%   NOTES
%     - The binary threshold 0.60 is LOCKED and must not be changed.
%       This function only reads its value for proximity checks.
%     - Thresholds are fully tunable via opts to support calibration
%       experiments. Defaults are conservative to err on the side of safety.
%     - This is an engineering tool, not a clinical device.

    % --- defaults -----------------------------------------------------------
    if nargin < 4, opts = struct(); end
    def.abstainConf  = 0.50;   % below this confidence -> too uncertain, abstain
    def.reviewConf   = 0.75;   % below this confidence -> needs review
    def.marginThr    = 0.20;   % top1-top2 margin below this -> ambiguous
    def.pRefBand     = 0.05;   % half-width around 0.60 -> abstain zone
    def.pRefLocked   = 0.60;   % locked binary threshold (DO NOT CHANGE)
    def.agreePRef    = 0.50;   % screen/grade disagreement pivot

    % merge user overrides with defaults
    fnames = fieldnames(def);
    for i = 1:numel(fnames)
        f = fnames{i};
        if ~isfield(opts, f)
            opts.(f) = def.(f);
        end
    end

    % --- derived metrics -----------------------------------------------------
    confidence = max(s5);
    [sorted, idx] = sort(s5, 'descend');
    top1 = sorted(1);
    top2 = sorted(2);
    margin = top1 - top2;

    gradeLabels = {'No DR','Mild','Moderate','Severe','Proliferative'};
    gLabel = gradeLabels{grade + 1};   % grade is 0-4, index is 1-5

    % Adjacent-ambiguous: top-2 class is a neighbour of top-1 in the ordinal
    % scale. This catches the clinical failure mode where Moderate is 0.45
    % and Severe is 0.43 -- close enough that the true grade could go
    % either way, and treatment decisions differ significantly.
    adjacentAmbiguous = abs(idx(1) - idx(2)) == 1;

    % pRef near the locked threshold: the binary screener sits right on
    % the referral cutoff. Even a tiny calibration shift flips referable
    % vs non-referable. This is the highest-stakes zone.
    bandPRefNearThreshold = abs(pRef - opts.pRefLocked) < opts.pRefBand;

    % Screen/grade disagreement: binary screener and 5-class grader
    % disagree on the referable / non-referable direction.
    screenGradeConflict = (grade <= 1 && pRef > opts.agreePRef) || ...
                          (grade >= 2 && pRef < opts.agreePRef);

    % --- routing logic (ABSTAIN checked first, then REVIEW, else CLEAR) ------
    abstainReason = '';
    reviewReason  = '';

    % ABSTAIN: highest priority -- too uncertain to route at all
    if confidence < opts.abstainConf
        abstainReason = sprintf('confidence %.2f < abstainConf %.2f', ...
            confidence, opts.abstainConf);
    elseif bandPRefNearThreshold
        abstainReason = sprintf('|pRef %.2f - locked %.2f| = %.3f < pRefBand %.3f', ...
            pRef, opts.pRefLocked, abs(pRef - opts.pRefLocked), opts.pRefBand);
    end

    if ~isempty(abstainReason)
        route = 'ABSTAIN';
    else
        % REVIEW: model leans a way but has risk factors
        reasons = {};
        if confidence < opts.reviewConf
            reasons{end+1} = sprintf('confidence %.2f < reviewConf %.2f', ...
                confidence, opts.reviewConf);
        end
        if margin < opts.marginThr
            reasons{end+1} = sprintf('margin %.2f < marginThr %.2f (adj=%d)', ...
                margin, opts.marginThr, adjacentAmbiguous);
        end
        if screenGradeConflict
            reasons{end+1} = sprintf('screen/grade disagree (grade=%d pRef=%.2f)', ...
                grade, pRef);
        end

        if ~isempty(reasons)
            route = 'REVIEW';
            reviewReason = strjoin(reasons, '; ');
        else
            route = 'CLEAR';
        end
    end

    % --- detail struct -------------------------------------------------------
    detail = struct();
    detail.confidence = confidence;
    detail.margin = margin;
    detail.grade = grade;
    detail.gradeLabel = gLabel;
    detail.pRef = pRef;
    detail.adjacentAmbiguous = adjacentAmbiguous;
    detail.screenGradeConflict = screenGradeConflict;
    detail.bandPRefNearThreshold = bandPRefNearThreshold;
    detail.abstainConf = opts.abstainConf;
    detail.reviewConf = opts.reviewConf;
    detail.marginThr = opts.marginThr;
    detail.pRefBand = opts.pRefBand;
    detail.pRefLocked = opts.pRefLocked;
    detail.agreePRef = opts.agreePRef;
    detail.abstainReason = abstainReason;
    detail.reviewReason = reviewReason;
end
