function result = predictSingleFundus(imagePath, varargin)
% PREDICTSINGLEFUNDUS Full DrishtiCare inference on one fundus image
%   result = predictSingleFundus(imagePath)
%
%   Pipeline (EXACT same preprocessing as training):
%     raw -> imresize 224 -> quality gate -> binary screening (pretrained)
%     -> 5-class grading (pretrained) -> Grad-CAM
%     -> [lesion evidence: {MA,HE,EX} candidates + optic disc] (lesions)
%
%   Returns struct: qualityStatus, qualityScore, binaryProbability,
%   binaryProbabilityCalibrated, calibrationTemperature, binaryDecision,
%   binaryThreshold, grade, gradeLabel, classProbabilities,
%   confidence, gradCAM, lesions.
%
%   ENGINEERING demo tool. NOT a clinical device.

    p = inputParser;
    addParameter(p, 'BinaryModel', '', @ischar);
    addParameter(p, 'GradeModel', '', @ischar);
    addParameter(p, 'BinaryThreshold', 0.60, @isnumeric);
    addParameter(p, 'ShowFigure', true, @islogical);
    addParameter(p, 'RunLesions', true, @islogical);
    addParameter(p, 'RunBranchB', true, @islogical);
    parse(p, varargin{:});

    projectRoot = pwd;
    addpath(fullfile(projectRoot, 'src', 'ood_detection'), ...
            fullfile(projectRoot, 'src', 'cascade_router'), ...
            fullfile(projectRoot, 'src', 'calibration'), ...
            fullfile(projectRoot, 'src', 'lesions'));
    modelDir = fullfile(projectRoot, 'data', 'models');
    if isempty(p.Results.BinaryModel)
        binPath = fullfile(modelDir, 'day7_pretrained_resnet18_binary_stage2.mat');
    else
        binPath = p.Results.BinaryModel;
    end
    if isempty(p.Results.GradeModel)
        gradePath = fullfile(modelDir, 'day7_pretrained_resnet18_5class_stage2.mat');
    else
        gradePath = p.Results.GradeModel;
    end
    thr = p.Results.BinaryThreshold;

    SB = load(binPath, 'trainedNet');
    S5 = load(gradePath, 'trainedNet');
    netB = SB.trainedNet;
    net5 = S5.trainedNet;
    gradeLabels = {'No DR', 'Mild', 'Moderate', 'Severe', 'Proliferative'};

    % 1-2. Load + EXACT training preprocessing
    raw = imread(imagePath);
    if size(raw, 3) == 1, raw = repmat(raw, 1, 1, 3); end
    modelInput = imresize(raw, [224 224]);

    % 3. Quality assessment (Day 3 gate)
    q = assessImageQuality(raw);
    qualityStatus = q.overall;
    qualityScore = q.qualityScore;

    % 4. Enhancement for display (Day 4, display only)
    [enhanced, ~] = enhanceImage(raw);
    enhanced = imresize(enhanced, [224 224]);

    % 5-6. Binary screening + 5-class grading
    sB = predict(netB, modelInput); sB = sB(:)';
    pRef = sB(2);  % referable = 2nd alphabetical class
    binaryDecision = 'NON-REFERABLE';
    if pRef >= thr, binaryDecision = 'REFERABLE'; end

    % --- Temperature calibration (engineering tool, not clinical) ---
    try
        T = loadTemperatureParams();
    catch
        T = 1.0;
    end
    pCalibrated = temperatureScale(pRef, T);

    [pred5, s5] = classify(net5, modelInput);
    s5 = s5(:)';
    [conf, gradeIdx] = max(s5);

    % 9. Grad-CAM for predicted grade
    cmap = gradCAM(net5, modelInput, gradeIdx, 'FeatureLayer', 'res5b_relu');
    hm = mat2gray(cmap);
    overlay = imfuse(repmat(imresize(hm, [224 224]), 1, 1, 3), ...
        im2double(modelInput), 'blend', 'Scaling', 'joint');

    result = struct();
    result.qualityStatus = qualityStatus;
    result.qualityScore = qualityScore;
    result.binaryProbability = pRef;
    result.binaryDecision = binaryDecision;
    result.binaryThreshold = thr;
    result.grade = gradeIdx - 1;  % 0-4 scale
    result.gradeLabel = gradeLabels{gradeIdx};
    result.classProbabilities = s5;
    result.confidence = conf;
    result.gradCAM = overlay;
    result.binaryProbabilityCalibrated = pCalibrated;
    result.calibrationTemperature = T;

    % 8. Lesion evidence (classical MA/HE/EX candidates + optic disc)
    result.lesions = struct();
    result.lesions.odLocated = false;
    result.lesions.od = [];
    result.lesions.exudateCentroidX = [];
    result.lesions.exudateCentroidY = [];
    if p.Results.RunLesions
        try
            odCnn = locateOpticDiscCnn(raw);
            od = odCnn;
            if isempty(od)
                od = estimateOpticDisc(raw);   % fallback to classical detector
            end
            loos = struct();
            if ~isempty(od)
                loos.odCenter = od(1:2);
                loos.odRadius = od(3);
                loos.fovea = [];
            else
                loos.odCenter = [];
                loos.odRadius = 0;
                loos.fovea = [];
            end
            feat = extractLesionCandidates(imagePath, loos);
            result.lesions.odLocated = ~isempty(od);
            result.lesions.od = od;
            result.lesions.odCnnOnly = ~isempty(odCnn);  % Branch B feature 8 = CNN-only locate
            result.lesions.odCnn = odCnn;
            result.lesions.maCount = feat.microaneurysms.count;
            result.lesions.heCount = feat.haemorrhages.count;
            result.lesions.exCount = feat.exudates.count;
            result.lesions.quadrantHemorrhage = feat.quadrantHemorrhage;
            result.lesions.exudateCentroidX = feat.exudates.centroidX;
            result.lesions.exudateCentroidY = feat.exudates.centroidY;
            result.lesions.meanExudateDistToFovea = feat.meanExudateDistToFovea;
            result.lesions.minExudateDistToFovea = feat.minExudateDistToFovea;
            result.lesions.overlay = feat.visual;
        catch me
            result.lesions.odLocated = false;
            result.lesions.od = [];
            result.lesions.odCnnOnly = false;
            result.lesions.odCnn = [];
            result.lesions.exudateCentroidX = [];
            result.lesions.exudateCentroidY = [];
            result.lesions.error = me.message;
        end
    end

    % 9. OOD detection + cascade routing (unsafe/uncertain -> human review)
    result.ood = struct('flag', false, 'mahalanobis', NaN, 'available', false);
    result.cascade = struct('route', 'CLEAR', 'available', false);
    if p.Results.RunLesions   % both are lightweight; reuse the same flag
        try
            [oodFlag, mDist, oodDet] = ood_detector(raw);
            result.ood.flag = oodFlag;
            result.ood.mahalanobis = mDist;
            result.ood.threshold = oodDet.threshold;
            result.ood.nearestClass = oodDet.nearestClass;
            result.ood.available = true;
        catch me
            result.ood.available = false;
            result.ood.error = me.message;
        end
        try
            [route, casDet] = cascade_router(result.grade, s5, pRef);
            result.cascade.route = route;
            result.cascade.detail = casDet;
            result.cascade.available = true;
        catch me
            result.cascade.available = false;
            result.cascade.error = me.message;
        end
    end

    % 9b. Dual-evidence: Branch B (lesion features) + evidence agreement
    result.fusion = struct('branchB', NaN, 'agree', false, 'discrepancy', false, ...
                           'routeOverride', '', 'available', false, ...
                           'reason', 'Branch B not run');
    if p.Results.RunBranchB && p.Results.RunLesions
        try
            modelFile = fullfile(projectRoot, 'data', 'analysis', 'day8', ...
                                 'branch_b', 'branchB_model.mat');
            if exist(modelFile, 'file') && isfield(result.lesions, 'maCount')
                SBB = load(modelFile);  % .model
                featRow = zeros(1, 10);
                featRow(1) = result.lesions.maCount;
                featRow(2) = result.lesions.heCount;
                featRow(3) = result.lesions.exCount;
                q = result.lesions.quadrantHemorrhage;
                if numel(q) >= 4, featRow(4:7) = q(1:4); end
                featRow(8) = double(result.lesions.odCnnOnly);
                exx = result.lesions.exudateCentroidX;
                exy = result.lesions.exudateCentroidY;
                if result.lesions.odCnnOnly && ~isempty(exx)
                    odc = result.lesions.odCnn;
                    odr = result.lesions.odCnn(3);
                    thr = 1.5 * max(odr, 50);
                    d = sqrt(sum(([exx; exy] - [odc(1); odc(2)]).^2, 1));
                    featRow(9) = double(sum(d <= thr));
                    featRow(10) = mean(d);
                end
                pRefB = branch_b_predict(featRow, SBB.model);
                aInfo.grade = result.grade;
                aInfo.pRefCal = pCalibrated;
                aInfo.confident = conf >= 0.80;
                bInfo.pRefB = pRefB;
                bInfo.available = true;
                [ag, dis, det] = fuseEvidence(aInfo, bInfo);
                result.fusion.branchB = pRefB;
                result.fusion.agree = ag;
                result.fusion.discrepancy = dis;
                result.fusion.routeOverride = det.routeOverride;
                result.fusion.available = true;
                result.fusion.reason = det.reason;
                if strcmp(det.routeOverride, 'REVIEW') && result.cascade.available
                    result.cascade.detail = [result.cascade.detail ...
                        ' | Branch B conflict -> manual review recommended'];
                end
            else
                result.fusion.reason = 'Branch B model unavailable';
            end
        catch me
            result.fusion.available = false;
            result.fusion.reason = ['Branch B error: ' me.message];
        end
    end

    % 10. Explanation narrative (evidence-based paragraph)
    result.explanation = buildExplanationNarrative(result);

    % 11. Display figure (2-row polished layout)
    if p.Results.ShowFigure
        fig = figure('Name', 'DrishtiCare Single-Image Inference', ...
            'Color', 'w', 'Position', [80 60 1680 880]);

        subplot(2, 3, 1); imshow(raw); title('Original fundus', 'FontWeight', 'bold');
        subplot(2, 3, 2); imshow(enhanced); title('Enhanced / model input', 'FontWeight', 'bold');
        subplot(2, 3, 3); imshow(overlay); title(['Grad-CAM (pred. class ', num2str(gradeIdx-1), ')'], 'FontWeight', 'bold');
        if p.Results.RunLesions
            subplot(2, 3, 4); hold on;
            if isfield(result.lesions, 'overlay') && ~isempty(result.lesions.overlay)
                ov = result.lesions.overlay.overlay;
                imagesc(ov); axis image off; title('Lesion evidence', 'FontWeight', 'bold');
                ma = result.lesions.overlay.maMask; he = result.lesions.overlay.heMask;
                ex = result.lesions.overlay.exMask;
                [ey, exx] = find(ex); if ~isempty(ey), plot(exx, ey, 'y.', 'MarkerSize', 1); end
                [my, mx] = find(ma);  if ~isempty(my), plot(mx, my, 'r.', 'MarkerSize', 3); end
                [hy, hx] = find(he);  if ~isempty(hy), plot(hx, hy, 'c.', 'MarkerSize', 3); end
                if result.lesions.odLocated && numel(result.lesions.od) == 3
                    scl = size(ov,1) / size(raw,1);
                    viscircles(result.lesions.od(1:2)*scl, result.lesions.od(3)*scl, ...
                        'Color', 'g', 'LineWidth', 1);
                end
            else
                axis off; title('Lesion evidence (unavailable)', 'FontWeight', 'bold');
            end
        else
            subplot(2, 3, 4); axis off;
        end

        % ---- bottom-left: decision metrics panel ----
        subplot(2, 3, 5); axis off; box on; set(gca, 'XLim',[0 1], 'YLim',[0 1]);
        lines = {
            sprintf('Quality: %s (score %.2f)', qualityStatus, qualityScore)
            sprintf('Referable prob: %.1f%%   ->  %s', pRef*100, binaryDecision)
            sprintf('Severity: grade %d  %s', gradeIdx-1, gradeLabels{gradeIdx})
            sprintf('Confidence: %.1f%%', conf*100)
            ''
            'Class probabilities:'
        };
        if abs(pCalibrated - pRef) > 0.01
            lines = [lines; {sprintf('Calib. P(referable): %.1f%% (T=%.2f)', pCalibrated*100, T)}];
        elseif T ~= 1.0
            lines = [lines; {sprintf('Calibration: T=%.2f applied (delta < 1 pp)', T)}];
        end
        if p.Results.RunLesions
            lines = [lines; {sprintf('Lesions  MA=%d HE=%d EX=%d', ...
                result.lesions.maCount, result.lesions.heCount, result.lesions.exCount)}];
            if result.lesions.odLocated
                lines = [lines; {sprintf('Optic disc: located (r=%.0f px)', result.lesions.od(3))}];
            else
                lines = [lines; {'Optic disc: NOT located (EX near disc may include it)'}];
            end
        end
        if result.ood.available
            if result.ood.flag
                lines = [lines; {sprintf('OOD: OUT-OF-DISTRIBUTION (Mah=%.1f)', result.ood.mahalanobis)}];
            else
                lines = [lines; {sprintf('OOD: in-dist (Mah=%.1f)', result.ood.mahalanobis)}];
            end
        end
        if result.cascade.available
            lines = [lines; {sprintf('Cascade: %s', result.cascade.route)}];
        end
        if isfield(result, 'fusion')
            if result.fusion.available
                if result.fusion.discrepancy
                    lines = [lines; {sprintf('Branch B: P(ref)=%.1f%%  DISCREPANCY', result.fusion.branchB*100)}];
                elseif result.fusion.agree
                    lines = [lines; {sprintf('Branch B: P(ref)=%.1f%%  agree (fusion)', result.fusion.branchB*100)}];
                else
                    lines = [lines; {sprintf('Branch B: P(ref)=%.1f%%  (no conflict)', result.fusion.branchB*100)}];
                end
            else
                lines = [lines; {'Branch B: unavailable'}];
            end
        end
        text(0.05, 0.97, lines, 'FontSize', 11, 'VerticalAlignment', 'top', ...
            'BackgroundColor','none', 'FontName','Consolas');
        hold all;
        h5 = text(0.07, 0.02, sprintf('NoDR %.0f%%  Mild %.0f%%  Mod %.0f%%  Sev %.0f%%  Prol %.0f%%', ...
            s5(1)*100, s5(2)*100, s5(3)*100, s5(4)*100, s5(5)*100), ...
            'FontSize', 9, 'FontName','Consolas');
        h6 = text(0.05, 0.12, sprintf('thr=%.2f (locked)', thr), 'FontSize', 9, 'Color', [0.4 0.4 0.4]);

        % ---- bottom-right: explanation narrative panel ----
        subplot(2, 3, 6); axis off;
        title('Explanation');
        narrLines = [{'EXPLANATION (engineering demo — not clinical advice):'; ''}; ...
                     wrapText(result.explanation.paragraph, 110); ...
                     {''; 'Evidence basis:'; ''}; ...
                     wrapText(result.explanation.caveats, 110)];
        text(0.03, 0.99, narrLines, 'FontSize', 9.5, 'VerticalAlignment', 'top', ...
            'FontName', 'Consolas', 'Units', 'normalized');

        result.figure = fig;
    end
end

function out = wrapText(s, width)
%WRAPTEXT Wrap char/string s into lines of at most `width` chars, splitting
%on spaces to preserve words (utility for the explanation panel).
    if isstring(s), s = char(s); else, s = char(s); end
    words = strsplit(strtrim(s), ' ');
    out = {};
    cur = '';
    for k = 1:numel(words)
        w = words{k};
        if isempty(cur)
            cur = w;
        elseif numel(cur) + 1 + numel(w) <= width
            cur = [cur ' ' w];
        else
            out{end+1} = cur; %#ok<AGROW>
            cur = w;
        end
    end
    if ~isempty(cur), out{end+1} = cur; end
    out = out(:);
end
