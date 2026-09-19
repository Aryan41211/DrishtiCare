classdef RetinaAIApp < matlab.apps.AppBase
%RETINAAIAPP DRISHTI single-image DR screening demo for DrishtiCare.
%   RetinaAIApp()
%
%   App Designer-style application (programmatic, convertible to .mlapp)
%   that wraps predictSingleFundus() with a clean vertical-flow UI:
%     image upload -> quality check -> DR grade -> Grad-CAM -> report
%
%   ENGINEERING demo tool. NOT a clinical device.

    properties (Access = public)
        UIFigure           matlab.ui.Figure
    end

    properties (Access = private)
        ProjectRoot        char
        CurrentImagePath   char
        CurrentResult      struct

        ImageAxes          matlab.ui.control.UIAxes
        UploadButton       matlab.ui.control.Button
        SampleDropdown     matlab.ui.control.DropDown
        AnalyzeButton      matlab.ui.control.Button

        QualityPanel       matlab.ui.container.Panel
        QualityBadge       matlab.ui.control.Label
        QualityScoreLabel  matlab.ui.control.Label

        GradePanel         matlab.ui.container.Panel
        GradeValueLabel    matlab.ui.control.Label
        GradeNameLabel     matlab.ui.control.Label
        ReferableLabel     matlab.ui.control.Label
        ConfidenceLabel    matlab.ui.control.Label
        CascadeLabel       matlab.ui.control.Label

        GradCAMPanel       matlab.ui.container.Panel
        GradCAMAxes        matlab.ui.control.UIAxes

        RecommendLabel     matlab.ui.control.Label

        ViewOriginal
        ViewEnhanced
        ViewHeatmap
        ViewOverlay
        ViewButtons

        EnhanceLabel       matlab.ui.control.Label

        ReportPanel        matlab.ui.container.Panel
        ReportTextArea     matlab.ui.control.TextArea
        GenerateReportBtn  matlab.ui.control.Button
        CopyReportBtn      matlab.ui.control.Button
        PdfReportBtn       matlab.ui.control.Button
        PdfEngineLabel     matlab.ui.control.Label
        LastPdfPath        char
        PdfEngine          char

        FooterLabel        matlab.ui.control.Label
        StatusLabel        matlab.ui.control.Label
    end

    methods (Access = public)

        function app = RetinaAIApp()
            % RetinaAIApp.m lives at the repo root, so its folder is the
            % project root. Anchor on a known child ('src') so a future
            % relocation cannot silently change ProjectRoot again.
            appRoot = fileparts(mfilename('fullpath'));
            if exist(fullfile(appRoot, 'src'), 'dir')
                app.ProjectRoot = appRoot;
            else
                app.ProjectRoot = fileparts(appRoot);
            end
            % Path: repo root plus the src tree ONLY. A repo-wide genpath would
            % also pull in archive/ and host-managed worktrees (e.g.
            % .kilo/worktrees/), whose stale function copies shadow the live
            % src/ code and silently change app behavior.
            addpath(app.ProjectRoot);
            addpath(genpath(fullfile(app.ProjectRoot, 'src')));
            app.CurrentImagePath = '';
            app.CurrentResult = struct();
            createComponents(app);
            loadSampleList(app);
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
            app.UIFigure = uifigure('Name', 'DRISHTI', ...
                'Position', [200 30 520 1040], ...
                'Color', [0.96 0.97 0.98], ...
                'Resize', 'off');

            scrollable = uipanel(app.UIFigure, ...
                'Position', [0 0 520 1040], ...
                'BackgroundColor', [0.96 0.97 0.98], ...
                'BorderType', 'none', ...
                'Scrollable', 'on');

            createHeader(app, scrollable);
            createImageSection(app, scrollable);
            createControlsSection(app, scrollable);
            createQualitySection(app, scrollable);
            createGradeSection(app, scrollable);
            createRecommendationSection(app, scrollable);
            createGradCAMSection(app, scrollable);
            createReportSection(app, scrollable);
            createFooter(app, scrollable);
        end

        function createHeader(app, parent)
            uilabel(parent, 'Text', 'DRISHTI', ...
                'Position', [0 975 520 40], ...
                'FontSize', 28, ...
                'FontWeight', 'bold', ...
                'FontColor', [0.13 0.22 0.38], ...
                'HorizontalAlignment', 'center');

            uilabel(parent, 'Text', 'AI Retinal Screening Assistant', ...
                'Position', [0 950 520 25], ...
                'FontSize', 13, ...
                'FontColor', [0.45 0.50 0.56], ...
                'HorizontalAlignment', 'center');
        end

        function createImageSection(app, parent)
            app.ImageAxes = uiaxes(parent, ...
                'Position', [60 770 400 160], ...
                'Box', 'on', ...
                'XTick', [], 'YTick', [], ...
                'BackgroundColor', [1 1 1]);
            title(app.ImageAxes, '');

            text(app.ImageAxes, 0.5, 0.5, 'No image selected', ...
                'Units', 'normalized', ...
                'HorizontalAlignment', 'center', ...
                'FontSize', 12, ...
                'Color', [0.7 0.7 0.7]);
        end

        function createControlsSection(app, parent)
            app.UploadButton = uibutton(parent, 'push', ...
                'Text', 'Upload Image', ...
                'Position', [60 725 160 32], ...
                'FontSize', 12, ...
                'FontWeight', 'bold', ...
                'BackgroundColor', [0.20 0.40 0.70], ...
                'FontColor', [1 1 1], ...
                'ButtonPushedFcn', @(~,~) app.uploadCallback());

            uilabel(parent, 'Text', 'or select sample:', ...
                'Position', [235 730 90 20], ...
                'FontSize', 11, ...
                'FontColor', [0.45 0.50 0.56]);

            app.SampleDropdown = uidropdown(parent, ...
                'Items', {'(no samples)'}, ...
                'Position', [330 725 130 32], ...
                'FontSize', 11, ...
                'ValueChangedFcn', @(~,~) app.sampleCallback());

            app.AnalyzeButton = uibutton(parent, 'push', ...
                'Text', 'ANALYZE IMAGE', ...
                'Position', [60 680 400 38], ...
                'FontSize', 15, ...
                'FontWeight', 'bold', ...
                'BackgroundColor', [0.10 0.55 0.35], ...
                'FontColor', [1 1 1], ...
                'Enable', 'off', ...
                'ButtonPushedFcn', @(~,~) app.analyzeCallback());
        end

        function createQualitySection(app, parent)
            app.QualityPanel = uipanel(parent, ...
                'Title', ' Image Quality ', ...
                'Position', [30 585 460 90], ...
                'FontSize', 12, ...
                'FontWeight', 'bold', ...
                'BackgroundColor', [1 1 1]);

            app.QualityBadge = uilabel(app.QualityPanel, ...
                'Text', '—', ...
                'Position', [15 45 220 35], ...
                'FontSize', 17, ...
                'FontWeight', 'bold', ...
                'FontColor', [0.5 0.5 0.5]);

            app.QualityScoreLabel = uilabel(app.QualityPanel, ...
                'Text', 'Upload an image and click ANALYZE', ...
                'Position', [240 45 205 35], ...
                'FontSize', 11, ...
                'FontColor', [0.5 0.5 0.5], ...
                'VerticalAlignment', 'center');

            app.EnhanceLabel = uilabel(app.QualityPanel, ...
                'Text', '', ...
                'Position', [15 10 430 28], ...
                'FontSize', 11, ...
                'FontColor', [0.45 0.50 0.56], ...
                'VerticalAlignment', 'center');
        end

        function createGradeSection(app, parent)
            app.GradePanel = uipanel(parent, ...
                'Title', ' DR Classification ', ...
                'Position', [30 410 460 170], ...
                'FontSize', 12, ...
                'FontWeight', 'bold', ...
                'BackgroundColor', [1 1 1]);

            app.GradeValueLabel = uilabel(app.GradePanel, ...
                'Text', '—', ...
                'Position', [20 115 200 40], ...
                'FontSize', 28, ...
                'FontWeight', 'bold', ...
                'FontColor', [0.13 0.22 0.38]);

            app.GradeNameLabel = uilabel(app.GradePanel, ...
                'Text', '', ...
                'Position', [230 115 210 40], ...
                'FontSize', 16, ...
                'FontWeight', 'bold', ...
                'FontColor', [0.30 0.35 0.40], ...
                'VerticalAlignment', 'center');

            app.ReferableLabel = uilabel(app.GradePanel, ...
                'Text', '', ...
                'Position', [20 75 420 30], ...
                'FontSize', 13, ...
                'FontColor', [0.30 0.35 0.40]);

            app.ConfidenceLabel = uilabel(app.GradePanel, ...
                'Text', '', ...
                'Position', [20 45 420 25], ...
                'FontSize', 12, ...
                'FontColor', [0.45 0.50 0.56]);

            app.CascadeLabel = uilabel(app.GradePanel, ...
                'Text', '', ...
                'Position', [20 15 420 25], ...
                'FontSize', 12, ...
                'FontColor', [0.45 0.50 0.56]);
        end

        function createRecommendationSection(app, parent)
            app.RecommendLabel = uilabel(parent, ...
                'Text', '', ...
                'Position', [30 365 460 40], ...
                'FontSize', 13, ...
                'FontWeight', 'bold', ...
                'FontColor', [0.38 0.42 0.46], ...
                'BackgroundColor', [0.94 0.95 0.97], ...
                'HorizontalAlignment', 'center', ...
                'VerticalAlignment', 'center');
        end

        function createGradCAMSection(app, parent)
            app.GradCAMPanel = uipanel(parent, ...
                'Title', ' Model Attention Visualization - not lesion localization ', ...
                'Position', [30 170 460 190], ...
                'FontSize', 12, ...
                'FontWeight', 'bold', ...
                'BackgroundColor', [1 1 1]);

            app.GradCAMAxes = uiaxes(app.GradCAMPanel, ...
                'Position', [10 5 440 150], ...
                'XTick', [], 'YTick', [], ...
                'Box', 'on', ...
                'BackgroundColor', [0.95 0.95 0.95]);
            title(app.GradCAMAxes, '');

            text(app.GradCAMAxes, 0.5, 0.5, 'Awaiting analysis', ...
                'Units', 'normalized', ...
                'HorizontalAlignment', 'center', ...
                'FontSize', 11, ...
                'Color', [0.7 0.7 0.7]);

            % View switcher: one large axes, Overlay default after analysis
            app.ViewButtons = gobjects(1, 4);
            viewNames = {'Original', 'Enhanced', 'Grad-CAM', 'Overlay'};
            xs = [10 118 226 334];
            for vi = 1:4
                app.ViewButtons(vi) = uibutton(app.GradCAMPanel, 'push', ...
                    'Text', viewNames{vi}, ...
                    'Position', [xs(vi) 160 105 25], ...
                    'FontSize', 10, ...
                    'ButtonPushedFcn', @(src, ~) app.showView(char(src.Text)));
            end
        end

        function createReportSection(app, parent)
            app.ReportPanel = uipanel(parent, ...
                'Title', ' Report ', ...
                'Position', [30 50 460 112], ...
                'FontSize', 12, ...
                'FontWeight', 'bold', ...
                'BackgroundColor', [1 1 1]);

            app.ReportTextArea = uitextarea(app.ReportPanel, ...
                'Position', [10 36 440 48], ...
                'FontSize', 10, ...
                'FontName', 'Consolas', ...
                'Editable', 'off', ...
                'Value', {'Analysis report will appear here.'});

            app.PdfEngineLabel = uilabel(app.ReportPanel, ...
                'Text', 'PDF engine: auto', ...
                'Position', [340 88 110 20], ...
                'FontSize', 9, ...
                'FontWeight', 'bold', ...
                'HorizontalAlignment', 'center', ...
                'VerticalAlignment', 'center', ...
                'FontColor', [0.55 0.60 0.65], ...
                'BackgroundColor', [0.93 0.94 0.96]);

            app.GenerateReportBtn = uibutton(app.ReportPanel, 'push', ...
                'Text', 'Save Report', ...
                'Position', [10 5 100 25], ...
                'FontSize', 10, ...
                'ButtonPushedFcn', @(~,~) app.saveReportCallback());

            app.CopyReportBtn = uibutton(app.ReportPanel, 'push', ...
                'Text', 'Copy to Clipboard', ...
                'Position', [115 5 135 25], ...
                'FontSize', 10, ...
                'ButtonPushedFcn', @(~,~) app.copyReportCallback());

            app.PdfReportBtn = uibutton(app.ReportPanel, 'push', ...
                'Text', 'Save PDF Report', ...
                'Position', [255 5 125 25], ...
                'FontSize', 10, ...
                'ButtonPushedFcn', @(~,~) app.savePdfReportCallback());
        end

        function createFooter(app, parent)
            app.FooterLabel = uilabel(parent, ...
                'Text', 'ENGINEERING DEMO - NOT a clinical device. Thresholds are experimental.', ...
                'Position', [0 20 520 20], ...
                'FontSize', 9, ...
                'FontAngle', 'italic', ...
                'FontColor', [0.65 0.32 0.32], ...
                'HorizontalAlignment', 'center');

            app.StatusLabel = uilabel(parent, ...
                'Text', 'Ready', ...
                'Position', [0 0 520 20], ...
                'FontSize', 10, ...
                'FontColor', [0.45 0.50 0.56], ...
                'HorizontalAlignment', 'center');
        end

        function loadSampleList(app)
            valDir = fullfile(app.ProjectRoot, 'data', 'splits', 'val');
            items = {'(no samples)'};
            if exist(valDir, 'dir')
                classes = {'class_0', 'class_1', 'class_2', 'class_3', 'class_4'};
                labels = {'NoDR', 'Mild', 'Moderate', 'Severe', 'Prolif'};
                for c = 1:numel(classes)
                    d = dir(fullfile(valDir, classes{c}, '*.png'));
                    for i = 1:min(3, numel(d))
                        items{end+1} = sprintf('%s/%s (%s)', classes{c}, d(i).name, labels{c}); %#ok<AGROW>
                    end
                end
            end
            app.SampleDropdown.Items = items;
        end

        function uploadCallback(app)
            [file, path] = uigetfile({'*.png;*.jpg;*.jpeg', 'Fundus images'}, 'Select a fundus image');
            if isequal(file, 0)
                return;
            end
            app.CurrentImagePath = fullfile(path, file);
            showImage(app, app.CurrentImagePath);
            app.AnalyzeButton.Enable = 'on';
            app.StatusLabel.Text = sprintf('Loaded: %s', file);
        end

        function sampleCallback(app)
            val = app.SampleDropdown.Value;
            if strcmp(val, '(no samples)')
                return;
            end
            parts = strsplit(val, '/');
            classFolder = parts{1};
            rest = strsplit(parts{2}, ' ');
            fileName = rest{1};
            app.CurrentImagePath = fullfile(app.ProjectRoot, 'data', 'splits', 'val', classFolder, fileName);
            if exist(app.CurrentImagePath, 'file')
                showImage(app, app.CurrentImagePath);
                app.AnalyzeButton.Enable = 'on';
                app.StatusLabel.Text = sprintf('Loaded: %s', fileName);
            else
                app.StatusLabel.Text = 'Sample file not found.';
            end
        end

        function showImage(app, imgPath)
            try
                img = imread(imgPath);
                imshow(img, 'Parent', app.ImageAxes);
                title(app.ImageAxes, '');
            catch
                app.StatusLabel.Text = 'Failed to load image.';
            end
        end

        function analyzeCallback(app)
            if isempty(app.CurrentImagePath) || ~exist(app.CurrentImagePath, 'file')
                app.StatusLabel.Text = 'No valid image selected.';
                return;
            end

            app.AnalyzeButton.Enable = 'off';
            app.StatusLabel.Text = 'Analyzing...';
            drawnow;

            try
                result = predictSingleFundus(app.CurrentImagePath, ...
                    'ShowFigure', false, 'RunLesions', true, ...
                    'RunBranchB', true, 'SkipModelOnFail', true);
                app.CurrentResult = result;
                cacheViews(app, result);
                displayResults(app, result);
                app.StatusLabel.Text = sprintf('Analysis complete (%.2fs)', result.runtimeSec);
            catch e
                app.StatusLabel.Text = sprintf('Error: %s', e.message);
            end

            app.AnalyzeButton.Enable = 'on';
        end

        function displayResults(app, r)
            displayQuality(app, r);
            if isfield(r, 'binaryDecision') && startsWith(r.binaryDecision, 'WITHHELD')
                displayWithheld(app, r);
                return;
            end
            displayGrade(app, r);
            displayRecommendation(app, r);
            showView(app, 'Overlay');
            displayReport(app, r);
        end

        function t = qualityJudgeTerm(~, status)
            switch status
                case 'PASS',    t = 'ACCEPT (PASS)';
                case 'WARNING', t = 'BORDERLINE (WARNING)';
                case 'FAIL',    t = 'REJECT (FAIL)';
                otherwise,      t = status;
            end
        end

        function cacheViews(app, r)
            % Cache the four explainability views (display only; the model
            % input pipeline inside predictSingleFundus is never re-fed).
            app.ViewOriginal = [];
            app.ViewEnhanced = [];
            app.ViewHeatmap = [];
            app.ViewOverlay = [];
            try
                raw = imread(app.CurrentImagePath);
                if size(raw, 3) == 1, raw = repmat(raw, 1, 1, 3); end
                app.ViewOriginal = raw;
                app.ViewEnhanced = enhanceImage(raw);
            catch
                return;
            end
            if isfield(r, 'gradCAM') && ~isempty(r.gradCAM)
                app.ViewOverlay = r.gradCAM;
            end
            if isfield(r, 'gradCAMMap') && ~isempty(r.gradCAMMap) ...
                    && isfield(r, 'binaryDecision') && ~startsWith(r.binaryDecision, 'WITHHELD')
                hm = imresize(mat2gray(r.gradCAMMap), [224 224]);
                app.ViewHeatmap = im2uint8(ind2rgb(im2uint8(hm), jet(256)));
            else
                app.ViewHeatmap = app.ViewOverlay;
            end
        end

        function showView(app, name)
            switch name
                case 'Original', img = app.ViewOriginal;
                case 'Enhanced', img = app.ViewEnhanced;
                case 'Grad-CAM', img = app.ViewHeatmap;
                otherwise,       img = app.ViewOverlay;
            end
            if isempty(img)
                cla(app.GradCAMAxes);
                text(app.GradCAMAxes, 0.5, 0.5, [name ' view unavailable'], ...
                    'Units', 'normalized', 'HorizontalAlignment', 'center', ...
                    'FontSize', 11, 'Color', [0.7 0.7 0.7]);
            else
                imshow(img, 'Parent', app.GradCAMAxes);
                title(app.GradCAMAxes, '');
            end
        end

        function displayWithheld(app, r)
            app.GradeValueLabel.Text = '—';
            app.GradeValueLabel.FontColor = [0.5 0.5 0.5];
            app.GradeNameLabel.Text = 'NOT ASSESSED (quality FAIL)';
            app.GradeNameLabel.FontColor = [0.5 0.5 0.5];
            app.ReferableLabel.Text = sprintf('DR decision: %s', r.binaryDecision);
            app.ReferableLabel.FontColor = [0.85 0.25 0.22];
            app.ConfidenceLabel.Text = 'No model score — classification was not run.';
            app.ConfidenceLabel.FontColor = [0.5 0.5 0.5];
            app.CascadeLabel.Text = 'Route: REVIEW (recapture / manual review)';
            app.RecommendLabel.Text = 'IMAGE NOT SUITABLE FOR ANALYSIS — RECAPTURE RECOMMENDED';
            app.RecommendLabel.FontColor = [0.85 0.25 0.22];
            app.RecommendLabel.BackgroundColor = [1 0.92 0.92];
            cla(app.GradCAMAxes);
            text(app.GradCAMAxes, 0.5, 0.5, 'No Grad-CAM: analysis withheld (quality FAIL)', ...
                'Units', 'normalized', 'HorizontalAlignment', 'center', ...
                'FontSize', 11, 'Color', [0.7 0.7 0.7]);
            lines = {};
            lines{end+1} = '=== DRISHTI Analysis Report ===';
            lines{end+1} = '';
            lines{end+1} = sprintf('Image Quality: %s (score %.2f)', ...
                app.qualityJudgeTerm(r.qualityStatus), r.qualityScore);
            lines{end+1} = 'DR decision WITHHELD: quality gate FAIL — no model decision computed.';
            lines{end+1} = '';
            lines{end+1} = 'Failure reasons:';
            for k = 1:numel(r.qualityFailureReasons)
                lines{end+1} = [' - ' r.qualityFailureReasons{k}];
            end
            lines{end+1} = '';
            lines{end+1} = ['Recapture advice: ' r.qualityRecaptureAdvice];
            lines{end+1} = '';
            lines{end+1} = 'ENGINEERING DEMO - NOT a clinical device.';
            app.ReportTextArea.Value = lines;
        end

        function displayQuality(app, r)
            status = r.qualityStatus;
            switch status
                case 'PASS'
                    badgeColor = [0.18 0.65 0.32];
                    enhanceText = 'Enhancement: not required';
                case 'WARNING'
                    badgeColor = [0.85 0.65 0.13];
                    enhanceText = 'Adaptive enhancement: APPLIED (display aid — model input unchanged)';
                case 'FAIL'
                    badgeColor = [0.85 0.25 0.22];
                    enhanceText = '';
                otherwise
                    badgeColor = [0.5 0.5 0.5];
                    enhanceText = '';
            end

            app.QualityBadge.Text = app.qualityJudgeTerm(status);
            app.QualityBadge.FontColor = badgeColor;
            app.EnhanceLabel.Text = enhanceText;

            detail = sprintf('Score: %.2f', r.qualityScore);
            if isfield(r, 'qualityGate') && r.qualityGate.enforced
                detail = [detail ' | GATE ENFORCED (FAIL)'];
            end
            app.QualityScoreLabel.Text = detail;
        end

        function displayGrade(app, r)
            app.GradeValueLabel.Text = sprintf('%d / 4', r.grade);
            app.GradeNameLabel.Text = upper(r.gradeLabel);

            if r.grade >= 3
                app.GradeValueLabel.FontColor = [0.85 0.22 0.18];
                app.GradeNameLabel.FontColor = [0.85 0.22 0.18];
            elseif r.grade >= 2
                app.GradeValueLabel.FontColor = [0.85 0.55 0.10];
                app.GradeNameLabel.FontColor = [0.85 0.55 0.10];
            else
                app.GradeValueLabel.FontColor = [0.18 0.65 0.32];
                app.GradeNameLabel.FontColor = [0.18 0.65 0.32];
            end

            app.ReferableLabel.Text = sprintf('REFERABLE DR: %s', r.binaryDecision);
            if strcmp(r.binaryDecision, 'REFERABLE')
                app.ReferableLabel.FontColor = [0.85 0.35 0.15];
            else
                app.ReferableLabel.FontColor = [0.18 0.65 0.32];
            end

            app.ConfidenceLabel.Text = sprintf('Model Score: %.1f%% (engineering prototype threshold %.2f LOCKED)', ...
                r.binaryProbability * 100, r.binaryThreshold);

            cascadeText = sprintf('Route: %s', r.cascade.route);
            if isfield(r, 'fusion') && r.fusion.available
                if r.fusion.discrepancy
                    cascadeText = [cascadeText ' | Branch B: DISCREPANCY'];
                elseif r.fusion.agree
                    cascadeText = [cascadeText ' | Branch B: agree'];
                end
            end
            app.CascadeLabel.Text = cascadeText;
        end

        function displayRecommendation(app, r)
            if r.qualityGate.enforced
                app.RecommendLabel.Text = 'RECAPTURE OR MANUAL REVIEW REQUIRED (quality FAIL)';
                app.RecommendLabel.FontColor = [0.85 0.25 0.22];
                app.RecommendLabel.BackgroundColor = [1 0.92 0.92];
            elseif r.grade >= 3
                app.RecommendLabel.Text = 'REFER FOR URGENT OPHTHALMOLOGIST REVIEW';
                app.RecommendLabel.FontColor = [0.85 0.15 0.10];
                app.RecommendLabel.BackgroundColor = [1 0.90 0.90];
            elseif r.grade == 2 || strcmp(r.binaryDecision, 'REFERABLE')
                app.RecommendLabel.Text = 'REFER FOR OPHTHALMOLOGIST REVIEW';
                app.RecommendLabel.FontColor = [0.85 0.50 0.08];
                app.RecommendLabel.BackgroundColor = [1 0.96 0.88];
            elseif strcmp(r.cascade.route, 'REVIEW') || strcmp(r.cascade.route, 'ABSTAIN')
                app.RecommendLabel.Text = 'SPECIALIST CHECK ADVISED (borderline case)';
                app.RecommendLabel.FontColor = [0.85 0.50 0.08];
                app.RecommendLabel.BackgroundColor = [1 0.96 0.88];
            else
                app.RecommendLabel.Text = 'NO REFERABLE DR DETECTED - ROUTINE FOLLOW-UP';
                app.RecommendLabel.FontColor = [0.18 0.65 0.32];
                app.RecommendLabel.BackgroundColor = [0.90 0.97 0.90];
            end
        end

        function displayReport(app, r)
            lines = {};
            lines{end+1} = sprintf('=== DRISHTI Analysis Report ===');
            lines{end+1} = '';
            lines{end+1} = sprintf('Image Quality: %s (score %.2f)', ...
                app.qualityJudgeTerm(r.qualityStatus), r.qualityScore);
            if strcmp(r.qualityStatus, 'WARNING')
                lines{end+1} = 'Adaptive enhancement: APPLIED (display aid — model input unchanged).';
            end
            if r.qualityGate.enforced
                lines{end+1} = '  Quality gate ENFORCED: FAIL -> recapture/manual review';
            end
            lines{end+1} = '';
            lines{end+1} = sprintf('DR Grade: %d / 4 - %s', r.grade, r.gradeLabel);
            lines{end+1} = sprintf('Referable DR: %s', r.binaryDecision);
            lines{end+1} = sprintf('Model Score: %.1f%% (engineering prototype threshold %.2f LOCKED)', ...
                r.binaryProbability * 100, r.binaryThreshold);
            lines{end+1} = '';
            if isfield(r, 'lesions') && isfield(r.lesions, 'maCount')
                lines{end+1} = sprintf('Lesion candidates: MA=%d HE=%d EX=%d', ...
                    r.lesions.maCount, r.lesions.heCount, r.lesions.exCount);
                if r.lesions.odLocated
                    lines{end+1} = '  Optic disc: located';
                else
                    lines{end+1} = '  Optic disc: not located';
                end
            end
            if r.ood.available
                if r.ood.flag
                    lines{end+1} = sprintf('OOD: OUT-OF-DISTRIBUTION (Mah=%.1f)', r.ood.mahalanobis);
                else
                    lines{end+1} = sprintf('OOD: in-distribution (Mah=%.1f)', r.ood.mahalanobis);
                end
            end
            lines{end+1} = sprintf('Cascade route: %s', r.cascade.route);
            lines{end+1} = '';
            if isfield(r, 'explanation') && isfield(r.explanation, 'recommendation')
                lines{end+1} = sprintf('Recommendation: %s', r.explanation.recommendation);
            end
            lines{end+1} = '';
            lines{end+1} = sprintf('Inference time: %.2fs', r.runtimeSec);
            lines{end+1} = '';
            lines{end+1} = 'ENGINEERING DEMO - NOT a clinical device.';

            app.ReportTextArea.Value = lines;
        end

        function saveReportCallback(app)
            if isempty(app.CurrentResult)
                app.StatusLabel.Text = 'No analysis to save.';
                return;
            end
            [file, path] = uiputfile({'*.txt', 'Text files'}, 'Save Report', 'retina_report.txt');
            if isequal(file, 0)
                return;
            end
            lines = app.ReportTextArea.Value;
            fid = fopen(fullfile(path, file), 'w');
            if fid == -1
                app.StatusLabel.Text = 'Failed to open report file';
                return;
            end
            try
                for i = 1:numel(lines)
                    fprintf(fid, '%s\n', lines{i});
                end
            catch
                fclose(fid);
                app.StatusLabel.Text = 'Error writing report';
                return;
            end
            fclose(fid);
            savedNote = sprintf('Report saved: %s', file);
            if ~isempty(app.ViewOverlay)
                [~, base] = fileparts(file);
                pngName = [base '_overlay.png'];
                try
                    imwrite(app.ViewOverlay, fullfile(path, pngName));
                    savedNote = sprintf('%s + %s', savedNote, pngName);
                catch
                    savedNote = [savedNote ' (overlay PNG export failed)'];
                end
            end
            app.StatusLabel.Text = savedNote;
        end

        function copyReportCallback(app)
            if isempty(app.CurrentResult)
                return;
            end
            lines = app.ReportTextArea.Value;
            text = strjoin(lines, newline);
            clipboard('copy', text);
            app.StatusLabel.Text = 'Report copied to clipboard.';
        end

        function savePdfReportCallback(app)
            if isempty(app.CurrentResult)
                app.StatusLabel.Text = 'No analysis to save.';
                return;
            end
            outDir = fullfile(app.ProjectRoot, 'results');
            patientID = app.derivedPatientId();
            try
                [pdfPath, engine] = generateDrishtiReport(app.CurrentResult, ...
                    'PatientID', patientID, 'OutDir', outDir);
                app.LastPdfPath = pdfPath;
                app.PdfEngine  = engine;
                app.showPdfEngine(engine);
                [~, baseName, ext] = fileparts(pdfPath);
                app.StatusLabel.Text = sprintf('PDF saved (%s): %s%s', engine, baseName, ext);
            catch e
                app.StatusLabel.Text = sprintf('PDF export failed: %s', e.message);
            end
        end

        function patientID = derivedPatientId(app)
            patientID = 'ANON';
            if ~isempty(app.CurrentImagePath) && exist(app.CurrentImagePath, 'file')
                [~, base] = fileparts(app.CurrentImagePath);
                candidate = regexprep(base, '[^A-Za-z0-9_.-]', '_');
                if ~isempty(candidate)
                    patientID = candidate;
                end
            end
        end

        function showPdfEngine(app, engine)
            if strcmpi(engine, 'mlreportgen')
                app.PdfEngineLabel.Text = 'PDF: mlreportgen';
                app.PdfEngineLabel.FontColor = [0.18 0.65 0.32];
                app.PdfEngineLabel.BackgroundColor = [0.90 0.97 0.90];
            else
                app.PdfEngineLabel.Text = 'PDF: Edge fallback';
                app.PdfEngineLabel.FontColor = [0.85 0.55 0.10];
                app.PdfEngineLabel.BackgroundColor = [1 0.96 0.88];
            end
            app.PdfEngineLabel.Visible = 'on';
        end

    end

end