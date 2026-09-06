function demoSingleImage(imagePath)
% DEMOSINGLEIMAGE Clean demo figure for one fundus image
%   demoSingleImage("C:\path\to\fundus.jpg")
%
%   See docs/individual-image-inference.md for instructions.

    if nargin < 1 || isempty(imagePath)
        error('Usage: demoSingleImage("C:\\path\\to\\fundus.jpg")');
    end
    assert(exist(imagePath, 'file') == 2, 'Image not found: %s', imagePath);

    projectRoot = pwd;
    addpath(fullfile(projectRoot, 'src', 'setup'));
    addpath(fullfile(projectRoot, 'src', 'quality'));
    addpath(fullfile(projectRoot, 'src', 'enhancement'));
    addpath(fullfile(projectRoot, 'src', 'grading'));
    addpath(fullfile(projectRoot, 'src', 'inference'));
    addpath(fullfile(projectRoot, 'src', 'lesions'));

    result = predictSingleFundus(imagePath);

    fprintf('\n=== DrishtiCare Inference ===\n');
    fprintf('Image: %s\n', imagePath);
    fprintf('Quality: %s (%.3f)\n', result.qualityStatus, result.qualityScore);
    fprintf('Referable probability: %.1f%% -> %s (thr %.2f)\n', ...
        result.binaryProbability*100, result.binaryDecision, result.binaryThreshold);
    fprintf('Grade: %d (%s), confidence %.1f%%\n', ...
        result.grade, result.gradeLabel, result.confidence*100);
    fprintf('Probabilities sum: %.4f\n', sum(result.classProbabilities));
    if isfield(result, 'lesions') && isfield(result.lesions, 'maCount')
        odTxt = 'OD not located (exudates may include OD)';
        if result.lesions.odLocated, odTxt = sprintf('OD at [%.0f %.0f] r=%.0f', ...
                result.lesions.od(1), result.lesions.od(2), result.lesions.od(3)); end
        fprintf('Lesions: MA=%d HE=%d EX=%d  quadHE=[%s]  %s\n', ...
            result.lesions.maCount, result.lesions.heCount, result.lesions.exCount, ...
            num2str(result.lesions.quadrantHemorrhage), odTxt);
    end
end
