classdef DRScreeningDashboard < matlab.apps.AppBase
%DRSCREENINGDASHBOARD Interactive screening-ops dashboard for DrishtiCare.
%   DRScreeningDashboard()
%
%   App Designer-style dashboard (matlab.apps.AppBase structure, convertible
%   to .mlapp in the App Designer editor) with five tabs fed by
%   load_dashboard_data.m (committed day3/day7/day8 artifacts):
%     1. Overview      - population screened, quality split, throughput
%     2. Performance   - T3 ablation (scratch vs pretrained), champion metrics
%     3. Quality Gate  - PASS/WARNING/FAIL split + failure-reason rates
%     4. Workload      - what-if manual-review workload calculator
%     5. Inspector     - run predictSingleFundus on a val image
%
%   ENGINEERING demo tool. NOT a clinical device. Threshold 0.60 is locked;
%   simulator sliders are labeled what-if ONLY.

    properties (Access = public)
        UIFigure  matlab.ui.Figure
    end

    properties (Access = private)
        Data         % struct from load_dashboard_data()
        ProjectRoot  % repo root (mfilename-anchored)
        WorkloadSld
        WorkloadOut
        InspectorDrop
        InspectorList
        InspectorOut
    end

    methods (Access = public)

        function app = DRScreeningDashboard()
            appRoot = fileparts(fileparts(fileparts(mfilename('fullpath'))));
            addpath(genpath(appRoot));
            app.Data = load_dashboard_data();
            app.ProjectRoot = appRoot;
            app.createComponents();
            registerApp(app, app.UIFigure);
        end

        function delete(app)
            if isvalid(app.UIFigure)
                delete(app.UIFigure);
            end
        end

    end

    methods (Access = private)

        function createComponents(app)
            app.UIFigure = uifigure('Name', 'DrishtiCare Screening Dashboard', ...
                'Position', [90 80 1280 760]);

            tg = uitabgroup(app.UIFigure, 'Position', [10 10 1260 740]);
            app.OverviewTab(tg);
            app.PerformanceTab(tg);
            app.QualityTab(tg);
            app.WorkloadTab(tg);
            app.InspectorTab(tg);
        end

        %% ---------------- Tab 1: Overview ----------------
        function OverviewTab(app, tg)
            t = uitab(tg, 'Title', ' Overview ');
            grid = uigridlayout(t, [4 1], 'RowHeight', {180, 200, 150, 30});
            grid.Padding = [12 12 12 12]; grid.RowSpacing = 10;
            D = app.Data;

            p1 = uipanel(grid, 'Title', sprintf('Screened population (APTOS train, n=%d)', D.quality.n), 'FontWeight', 'bold');
            c1 = uilabel(p1, 'Text', sprintf(['Referable rate (train): %.1f%%\n' ...
                'Referable rate (val): %.1f%%\n' ...
                'Class mix: NoDR %d | Mild %d | Moderate %d | Severe %d | Prolif %d\n' ...
                'Binary threshold: 0.60 (LOCKED)'], ...
                D.referable.trainFrac * 100, D.referable.valFrac * 100, ...
                D.quality.classCounts), 'FontName', 'Consolas', 'FontSize', 12, ...
                'Position', [12 12 560 150]);

            p2 = uipanel(grid, 'Title', 'Quality gate split', 'FontWeight', 'bold');
            ax = uiaxes(p2, 'Position', [12 10 420 155]); cla(ax); hold(ax, 'on');
            pie(ax, [D.quality.pass, D.quality.warning, D.quality.fail], ...
                {'PASS', 'WARNING', 'FAIL'});
            colormap(ax, [0.35 0.7 0.35; 0.95 0.8 0.35; 0.85 0.32 0.32]);
            title(ax, 'Quality gate (PASS/WARNING/FAIL)');

            p3 = uipanel(grid, 'Title', 'Throughput estimate', 'FontWeight', 'bold');
            uilabel(p3, 'Text', sprintf(['Measured inference (day7 val, n=%d):\n' ...
                '  %.4f s/image  (%.1f images/s)\n' ...
                'Engine: CPU resnet18 @ 224x224 (no GPU)\n' ...
                'Estimated capacity at 75%% duty over an 8h day:\n' ...
                '  ~%.0f images / clinic day\n\n' ...
                'Single-thread engineering estimate, not a site-ops claim.'], ...
                D.quality.n, D.inference.secondsPerImg, D.inference.imgPerSec, ...
                D.inference.perDayEstimated), 'FontName', 'Consolas', ...
                'FontSize', 12, 'Position', [12 6 560 130]);

            uilabel(grid, 'Text', 'ENGINEERING DEMO — NOT a clinical device. Thresholds/probabilities are experimental.', ...
                'FontSize', 12, 'FontAngle', 'italic', 'HorizontalAlignment', 'center');
        end

        %% ---------------- Tab 2: Performance ----------------
        function PerformanceTab(app, tg)
            t = uitab(tg, 'Title', ' Performance ');
            grid = uigridlayout(t, [2 1], 'RowHeight', {340, 60});
            grid.Padding = [12 12 12 12]; grid.RowSpacing = 10;
            D = app.Data;
            c = D.champion;

            p1 = uipanel(grid, 'Title', 'T3 ablation + champion detail (val n=733)', 'FontWeight', 'bold');
            tt = uitable(p1, 'Data', D.ablation, 'ColumnName', ...
                {'Config', 'Acc', 'macroF1', 'QWK', 'Sens(ref)', 'Spec(ref)', 'n'}, ...
                'ColumnWidth', {285, 55, 55, 55, 65, 65, 40}, ...
                'Position', [12 150 620 170]);
            rows = cell(5, 4);
            for i = 1:5
                rows(i, :) = {c.classNames{i}, c.support(i), c.recall(i), c.f1(i)};
            end
            perClass = cell2table(rows, 'VariableNames', {'class', 'support', 'recall', 'f1'});
            uitable(p1, 'Data', perClass, 'ColumnName', {'class', 'support', 'recall', 'F1'}, ...
                'ColumnWidth', {130, 65, 65, 65}, 'Position', [12 20 330 120]);
            txt = sprintf(['day7 pretrained (champion): Acc %.4f | MacroF1 %.4f | QWK %.4f\n' ...
                'Binary referable @ 0.60 (LOCKED): Sens %.4f  Spec %.4f  PPV %.4f  NPV %.4f\n' ...
                '  TP %d  FP %d  FN %d  TN %d'], ...
                c.accuracy, c.macroF1, c.qwk, c.binarySens, c.binarySpec, ...
                c.binaryPpv, c.binaryNpv, c.binaryTp, c.binaryFp, c.binaryFn, c.binaryTn);
            uilabel(p1, 'Text', txt, 'FontName', 'Consolas', 'FontSize', 11, ...
                'Position', [360 20 300 120]);

            if D.branchB.available
                txt3 = sprintf(['Branch B (lesion-feature dual evidence): kind %s | eval AUC %.3f | ' ...
                    'A/B match @0.60 = %.3f (n=%d)\n' ...
                    'Fusion flags A/B disagreements as REVIEW (never downgrades a referable).'], ...
                    D.branchB.kind, D.branchB.evalAUC, D.branchB.matchRate, D.branchB.nEval);
            else
                txt3 = 'Branch B artifacts not present.';
            end
            uilabel(p1, 'Text', txt3, 'FontSize', 11, 'Position', [12 6 1220 30]);

            uilabel(grid, 'Text', 'Ablation + calibration numbers reproduced from committed day7/day8 artifacts.', ...
                'FontSize', 11, 'FontAngle', 'italic');
        end

        %% ---------------- Tab 3: Quality Gate ----------------
        function QualityTab(app, tg)
            t = uitab(tg, 'Title', ' Quality Gate ');
            grid = uigridlayout(t, [2 2], 'RowHeight', {340, 60});
            grid.Padding = [12 12 12 12]; grid.RowSpacing = 10;
            D = app.Data;

            p1 = uipanel(grid, 'Title', 'Quality status by referral grade', 'FontWeight', 'bold');
            ax = uiaxes(p1, 'Position', [12 10 600 300]); cla(ax); hold(ax, 'on');
            byGrade = D.qualityByGrade;
            bar(ax, byGrade, 'stacked');
            xlabel(ax, 'Grade'); ylabel(ax, 'Images');
            xticks(ax, 1:5);
            xticklabels(ax, {'0-NoDR', '1-Mild', '2-Mod', '3-Sev', '4-Prolif'});
            legend(ax, {'PASS', 'WARNING', 'FAIL'}, 'Location', 'northwest');
            title(ax, 'Quality status by referral grade');

            p2 = uipanel(grid, 'Title', 'Top quality failure reasons', 'FontWeight', 'bold');
            ax2 = uiaxes(p2, 'Position', [12 10 600 300]); cla(ax2); hold(ax2, 'on');
            nShow = min(12, size(D.failureReasons, 1));
            counts = cell2mat(D.failureReasons(1:nShow, 2));
            labels = cell(nShow, 1);
            for i = 1:nShow
                labels{i} = sprintf('%s (%d)', app.shortReason(D.failureReasons{i, 1}), counts(i));
            end
            barh(ax2, counts(end:-1:1));
            set(ax2, 'YTick', 1:nShow, 'YTickLabel', labels(end:-1:1));
            xlabel(ax2, 'Images flagged'); title(ax2, 'Top quality failure reasons');

            txt = sprintf(['PASS %d (%.1f%%) | WARNING %d (%.1f%%) | FAIL %d (%.1f%%) of %d train images.\n' ...
                'FAIL -> forced recapture / manual review (Stage 5 quality-gate enforcement).\n' ...
                'WARNING -> caution flag only; may benefit from recapture.  Engineering thresholds, not clinical gradability.'], ...
                D.quality.pass, D.quality.passPct, D.quality.warning, D.quality.warningPct, ...
                D.quality.fail, D.quality.failPct, D.quality.n);
            uilabel(grid, 'Text', txt, 'FontSize', 11);
        end

        %% ---------------- Tab 4: Workload / Staffing ----------------
        function WorkloadTab(app, tg)
            t = uitab(tg, 'Title', ' Workload / Staffing ');
            grid = uigridlayout(t, [3 1], 'RowHeight', {90, 180, 30});
            grid.Padding = [12 12 12 12]; grid.RowSpacing = 10;
            D = app.Data;

            uilabel(grid, 'Text', sprintf(['WHAT-IF simulator (display only — screening threshold stays 0.60).\n' ...
                'Review load = referable (P(ref) >= 0.60) + FAIL-recapture + WARNING caution checks,\n' ...
                'using measured val referable rate %.1f%% and quality split PASS %.1f%% / WARNING %.1f%% / FAIL %.1f%%.'], ...
                D.referable.valFrac * 100, D.quality.passPct, D.quality.warningPct, D.quality.failPct), ...
                'FontSize', 12);

            pg = uipanel(grid, 'Title', 'Images per 8h clinic day (what-if)', 'FontWeight', 'bold');
            app.WorkloadSld = uislider(pg, 'Limits', [100 3000], 'Value', 500, ...
                'MajorTicks', [100 500 1000 2000 3000], ...
                'MajorTickLabels', {'100', '500', '1k', '2k', '3k'}, ...
                'Position', [40 150 700 30]);
            app.WorkloadSld.ValueChangedFcn = @(s, ~) app.updateWorkload(s.Value);
            app.WorkloadOut = uilabel(pg, 'Text', '', 'FontName', 'Consolas', ...
                'FontSize', 13, 'VerticalAlignment', 'top', 'Position', [40 8 700 130]);
            app.updateWorkload(app.WorkloadSld.Value);

            uilabel(grid, 'Text', 'All workload figures are engineering what-if estimates, not site commitments.', ...
                'FontSize', 11, 'FontAngle', 'italic');
        end

        function updateWorkload(app, imagesPerDay)
            D = app.Data;
            ref = D.referable.valFrac;
            fP = D.quality.passPct / 100; wP = D.quality.warningPct / 100; fL = D.quality.failPct / 100;
            n = imagesPerDay;
            nRef = n * ref;
            nFail = n * fL;
            nWarn = n * wP;
            sr = nRef + nFail + 0.25 * nWarn;
            txt = sprintf(['Input: %d images / 8h clinic day\n' ...
                '----------------------------------------------------\n' ...
                'Referable (P(ref) >= 0.60):     %6d  (%.1f%%)\n' ...
                'Quality FAIL -> recapture:       %6d  (%.1f%%)\n' ...
                'Quality WARNING (caution):       %6d  (%.1f%%)\n' ...
                '----------------------------------------------------\n' ...
                'Manual-review load (est.):       %6d  (WARNING counted at 25%%)\n' ...
                'Auto-clearable (est.):           %6d\n\n' ...
                'A single reviewer at ~60 reviews/hour clears the queue\n' ...
                'in one 8h shift: est. %.2f reviewers'], ...
                round(n), round(nRef), nRef / n * 100, round(nFail), nFail / n * 100, ...
                round(nWarn), nWarn / n * 100, round(sr), max(0, round(n - sr)), sr / (60 * 8));
            app.WorkloadOut.Text = txt;
        end

        %% ---------------- Tab 5: Inspector ----------------
        function InspectorTab(app, tg)
            t = uitab(tg, 'Title', ' Inspector ');
            grid = uigridlayout(t, [1 2], 'ColumnWidth', {260, '1x'});
            D = app.Data;

            cg = uigridlayout(grid, [5 1], 'RowHeight', {28, 40, 28, 170, 40});
            cg.Padding = [8 8 8 8]; cg.RowSpacing = 8;
            uilabel(cg, 'Text', 'Pick a class:');
            app.InspectorDrop = uidropdown(cg, ...
                'Items', {'0 - NoDR', '1 - Mild', '2 - Moderate', '3 - Severe', '4 - Proliferative'}, ...
                'Value', '2 - Moderate');
            app.InspectorDrop.ValueChangedFcn = @(s, ~) app.refreshList(s.Value);
            app.InspectorList = uilistbox(cg, 'Items', {});
            app.refreshList(app.InspectorDrop.Value);
            uibutton(cg, 'Text', 'Run predictSingleFundus', ...
                'ButtonPushedFcn', @(~, ~) app.runInspect());

            outPanel = uipanel(grid, 'Title', 'Prediction');
            app.InspectorOut = uitextarea(outPanel, ...
                'Value', {'Select a class + image, then press Run.'}, ...
                'FontName', 'Consolas', 'FontSize', 11, 'Editable', 'off', ...
                'Position', [12 12 760 260]);
        end

        function refreshList(app, classLabel)
            g = sscanf(classLabel, '%d');
            d = dir(fullfile(app.ProjectRoot, 'data', 'splits', 'val', ...
                sprintf('class_%d', g), '*.png'));
            items = cell(numel(d), 1);
            for i = 1:numel(d)
                items{i} = d(i).name;
            end
            app.InspectorList.Items = items;
            if ~isempty(items)
                app.InspectorList.Value = items{1};
            end
        end

        function runInspect(app)
            grade = sscanf(app.InspectorDrop.Value, '%d');
            imgPath = fullfile(app.ProjectRoot, 'data', 'splits', 'val', ...
                sprintf('class_%d', grade), char(app.InspectorList.Value));
            try
                r = predictSingleFundus(imgPath, 'ShowFigure', false);
                L = cell(0, 1);
                L{end + 1} = sprintf('File    : %s', char(app.InspectorList.Value));
                L{end + 1} = sprintf('Quality : %s (score %.2f)', r.qualityStatus, r.qualityScore);
                if r.qualityGate.enforced
                    L{end + 1} = sprintf('           -> QUALITY GATE ENFORCED (FAIL): recapture / manual review');
                elseif ~strcmp(r.qualityStatus, 'PASS')
                    L{end + 1} = sprintf('           -> caution flag (WARNING)');
                end
                L{end + 1} = sprintf('Referable: %.1f%% -> %s  (thr 0.60, LOCKED)', ...
                    r.binaryProbability * 100, r.binaryDecision);
                L{end + 1} = sprintf('Grade   : %d (%s), confidence %.1f%%', ...
                    r.grade, r.gradeLabel, r.confidence * 100);
                L{end + 1} = sprintf('Cascade : %s', r.cascade.route);
                if isfield(r, 'fusion') && r.fusion.available && ~isnan(r.fusion.branchB)
                    tag = 'agree (fusion)';
                    if r.fusion.discrepancy
                        tag = 'DISCREPANCY -> review';
                    end
                    L{end + 1} = sprintf('Branch B: P(ref)=%.1f%%  %s', r.fusion.branchB * 100, tag);
                end
                if isfield(r, 'lesions') && isfield(r.lesions, 'maCount')
                    L{end + 1} = sprintf('Lesions : MA=%d HE=%d EX=%d', ...
                        r.lesions.maCount, r.lesions.heCount, r.lesions.exCount);
                    if isfield(r.lesions, 'foveaSupplied') && r.lesions.foveaSupplied
                        L{end + 1} = sprintf('           fovea supplied -> xd. dist %.0f px', ...
                            r.lesions.meanExudateDistToFovea);
                    else
                        L{end + 1} = sprintf('           fovea NOT localized (T11 negative); dist n/a');
                    end
                end
                L{end + 1} = '';
                L{end + 1} = 'ENGINEERING DEMO. NOT a clinical device.';
                app.InspectorOut.Value = L;
            catch e
                app.InspectorOut.Value = {sprintf('Inference error: %s', e.message)};
            end
        end

        function s = shortReason(app, r)
            r = strtrim(r);
            if numel(r) > 48
                s = [r(1:45) '...'];
            else
                s = r;
            end
        end

    end

end