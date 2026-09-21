function render_comparison_figure(R, outPath)
% RENDER_COMPARISON_FIGURE Build the failure-aware left/right demo visual.
%   Two real held-out images: GOOD quality (full AI flow) vs POOR quality
%   (AI grading skipped with an explicit reason / metric / threshold).

    goodIdx = find(strcmp({R.role}, 'pass_referable'), 1);
    if isempty(goodIdx), goodIdx = find(strcmp({R.quality_status}, 'PASS'), 1); end
    poorIdx = find(strcmp({R.role}, 'fail_blur'), 1);
    if isempty(poorIdx), poorIdx = find(strcmp({R.quality_status}, 'FAIL'), 1); end

    projectRoot = fileparts(fileparts(fileparts(mfilename('fullpath'))));
    valDir = fullfile(projectRoot, 'data', 'splits', 'val');

    fig = figure('Visible', 'off', 'Color', 'w', 'Position', [40 40 1500 900]);
    tl = tiledlayout(fig, 2, 3, 'TileSpacing', 'compact', 'Padding', 'compact');
    title(tl, 'DrishtiCare failure-aware screening: a quality FAIL never reaches the AI stage', ...
        'FontWeight', 'bold', 'FontSize', 14);

    % ---- GOOD flow ----
    if ~isempty(goodIdx)
        g = R(goodIdx);
        ax = nexttile(tl); imshow(imread(fullfile(valDir, g.image_relpath)));
        title(ax, sprintf('GOOD input  (real held-out)  -  QUALITY: %s', g.quality_status), ...
            'Color', [0 0.45 0], 'FontWeight', 'bold');
        ax = nexttile(tl);
        if g.gradcam_available && ~isempty(g.gradcam_overlay)
            imshow(g.gradcam_overlay);
            title(ax, 'Model visual evidence (Grad-CAM)', 'FontWeight', 'bold');
        else
            axis(ax, 'off'); text(ax, 0.5, 0.5, 'Grad-CAM unavailable', ...
                'HorizontalAlignment', 'center');
        end
        ax = nexttile(tl); axis(ax, 'off'); set(ax, 'XLim', [0 1], 'YLim', [0 1]);
        lines = {
            sprintf('QUALITY: %s (score %.2f)', g.quality_status, g.quality_score)
            'AI SCREENING: executed'
            sprintf('Referable probability: %.1f%%', g.referable_probability * 100)
            sprintf('AI decision: %s', g.binary_decision)
            sprintf('DR grade: %d  (%s)', g.grade, g.grade_label)
            sprintf('Confidence: %.1f%%', g.confidence * 100)
            sprintf('Cascade route: %s', g.cascade_route)
            sprintf('Evidence: Grad-CAM generated: %d', g.gradcam_available)
            ''
            'NOTE: Grad-CAM is MODEL VISUAL EVIDENCE,'
            'not a clinical explanation.'};
        text(ax, 0.02, 0.98, lines, 'VerticalAlignment', 'top', ...
            'FontName', 'Consolas', 'FontSize', 10.5, 'Color', [0.1 0.1 0.1]);
    end

    % ---- POOR flow ----
    if ~isempty(poorIdx)
        b = R(poorIdx);
        ax = nexttile(tl); imshow(imread(fullfile(valDir, b.image_relpath)));
        title(ax, sprintf('POOR input  (real held-out)  -  QUALITY: %s', b.quality_status), ...
            'Color', [0.7 0 0], 'FontWeight', 'bold');
        ax = nexttile(tl); axis(ax, 'off'); set(ax, 'XLim', [0 1], 'YLim', [0 1]);
        rectangle(ax, 'Position', [0.02 0.15 0.96 0.7], 'Curvature', 0.08, ...
            'FaceColor', [1 0.92 0.92], 'EdgeColor', [0.7 0 0], 'LineWidth', 2);
        text(ax, 0.5, 0.62, 'AI GRADING: SKIPPED', 'HorizontalAlignment', 'center', ...
            'FontName', 'Consolas', 'FontSize', 17, 'FontWeight', 'bold', 'Color', [0.7 0 0]);
        text(ax, 0.5, 0.38, {'No model was run.', 'Routed to recapture / manual review.'}, ...
            'HorizontalAlignment', 'center', 'FontSize', 11, 'Color', [0.35 0 0]);
        ax = nexttile(tl); axis(ax, 'off'); set(ax, 'XLim', [0 1], 'YLim', [0 1]);
        if isfield(b, 'primary_message') && ~isempty(b.primary_message)
            reasonTxt = b.primary_message;
        else
            reasonTxt = b.quality_reason;
        end
        lines = {
            'QUALITY: FAIL'
            sprintf('Reason: %s', reasonTxt)
            sprintf('Metric: %s = %.4g', b.primary_metric, b.primary_value)
            sprintf('Threshold: %s = %.4g', b.primary_bound, b.primary_threshold)
            'AI GRADING: SKIPPED'
            'Action: RECAPTURE IMAGE / MANUAL REVIEW'
            ''
            'No DR grade, class probabilities or'
            'confidence were produced for this image.'};
        text(ax, 0.02, 0.98, lines, 'VerticalAlignment', 'top', ...
            'FontName', 'Consolas', 'FontSize', 10.5, 'Color', [0.1 0.1 0.1]);
    end

    exportgraphics(fig, outPath, 'Resolution', 150);
    close(fig);
end
