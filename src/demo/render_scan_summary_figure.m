function render_scan_summary_figure(Tscan, ss, outPath)
% RENDER_SCAN_SUMMARY_FIGURE Held-out split quality split + FAIL categories.

    fig = figure('Visible', 'off', 'Color', 'w', 'Position', [40 40 1400 560]);
    t = tiledlayout(fig, 1, 2, 'TileSpacing', 'compact', 'Padding', 'compact');
    title(t, sprintf('Quality gate on the held-out validation split (%d real images)', ss.total), ...
        'FontWeight', 'bold', 'FontSize', 14);

    ax1 = nexttile(t);
    vals = [ss.nPass, ss.nWarn, ss.nFail];
    b = bar(ax1, vals, 0.6, 'FaceColor', 'flat');
    b.CData = [0.35 0.72 0.40; 0.98 0.75 0.25; 0.85 0.28 0.28];
    set(ax1, 'XTickLabel', {'PASS', 'WARNING', 'FAIL'});
    ylabel(ax1, 'images');
    title(ax1, 'Overall quality decision');
    for i = 1:3
        text(ax1, i, vals(i) + max(vals)*0.02, sprintf('%d\n(%.1f%%)', vals(i), ...
            100*vals(i)/ss.total), 'HorizontalAlignment', 'center', 'FontSize', 10);
    end
    ylim(ax1, [0 max(vals)*1.2]);
    grid(ax1, 'on');

    ax2 = nexttile(t);
    if ~isempty(ss.categories)
        cats = ss.categories;
        n = size(cats, 1);
        cvals = zeros(1, n); names = cell(1, n);
        for i = 1:n
            cvals(i) = cats{i,2};
            names{i} = cats{i,1};
        end
        b2 = barh(ax2, cvals, 0.6);
        b2.FaceColor = [0.85 0.45 0.30];
        set(ax2, 'YTickLabel', names);
        xlabel(ax2, 'FAIL cases');
        title(ax2, 'Reasons for quality FAIL (count of failed checks)');
        for i = 1:n
            text(ax2, cvals(i) + max(cvals)*0.02, i, num2str(cvals(i)), ...
                'VerticalAlignment', 'middle', 'FontSize', 10);
        end
        xlim(ax2, [0 max(cvals)*1.2]);
        grid(ax2, 'on');
    else
        axis(ax2, 'off');
        text(ax2, 0.5, 0.5, 'No FAIL categories', 'HorizontalAlignment', 'center');
    end

    exportgraphics(fig, outPath, 'Resolution', 150);
    close(fig);
end
