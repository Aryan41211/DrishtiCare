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

    result = predictSingleFundus(imagePath);

    fprintf('\n=== DrishtiCare Inference ===\n');
    fprintf('Image: %s\n', imagePath);
    fprintf('Quality: %s (%.3f)\n', result.qualityStatus, result.qualityScore);
    fprintf('Referable probability: %.1f%% -> %s (thr %.2f)\n', ...
        result.binaryProbability*100, result.binaryDecision, result.binaryThreshold);
    fprintf('Grade: %d (%s), confidence %.1f%%\n', ...
        result.grade, result.gradeLabel, result.confidence*100);
    fprintf('Probabilities sum: %.4f\n', sum(result.classProbabilities));
end
