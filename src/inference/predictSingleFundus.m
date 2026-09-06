function result = predictSingleFundus(imagePath, varargin)
% PREDICTSINGLEFUNDUS Full DrishtiCare inference on one fundus image
%   result = predictSingleFundus(imagePath)
%
%   Pipeline (EXACT same preprocessing as training):
%     raw -> imresize 224 -> quality gate -> binary screening (pretrained)
%     -> 5-class grading (pretrained) -> Grad-CAM
%
%   Returns struct: qualityStatus, qualityScore, binaryProbability,
%   binaryDecision, binaryThreshold, grade, gradeLabel, classProbabilities,
%   confidence, gradCAM.
%
%   ENGINEERING demo tool. NOT a clinical device.

    p = inputParser;
    addParameter(p, 'BinaryModel', '', @ischar);
    addParameter(p, 'GradeModel', '', @ischar);
    addParameter(p, 'BinaryThreshold', 0.60, @isnumeric);
    addParameter(p, 'ShowFigure', true, @islogical);
    parse(p, varargin{:});

    projectRoot = pwd;
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

    % 10. Display figure
    if p.Results.ShowFigure
        fig = figure('Name', 'DrishtiCare Single-Image Inference', ...
            'Position', [100 100 1100 420]);
        subplot(1, 4, 1); imshow(raw); title('Original fundus');
        subplot(1, 4, 2); imshow(enhanced); title('Enhanced / model input');
        subplot(1, 4, 3); imshow(overlay); title('Grad-CAM');
        subplot(1, 4, 4); axis off;
        text(0.05, 0.95, sprintf('Quality: %s (%.2f)', qualityStatus, qualityScore), 'FontSize', 11);
        text(0.05, 0.82, sprintf('Referable prob: %.1f%%', pRef*100), 'FontSize', 12, 'FontWeight', 'bold');
        text(0.05, 0.72, sprintf('Screening: %s (thr %.2f)', binaryDecision, thr), 'FontSize', 11);
        text(0.05, 0.58, sprintf('Grade: %d — %s', gradeIdx-1, gradeLabels{gradeIdx}), 'FontSize', 12, 'FontWeight', 'bold');
        text(0.05, 0.48, sprintf('Confidence: %.1f%%', conf*100), 'FontSize', 11);
        text(0.05, 0.34, '5-class probs:', 'FontSize', 10);
        for i = 1:5
            text(0.05, 0.28-(i-1)*0.06, sprintf('  %d %s: %.1f%%', ...
                i-1, gradeLabels{i}, s5(i)*100), 'FontSize', 10);
        end
        result.figure = fig;
    end
end
