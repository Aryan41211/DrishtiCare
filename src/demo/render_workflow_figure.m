function render_workflow_figure(outPath)
% RENDER_WORKFLOW_FIGURE Conceptual failure-aware screening pipeline.
%   Shows the hard quality gate: PASS/WARNING continues to the AI stage,
%   FAIL stops the pipeline and routes to recapture / manual review.

    fig = figure('Visible', 'off', 'Color', 'w', 'Position', [40 40 1500 760]);
    ax = axes(fig, 'Position', [0 0 1 1], 'XLim', [0 1], 'YLim', [0 1]);
    axis(ax, 'off'); hold(ax, 'on');

    blue  = [0.85 0.91 0.98];
    orange = [1.00 0.90 0.72];
    red   = [0.99 0.85 0.85];
    green = [0.86 0.95 0.86];

    y = 0.60; h = 0.15; w = 0.115;
    xs = [0.015 0.155 0.295 0.435 0.575 0.715 0.855];
    labels = {
        sprintf('Fundus\nimage\ncapture')
        sprintf('QUALITY\nGATE\n(Day-3)')
        sprintf('AI screening\n(binary\nreferable)')
        sprintf('DR grading\n5-class\n(0-4)')
        sprintf('Model evidence\nGrad-CAM\n(visual)')
        sprintf('Referral\ndecision\n(thr=0.60)')
        sprintf('Specialist\nreview\n(queue)')};
    fills = {blue, orange, blue, blue, blue, blue, green};

    for i = 1:numel(xs)
        drawBox(xs(i), y, w, h, labels{i}, fills{i});
    end

    for i = 1:numel(xs)-1
        drawArrow(xs(i) + w, y + h/2, xs(i+1), y + h/2);
    end
    text(ax, (xs(2)+w + xs(3))/2, y + h/2 + 0.028, 'PASS / WARNING', ...
        'HorizontalAlignment', 'center', 'FontSize', 9, 'Color', [0 0.4 0]);
    text(ax, (xs(2)+w + xs(3))/2, y + h/2 - 0.045, 'continue to AI', ...
        'HorizontalAlignment', 'center', 'FontSize', 8, 'Color', [0.3 0.3 0.3]);

    gx = xs(2) + w/2;
    drawArrow(gx, y, gx, 0.40);
    text(ax, gx + 0.012, 0.485, 'FAIL', 'FontSize', 12, 'FontWeight', 'bold', ...
        'Color', [0.75 0 0]);
    drawBox(0.045, 0.22, 0.42, 0.16, ...
        sprintf('STOP - AI GRADING SKIPPED\nRecapture image  /  MANUAL REVIEW\n(explicit reason + metric + threshold)'), red);

    text(ax, 0.5, 0.905, 'Failure-aware DR screening pipeline', ...
        'HorizontalAlignment', 'center', 'FontSize', 16, 'FontWeight', 'bold');
    text(ax, 0.5, 0.855, 'A quality FAIL is a hard gate: the AI stage is never executed for that image.', ...
        'HorizontalAlignment', 'center', 'FontSize', 11, 'Color', [0.3 0.3 0.3]);
    text(ax, 0.5, 0.11, ['Referral volume and specialist queue workload are modelled separately ' ...
        'in the Simulink resource simulation (data/analysis/simulink_resource_simulation).'], ...
        'HorizontalAlignment', 'center', 'FontSize', 9, 'Color', [0.4 0.4 0.4]);
    text(ax, 0.5, 0.06, 'ENGINEERING DEMO - NOT a clinical device. Thresholds are prototypes, not clinically validated.', ...
        'HorizontalAlignment', 'center', 'FontSize', 9, 'FontAngle', 'italic', 'Color', [0.5 0.2 0.2]);

    hold(ax, 'off');
    exportgraphics(fig, outPath, 'Resolution', 150);
    close(fig);

    function drawBox(x, y, w, h, txt, face)
        rectangle(ax, 'Position', [x y w h], 'Curvature', 0.18, ...
            'FaceColor', face, 'EdgeColor', [0.25 0.25 0.25], 'LineWidth', 1.3);
        text(ax, x + w/2, y + h/2, txt, 'HorizontalAlignment', 'center', ...
            'VerticalAlignment', 'middle', 'FontSize', 8.8, 'FontWeight', 'bold', ...
            'Color', [0.1 0.1 0.1]);
    end

    function drawArrow(x1, y1, x2, y2)
        annotation(fig, 'arrow', [x1 x2], [y1 y2], 'LineWidth', 1.4, 'Color', [0.2 0.2 0.2]);
    end
end
