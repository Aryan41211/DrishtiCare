function plotTrainingResults(info, metrics, varargin)
% PLOTTRAININGRESULTS Generate training and evaluation visualizations
%   plotTrainingResults(info, metrics)
%   plotTrainingResults(info, metrics, 'Config', config, 'Stage', 1)
%
%   Inputs:
%       info    - Training information from trainNetwork
%       metrics - Evaluation metrics from evaluateClassifier
%
%   Optional Parameters:
%       'Config' - Training config struct (default: defaultTrainingConfig())
%       'Stage'  - Training stage (default: 1)
%
%   Generates:
%       - Training curves (loss, accuracy)
%       - Confusion matrix heatmap
%       - Per-class F1 bar chart
%       - Class distribution comparison

    %% Parse arguments
    p = inputParser;
    addParameter(p, 'Config', [], @(x) isstruct(x));
    addParameter(p, 'Stage', 1, @(x) ismember(x, [1, 2]));
    parse(p, varargin{:});
    config = p.Results.Config;
    stage = p.Results.Stage;

    if isempty(config)
        config = defaultTrainingConfig();
    end

    classNames = config.classes.names;
    analysisDir = config.dataset.analysisDir;

    if ~exist(analysisDir, 'dir')
        mkdir(analysisDir);
    end

    %% Figure 1: Training curves
    fprintf('Generating training curves...\n');
    fig1 = figure('Visible', 'off', 'Position', [100 100 1200 400]);

    % Loss
    subplot(1, 3, 1);
    plot(info.TrainingLoss, 'b-', 'LineWidth', 1.5);
    hold on;
    plot(info.ValidationLoss, 'r-', 'LineWidth', 1.5);
    xlabel('Epoch');
    ylabel('Loss');
    title('Training & Validation Loss');
    legend('Train', 'Validation', 'Location', 'best');
    grid on;

    % Accuracy
    subplot(1, 3, 2);
    plot(info.TrainingAccuracy, 'b-', 'LineWidth', 1.5);
    hold on;
    plot(info.ValidationAccuracy, 'r-', 'LineWidth', 1.5);
    xlabel('Epoch');
    ylabel('Accuracy (%)');
    title('Training & Validation Accuracy');
    legend('Train', 'Validation', 'Location', 'best');
    grid on;

    % Learning rate
    subplot(1, 3, 3);
    if isfield(info, 'LearnRate')
        plot(info.LearnRate, 'g-', 'LineWidth', 1.5);
    else
        text(0.5, 0.5, 'LR schedule not logged', 'HorizontalAlignment', 'center');
    end
    xlabel('Epoch');
    ylabel('Learning Rate');
    title('Learning Rate Schedule');
    grid on;

    stageStr = sprintf('_stage%d', stage);
    saveas(fig1, fullfile(analysisDir, [config.experimentId stageStr '_training_curves.png']));
    fprintf('  Saved: %s\n', fullfile(analysisDir, [config.experimentId stageStr '_training_curves.png']));

    %% Figure 2: Confusion matrix
    fprintf('Generating confusion matrix...\n');
    fig2 = figure('Visible', 'off', 'Position', [100 100 600 500]);

    confMat = metrics.confusionMatrix;
    confMatNorm = confMat ./ sum(confMat, 2); % Normalize by row

    imagesc(confMatNorm);
    colorbar;
    colormap('parula');
    set(gca, 'XTick', 1:length(classNames), 'XTickLabel', classNames, ...
        'YTick', 1:length(classNames), 'YTickLabel', classNames);
    xlabel('Predicted');
    ylabel('True');
    title('Confusion Matrix (Normalized)');

    % Add text annotations
    for i = 1:size(confMat, 1)
        for j = 1:size(confMat, 2)
            text(j, i, sprintf('%.2f\n(%d)', confMatNorm(i,j), confMat(i,j)), ...
                'HorizontalAlignment', 'center', 'FontSize', 8);
        end
    end

    saveas(fig2, fullfile(analysisDir, [config.experimentId stageStr '_confusion_matrix.png']));
    fprintf('  Saved: %s\n', fullfile(analysisDir, [config.experimentId stageStr '_confusion_matrix.png']));

    %% Figure 3: Per-class F1
    fprintf('Generating per-class F1 chart...\n');
    fig3 = figure('Visible', 'off', 'Position', [100 100 600 400]);

    bar(metrics.f1, 'FaceColor', [0.3 0.6 0.9]);
    set(gca, 'XTick', 1:length(classNames), 'XTickLabel', classNames);
    ylabel('F1 Score');
    title(sprintf('Per-Class F1 Score (Macro F1: %.4f)', metrics.macroF1));
    ylim([0 1]);
    grid on;

    % Add value labels
    for i = 1:length(metrics.f1)
        text(i, metrics.f1(i) + 0.02, sprintf('%.3f', metrics.f1(i)), ...
            'HorizontalAlignment', 'center', 'FontSize', 9);
    end

    saveas(fig3, fullfile(analysisDir, [config.experimentId stageStr '_per_class_f1.png']));
    fprintf('  Saved: %s\n', fullfile(analysisDir, [config.experimentId stageStr '_per_class_f1.png']));

    %% Figure 4: Class distribution
    fprintf('Generating class distribution chart...\n');
    fig4 = figure('Visible', 'off', 'Position', [100 100 600 400]);

    bar(metrics.support, 'FaceColor', [0.9 0.5 0.3]);
    set(gca, 'XTick', 1:length(classNames), 'XTickLabel', classNames);
    ylabel('Samples');
    title('Validation Set Class Distribution');
    grid on;

    % Add value labels
    for i = 1:length(metrics.support)
        text(i, metrics.support(i) + 5, sprintf('%d', metrics.support(i)), ...
            'HorizontalAlignment', 'center', 'FontSize', 9);
    end

    saveas(fig4, fullfile(analysisDir, [config.experimentId stageStr '_class_distribution.png']));
    fprintf('  Saved: %s\n', fullfile(analysisDir, [config.experimentId stageStr '_class_distribution.png']));

    %% Close figures
    close all;

    fprintf('All visualizations saved to: %s\n', analysisDir);
end