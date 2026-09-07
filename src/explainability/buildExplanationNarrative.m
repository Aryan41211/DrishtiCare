function narrative = buildExplanationNarrative(result)
%BUILDEXPLANATIONNARRATIVE Turn DrishtiCare inference evidence into a
%clinical-style, hedged explanation paragraph.
%   narrative = buildExplanationNarrative(result)
%
%   result is the struct returned by predictSingleFundus. Returns
%   narrative with fields:
%     .paragraph   full paragraph (human-readable, multi-sentence)
%     .assessment  severity sentence(s)
%     .evidence    evidence-basis sentence(s) (lesion candidates, OD)
%     .confidence  confidence sentence
%     .recommendation referral/conservative-care sentence
%     .caveats     non-clinical-device + quality caveats
%
%   All lesion counts are candidate detections (classical + CNN), NOT
%   clinical-grade; the text always says so. ENGINEERING demo, not a
%   clinical device.

hasLesions = isfield(result, 'lesions') && isfield(result.lesions, 'maCount');

% ---------- severity assessment ----------
grade = result.grade;                 % 0..4
desc = gradeDescriptor(grade);
if result.confidence >= 0.80
    assess = ['DR severity assessed as ' result.gradeLabel ' (grade ' num2str(grade) ...
        '): ' desc ', with model confidence ' sprintf('%.1f%%', result.confidence*100) '.'];
else
    assess = ['DR severity assessed as ' result.gradeLabel ' (grade ' num2str(grade) ...
        '), model confidence ' sprintf('%.1f%%', result.confidence*100) ...
        ' — borderline between adjacent grades, manual review advised.'];
end

% ---------- evidence from lesion candidates ----------
if hasLesions
    ma = result.lesions.maCount; he = result.lesions.heCount; ex = result.lesions.exCount;
    q = result.lesions.quadrantHemorrhage;   % [TR TL BL BR]
    nQ = sum(q > 0);
    ev = sprintf('Lesion-candidate scan found %d microaneurysms, %d haemorrhages and %d hard exudate regions', ma, he, ex);
    if nQ > 0
        if nQ >= 3
            ev = [ev sprintf('; haemorrhages are spread across %d of 4 quadrants (TR/TL/BL/BR = %d/%d/%d/%d), indicating more extensive involvement', nQ, q(1), q(2), q(3), q(4))];
        else
            ev = [ev sprintf('; haemorrhages are present in %d quadrant(s) (TR/TL/BL/BR = %d/%d/%d/%d)', nQ, q(1), q(2), q(3), q(4))];
        end
    end
    if result.lesions.odLocated
        ev = [ev sprintf(', and the optic disc was located and excluded from exudate counting')];
    else
        ev = [ev sprintf('; the optic disc was NOT reliably located, so exudate and haemorrhage counts near the disc may include disc tissue')];
    end
    if isfinite(result.lesions.meanExudateDistToFovea)
        ev = [ev sprintf(' (mean exudate-to-fovea distance %d px, closest %d px)', ...
            round(result.lesions.meanExudateDistToFovea), round(result.lesions.minExudateDistToFovea))];
    end
    ev = [ev '. These are automated candidate counts (not clinical-grade measurements) and serve as supportive evidence only.'];
else
    ev = 'Lesion candidate analysis was disabled or unavailable.';
end

% ---------- screening interpretation ----------
scr = sprintf('Screening interpretation at the locked referability threshold (%.2f): the image is flagged %s (P(referable) = %.1f%%).', ...
    result.binaryThreshold, result.binaryDecision, result.binaryProbability*100);

% ---------- governance: OOD flag + cascade route ----------
gov = '';
if isfield(result, 'ood') && isfield(result.ood, 'available') && result.ood.available
    if result.ood.flag
        gov = 'The sample is flagged as OUT-OF-DISTRIBUTION relative to the training population (Mahalanobis distance beyond threshold), so automated conclusions should be treated cautiously and a manual review is strongly advised.';
        oodReview = true;
    else
        gov = 'The sample is within the model''s training distribution (Mahalanobis distance within threshold).';
        oodReview = false;
    end
else
    oodReview = false;
end
crowReview = false;
if isfield(result, 'cascade') && isfield(result.cascade, 'available') && result.cascade.available
    if ~isempty(gov), gov = [gov ' ']; end
    switch result.cascade.route
        case 'ABSTAIN'
            gov = [gov 'The confidence router ABSTAINED due to uncertainty near the referral boundary or low classification confidence, so the result should not be auto-answered and requires specialist review.'];
            crowReview = true;
        case 'REVIEW'
            gov = [gov 'The confidence router flagged REVIEW (borderline confidence, adjacent-grade ambiguity, or screen/grader disagreement); a specialist check is advised.'];
            crowReview = true;
        case 'CLEAR'
            gov = [gov 'The confidence router marked the case CLEAR (high confidence, clear class margin, and screen/grader agreement).'];
    end
end

% ---------- recommendation ----------
needsReview = crowReview || oodReview || result.grade >= 3 || ...
    (isfield(result,'ood') && isfield(result.ood,'flag') && result.ood.flag);
if result.grade >= 3
    rec = 'Recommend urgent specialist review — findings suggest severe or proliferative retinopathy.';
elseif result.grade == 2
    rec = 'Recommend referral for specialist examination — moderate non-proliferative findings.';
elseif needsReview
    rec = 'Recommend follow-up evaluation — automated confidence is reduced (low confidence, out-of-distribution sample, or borderline case), so clinical confirmation is advised.';
elseif strcmp(result.binaryDecision, 'REFERABLE')
    rec = 'Recommend follow-up evaluation — early DR signs warrant clinical confirmation.';
else
    rec = 'No referable DR features were detected by the screening model; routine follow-up per clinical schedule is advised.';
end

% ---------- quality caveat ----------
qc = sprintf('Image quality: %s (score %.2f).', result.qualityStatus, result.qualityScore);
if ~strcmp(result.qualityStatus, 'PASS')
    qc = [qc ' The quality flags advise caution in accepting the prediction.'];
end

% ---------- assemble ----------
para = ['This analysis is an engineering demonstration and is NOT intended for clinical use or diagnosis. ' ...
    assess ' ' scr ' ' ev ' ' qc ' '];
if ~isempty(gov)
    para = [para gov ' '];
end
para = [para rec];
narrative.paragraph = para;
narrative.assessment = assess;
narrative.evidence = ev;
narrative.screening = scr;
narrative.recommendation = rec;
narrative.quality = qc;
narrative.governance = gov;
narrative.caveats = 'Engineering demonstration only. Automated lesion counts are supportive, not clinical-grade. Clinical correlation is required.';
end

function s = gradeDescriptor(g)
switch g
    case 0, s = 'no visible diabetic-retinopathy features detected';
    case 1, s = 'mild non-proliferative retinopathy (limited microaneurysm/lesion burden)';
    case 2, s = 'moderate non-proliferative retinopathy (more extensive haemorrhage/aneurysm burden)';
    case 3, s = 'severe non-proliferative retinopathy (widespread lesions across quadrants)';
    case 4, s = 'proliferative diabetic retinopathy (neovascularisation risk)';
    otherwise, s = 'unspecified severity';
end
end