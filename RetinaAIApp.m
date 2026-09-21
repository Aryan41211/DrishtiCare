classdef RetinaAIApp < matlab.apps.AppBase
%RETINAAIAPP DRISHTI single-image DR screening demo for DrishtiCare.
%   RetinaAIApp()
%
%   App Designer-style application (programmatic, convertible to .mlapp)
%   that wraps predictSingleFundus() with a three-column dark desktop UI:
%
%     [ FUNDUS IMAGE ] | [ AI SCREENING RESULT + IMAGE QUALITY ] |
%                      | [ MODEL EXPLANATION + report button       ]
%
%   image upload -> quality check -> DR grade -> Grad-CAM -> report
%
%   ENGINEERING demo tool. NOT a clinical device.

    properties (Access = public)
        UIFigure           matlab.ui.Figure
    end

    properties (Access = private)
        ProjectRoot        char
        CurrentImagePath   char
        CurrentResult      struct

        % ---- layout containers -------------------------------------------
        HeaderPanel        matlab.ui.container.Panel
        LeftPanel          matlab.ui.container.Panel
        MiddlePanel        matlab.ui.container.Panel
        RightPanel        matlab.ui.container.Panel

        % ---- header -------------------------------------------------------
        % ---- left panel: fundus image -------------------------------------
        FilenameLabel      matlab.ui.control.Label
        MenuBtn            matlab.ui.control.Button
        ImageAxes          matlab.ui.control.UIAxes
        UploadButton       matlab.ui.control.Button
        SampleDropdown     matlab.ui.control.DropDown
        AnalyzeButton      matlab.ui.control.Button

        % ---- middle panel: AI screening result ----------------------------
        SeverityValue      matlab.ui.control.Label
        IcdrValue          matlab.ui.control.Label
        ReferableValue     matlab.ui.control.Label
        ScoreValue         matlab.ui.control.Label
        AdviceBox          matlab.ui.control.Label
        ModelInfoLabel     matlab.ui.control.Label

        % ---- image quality panel ------------------------------------------
        QualityPanel       matlab.ui.container.Panel
        FocusValue         matlab.ui.control.Label
        FocusCheck         matlab.ui.control.Label
        IllumValue         matlab.ui.control.Label
        IllumCheck         matlab.ui.control.Label
        FovValue           matlab.ui.control.Label
        FovCheck           matlab.ui.control.Label
        OverallValue       matlab.ui.control.Label
        EnhanceLabel       matlab.ui.control.Label
        QualityBadge       matlab.ui.control.Label

        % ---- right panel: model explanation -------------------------------
        GradCAMPanel       matlab.ui.container.Panel
        GradCAMAxes        matlab.ui.control.UIAxes
        ColorbarAxes       matlab.ui.control.UIAxes
        VizTitle           matlab.ui.control.Label
        ViewOriginal
        ViewEnhanced
        ViewHeatmap
        ViewOverlay
        ViewButtons

        % ---- report --------------------------------------------------------
        ReportTextArea     matlab.ui.control.TextArea
        GenerateReportBtn  matlab.ui.control.Button
        CopyReportBtn      matlab.ui.control.Button
        PdfReportBtn       matlab.ui.control.Button
        PdfEngineLabel     matlab.ui.control.Label
        LastPdfPath        char
        PdfEngine          char

        % ---- kebab menu / sample list state --------------------------------
        KebabMenu
        SamplePaths        cell
        SampleItems        cell
        SuspendSampleCallback logical = false

        FooterLabel        matlab.ui.control.Label
        MetricsLabel       matlab.ui.control.Label
        StatusLabel        matlab.ui.control.Label
        StatusDot          matlab.ui.control.Label
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
            % Dark desktop window, three fixed columns:
            %   left (image) | middle (result + quality) | right (explanation)
            app.UIFigure = uifigure('Name', 'DRISHTI - DR Screening Assistant', ...
                'Position', [60 40 1360 780], ...
                'Color', [0.09 0.10 0.12], ...
                'Resize', 'off');

            % ---------- header ----------
            app.HeaderPanel = uipanel(app.UIFigure, ...
                'Position', [0 728 1360 52], ...
                'BackgroundColor', [0.09 0.17 0.30], ...
                'BorderType', 'none');

            uilabel(app.HeaderPanel, 'Text', 'DRISHTI', ...
                'Position', [16 20 220 30], ...
                'FontSize', 22, 'FontWeight', 'bold', ...
                'FontColor', [1 1 1], 'HorizontalAlignment', 'left');

            uilabel(app.HeaderPanel, 'Text', 'Explainable AI for Diabetic Retinopathy Screening', ...
                'Position', [18 2 420 16], ...
                'FontSize', 10, ...
                'FontColor', [0.70 0.78 0.88], 'HorizontalAlignment', 'left');

            app.StatusDot = uilabel(app.HeaderPanel, ...
                'Text', char(9679), ...
                'Position', [1180 16 24 22], ...
                'FontSize', 14, 'FontColor', [0.20 0.78 0.35], ...
                'BackgroundColor', [0.09 0.17 0.30]);

            app.StatusLabel = uilabel(app.HeaderPanel, ...
                'Text', 'System Ready', ...
                'Position', [1204 16 130 22], ...
                'FontSize', 11, 'FontColor', [0.90 0.93 0.96], ...
                'BackgroundColor', [0.09 0.17 0.30]);
            % ---------- three columns ----------
            app.LeftPanel = uipanel(app.UIFigure, ...
                'Title', ' FUNDUS IMAGE ', ...
                'FontSize', 11, 'FontWeight', 'bold', ...
                'ForegroundColor', [0.90 0.92 0.95], ...
                'BackgroundColor', [0.13 0.14 0.17], ...
                'BorderColor', [0.45 0.47 0.50], ...
                'Position', [8 30 400 690]);

            app.MiddlePanel = uipanel(app.UIFigure, ...
                'Title', ' AI SCREENING RESULT ', ...
                'FontSize', 11, 'FontWeight', 'bold', ...
                'ForegroundColor', [0.90 0.92 0.95], ...
                'BackgroundColor', [0.13 0.14 0.17], ...
                'BorderColor', [0.45 0.47 0.50], ...
                'Position', [414 30 460 690]);

            app.RightPanel = uipanel(app.UIFigure, ...
                'Title', ' MODEL EXPLANATION (attention, not lesion proof) ', ...
                'FontSize', 11, 'FontWeight', 'bold', ...
                'ForegroundColor', [0.90 0.92 0.95], ...
                'BackgroundColor', [0.13 0.14 0.17], ...
                'BorderColor', [0.45 0.47 0.50], ...
                'Position', [880 30 472 690]);

            % ---------- footer (bottom bar) ----------
            app.FooterLabel = uilabel(app.UIFigure, ...
                'Text', 'Human-in-the-loop: final clinical decision by an ophthalmologist.', ...
                'Position', [16 6 560 20], ...
                'FontSize', 9, ...
                'FontColor', [0.75 0.78 0.82], 'HorizontalAlignment', 'left');

            app.MetricsLabel = uilabel(app.UIFigure, ...
                'Text', ['Model V1 test acc 82.81% ' char(183) ' referable sens 90.60% / spec 94.71% ' char(183) ' prototype, NOT clinically validated.'], ...
                'Position', [580 6 770 20], ...
                'FontSize', 9, ...
                'FontColor', [0.75 0.78 0.82], 'HorizontalAlignment', 'right');

            createImageSection(app, app.LeftPanel);
            createControlsSection(app, app.LeftPanel);
            createResultSection(app, app.MiddlePanel);
            createQualitySection(app, app.MiddlePanel);
            createGradCAMSection(app, app.RightPanel);
            createReportSection(app, app.RightPanel);
        end

        function createImageSection(app, parent)
            % Left column: filename row, kebab menu, fundus preview
            app.FilenameLabel = uilabel(parent, ...
                'Text', 'No image selected', ...
                'Position', [16 652 348 20], ...
                'FontSize', 10, 'FontColor', [0.63 0.65 0.70], ...
                'BackgroundColor', [0.13 0.14 0.17], ...
                'HorizontalAlignment', 'left');

            app.MenuBtn = uibutton(parent, 'push', ...
                'Text', char(8943), ...
                'Position', [368 648 16 26], ...
                'FontSize', 12, 'FontWeight', 'bold', ...
                'BackgroundColor', [0.13 0.14 0.17], ...
                'FontColor', [0.63 0.65 0.70], ...
                'ButtonPushedFcn', @(~,~) app.menuButtonCallback());

            app.ImageAxes = uiaxes(parent, ...
                'Position', [16 96 368 546], ...
                'Box', 'off', ...
                'XTick', [], 'YTick', [], ...
                'Toolbar', [], ...
                'BackgroundColor', [0.07 0.08 0.10]);
            text(app.ImageAxes, 0.5, 0.5, 'No image selected', ...
                'Units', 'normalized', ...
                'HorizontalAlignment', 'center', ...
                'FontSize', 12, ...
                'Color', [0.55 0.57 0.60]);
        end

        function createControlsSection(app, parent)
            % Left column bottom: upload + analyze buttons.
            % The sample dropdown is kept (hidden) so sample selection
            % stays driven by the kebab menu and headless verifiers.
            app.UploadButton = uibutton(parent, 'push', ...
                'Text', 'Upload Fundus Image', ...
                'Position', [16 34 190 44], ...
                'FontSize', 12, ...
                'BackgroundColor', [0.20 0.22 0.26], ...
                'FontColor', [0.95 0.96 0.97], ...
                'ButtonPushedFcn', @(~,~) app.uploadCallback());

            app.AnalyzeButton = uibutton(parent, 'push', ...
                'Text', 'ANALYZE IMAGE', ...
                'Position', [222 34 162 44], ...
                'FontSize', 13, ...
                'FontWeight', 'bold', ...
                'BackgroundColor', [0.16 0.42 0.86], ...
                'FontColor', [1 1 1], ...
                'Enable', 'off', ...
                'ButtonPushedFcn', @(~,~) app.analyzeCallback());

            app.SampleDropdown = uidropdown(parent, ...
                'Items', {'(no samples)'}, ...
                'Position', [16 8 100 22], ...
                'FontSize', 11, ...
                'Visible', 'off', ...
                'ValueChangedFcn', @(~,~) app.sampleCallback());
        end

        function createResultSection(app, parent)
            % Middle column upper block: the screening result fields
            muted = [0.63 0.65 0.70];
            rowLabel('DR Severity:', 646);
            app.SeverityValue = rowValue([150 644 294 22]);
            rowLabel('ICDR Grade:', 610);
            app.IcdrValue = rowValue([150 608 294 22]);
            rowLabel('Referable DR:', 574);
            app.ReferableValue = rowValue([150 572 294 22]);
            rowLabel('Model Score:', 538);
            app.ScoreValue = rowValue([150 536 294 22]);

            function rowLabel(txt, y)
                uilabel(parent, 'Text', txt, ...
                    'Position', [16 y 130 18], ...
                    'FontSize', 11, 'FontColor', muted, ...
                    'BackgroundColor', [0.13 0.14 0.17], ...
                    'HorizontalAlignment', 'left');
            end
            function v = rowValue(pos)
                v = uilabel(parent, ...
                    'Position', pos, ...
                    'FontSize', 13, 'FontWeight', 'bold', ...
                    'FontColor', [0.95 0.96 0.97], ...
                    'BackgroundColor', [0.13 0.14 0.17], ...
                    'HorizontalAlignment', 'left');
            end

            uilabel(parent, 'Text', 'Advice:', ...
                'Position', [16 498 130 18], ...
                'FontSize', 11, 'FontColor', muted, ...
                'BackgroundColor', [0.13 0.14 0.17], ...
                'HorizontalAlignment', 'left');

            app.AdviceBox = uilabel(parent, ...
                'Text', 'Run an analysis to see the screening advice', ...
                'Position', [16 388 428 100], ...
                'FontSize', 12, 'FontWeight', 'bold', ...
                'FontColor', [0.55 0.57 0.60], ...
                'BackgroundColor', [0.11 0.12 0.15], ...
                'HorizontalAlignment', 'center', ...
                'VerticalAlignment', 'center', ...
                'WordWrap', 'on');

            app.ModelInfoLabel = uilabel(parent, ...
                'Text', 'Awaiting analysis', ...
                'Position', [16 358 428 18], ...
                'FontSize', 9, 'FontColor', muted, ...
                'BackgroundColor', [0.13 0.14 0.17], ...
                'HorizontalAlignment', 'left');
        end

        function createQualitySection(app, parent)
            % Middle column lower block: image quality vs prototype thresholds
            app.QualityPanel = uipanel(parent, ...
                'Title', ' IMAGE QUALITY (prototype thresholds) ', ...
                'FontSize', 10, 'FontWeight', 'bold', ...
                'ForegroundColor', [0.90 0.92 0.95], ...
                'BackgroundColor', [0.13 0.14 0.17], ...
                'BorderColor', [0.45 0.47 0.50], ...
                'Position', [8 12 444 334]);

            muted = [0.63 0.65 0.70];
            qLabel('Focus', 286);
            app.FocusValue = qValue([16 262 350 20]);
            app.FocusCheck = qCheck([400 262 28 20]);
            qLabel('Illumination', 230);
            app.IllumValue = qValue([16 206 350 20]);
            app.IllumCheck = qCheck([400 206 28 20]);
            qLabel('FOV', 174);
            app.FovValue = qValue([16 150 350 20]);
            app.FovCheck = qCheck([400 150 28 20]);
            qLabel('Overall:', 102);
            app.OverallValue = uilabel(app.QualityPanel, ...
                'Text', '—', ...
                'Position', [100 100 328 20], ...
                'FontSize', 10, 'FontColor', muted, ...
                'BackgroundColor', [0.13 0.14 0.17], ...
                'HorizontalAlignment', 'left');
            qLabel('Enhancement:', 62);
            app.EnhanceLabel = uilabel(app.QualityPanel, ...
                'Text', '—', ...
                'Position', [130 60 298 20], ...
                'FontSize', 10, 'FontColor', muted, ...
                'BackgroundColor', [0.13 0.14 0.17], ...
                'HorizontalAlignment', 'left');

            % Hidden judge-terms badge (headless-verification contract).
            app.QualityBadge = uilabel(app.QualityPanel, ...
                'Text', '', ...
                'Position', [396 8 36 16], ...
                'FontSize', 8, ...
                'Visible', 'off');

            function qLabel(txt, y)
                uilabel(app.QualityPanel, 'Text', txt, ...
                    'Position', [16 y 110 16], ...
                    'FontSize', 11, 'FontColor', muted, ...
                    'BackgroundColor', [0.13 0.14 0.17], ...
                    'HorizontalAlignment', 'left');
            end
            function v = qValue(pos)
                v = uilabel(app.QualityPanel, ...
                    'Position', pos, ...
                    'FontSize', 12, 'FontWeight', 'bold', ...
                    'FontColor', [0.95 0.96 0.97], ...
                    'BackgroundColor', [0.13 0.14 0.17], ...
                    'HorizontalAlignment', 'left');
            end
            function c = qCheck(pos)
                c = uilabel(app.QualityPanel, ...
                    'Position', pos, ...
                    'FontSize', 12, 'FontWeight', 'bold', ...
                    'FontColor', [0.20 0.78 0.35], ...
                    'BackgroundColor', [0.13 0.14 0.17], ...
                    'HorizontalAlignment', 'center');
            end
        end

        function createGradCAMSection(app, parent)
            % Right column top: 2x2 view switcher + attention visualization
            app.ViewButtons = gobjects(1, 4);
            viewNames = {'Original', 'Enhanced', 'Grad-CAM', 'Overlay'};
            viewPos = {[16 632 108 34], [132 632 108 34], ...
                       [16 590 108 34], [132 590 108 34]};
            for vi = 1:4
                app.ViewButtons(vi) = uibutton(parent, 'push', ...
                    'Text', viewNames{vi}, ...
                    'Position', viewPos{vi}, ...
                    'FontSize', 10, ...
                    'BackgroundColor', [0.20 0.22 0.26], ...
                    'FontColor', [0.63 0.65 0.70], ...
                    'ButtonPushedFcn', @(src, ~) app.showView(char(src.Text)));
            end

            app.VizTitle = uilabel(parent, ...
                'Text', 'Fundus + Grad-CAM Overlay', ...
                'Position', [0 548 472 22], ...
                'FontSize', 11, 'FontWeight', 'bold', ...
                'FontColor', [0.90 0.92 0.95], ...
                'BackgroundColor', [0.13 0.14 0.17], ...
                'HorizontalAlignment', 'center');

            app.GradCAMAxes = uiaxes(parent, ...
                'Position', [16 122 396 404], ...
                'XTick', [], 'YTick', [], ...
                'Toolbar', [], ...
                'Box', 'off', ...
                'BackgroundColor', [0.07 0.08 0.10]);
            text(app.GradCAMAxes, 0.5, 0.5, 'Awaiting analysis', ...
                'Units', 'normalized', ...
                'HorizontalAlignment', 'center', ...
                'FontSize', 11, ...
                'Color', [0.55 0.57 0.60]);

            % Vertical 0 -> 1 heatmap color scale (jet, red = 1 on top)
            app.ColorbarAxes = uiaxes(parent, ...
                'Position', [424 122 16 404], ...
                'XTick', [], 'YTick', [], ...
                'Toolbar', [], ...
                'Box', 'off', ...
                'BackgroundColor', [0.07 0.08 0.10]);
            stripImg = repmat(reshape(flipud(jet(256)), [256 1 3]), [1 1 1]);
            image(app.ColorbarAxes, stripImg);
            app.ColorbarAxes.YDir = 'reverse';
            app.ColorbarAxes.XLim = [0.5 1.5];
            app.ColorbarAxes.YLim = [0.5 256.5];

            uilabel(parent, 'Text', '1', ...
                'Position', [406 528 44 14], ...
                'FontSize', 9, 'FontColor', [0.63 0.65 0.70], ...
                'BackgroundColor', [0.13 0.14 0.17], ...
                'HorizontalAlignment', 'center');
            uilabel(parent, 'Text', '0', ...
                'Position', [406 104 44 14], ...
                'FontSize', 9, 'FontColor', [0.63 0.65 0.70], ...
                'BackgroundColor', [0.13 0.14 0.17], ...
                'HorizontalAlignment', 'center');

            uilabel(parent, ...
                'Text', 'Model attention visualization — not validated lesion localization.', ...
                'Position', [16 84 440 16], ...
                'FontSize', 9, ...
                'FontColor', [0.63 0.65 0.70], ...
                'BackgroundColor', [0.13 0.14 0.17], ...
                'HorizontalAlignment', 'left');
        end

        function createReportSection(app, parent)
            % Right column bottom: green report action. The original
            % Save Report / Copy / Save PDF callbacks are preserved on
            % hidden controls + the kebab menu (headless-verified).
            app.GenerateReportBtn = uibutton(parent, 'push', ...
                'Text', 'Generate Screening Report', ...
                'Position', [16 12 440 48], ...
                'FontSize', 13, 'FontWeight', 'bold', ...
                'BackgroundColor', [0.13 0.60 0.28], ...
                'FontColor', [1 1 1], ...
                'ButtonPushedFcn', @(~,~) app.savePdfReportCallback());

            app.ReportTextArea = uitextarea(parent, ...
                'Position', [16 160 440 60], ...
                'FontSize', 10, 'FontName', 'Consolas', ...
                'Editable', 'off', ...
                'Visible', 'off', ...
                'Value', {'Analysis report will appear here.'});

            app.PdfEngineLabel = uilabel(parent, ...
                'Text', 'PDF engine: auto', ...
                'Position', [16 64 440 16], ...
                'FontSize', 9, 'FontWeight', 'bold', ...
                'HorizontalAlignment', 'right', ...
                'VerticalAlignment', 'center', ...
                'FontColor', [0.55 0.60 0.65], ...
                'BackgroundColor', [0.93 0.94 0.96], ...
                'Visible', 'off');

            app.CopyReportBtn = uibutton(parent, 'push', ...
                'Text', 'Copy to Clipboard', ...
                'Position', [16 240 100 20], ...
                'FontSize', 10, ...
                'Visible', 'off', ...
                'ButtonPushedFcn', @(~,~) app.copyReportCallback());

            app.PdfReportBtn = uibutton(parent, 'push', ...
                'Text', 'Save PDF Report', ...
                'Position', [124 240 100 20], ...
                'FontSize', 10, ...
                'Visible', 'off', ...
                'ButtonPushedFcn', @(~,~) app.savePdfReportCallback());
        end

        function loadSampleList(app)
            valDir = fullfile(app.ProjectRoot, 'data', 'splits', 'val');
            items = {'(no samples)'};
            paths = {};
            if exist(valDir, 'dir')
                classes = {'class_0', 'class_1', 'class_2', 'class_3', 'class_4'};
                labels = {'NoDR', 'Mild', 'Moderate', 'Severe', 'Prolif'};
                for c = 1:numel(classes)
                    d = dir(fullfile(valDir, classes{c}, '*.png'));
                    for i = 1:min(3, numel(d))
                        items{end+1} = sprintf('%s/%s (%s)', classes{c}, d(i).name, labels{c}); %#ok<AGROW>
                        paths{end+1} = fullfile(valDir, classes{c}, d(i).name); %#ok<AGROW>
                    end
                end
            end
            app.SampleDropdown.Items = items;
            app.SampleItems = items;
            app.SamplePaths = paths;
            app.buildKebabMenu();
        end

        function buildKebabMenu(app)
            % Three-dot menu: sample picker + the preserved report actions
            % (Save TXT / Copy to Clipboard / Save PDF).
            app.KebabMenu = uicontextmenu(app.UIFigure);
            samplesMenu = uimenu(app.KebabMenu, 'Text', 'Open sample image');
            if isempty(app.SamplePaths)
                uimenu(samplesMenu, 'Text', '(no samples)', 'Enable', 'off');
            else
                for k = 1:numel(app.SamplePaths)
                    uimenu(samplesMenu, 'Text', app.SampleItems{k + 1}, ...
                        'MenuSelectedFcn', @(~,~) app.selectSample(k));
                end
            end
            uimenu(app.KebabMenu, 'Text', 'Save Report as Text', ...
                'MenuSelectedFcn', @(~,~) app.saveReportCallback());
            uimenu(app.KebabMenu, 'Text', 'Copy Report to Clipboard', ...
                'MenuSelectedFcn', @(~,~) app.copyReportCallback());
            uimenu(app.KebabMenu, 'Text', 'Save PDF Report', ...
                'MenuSelectedFcn', @(~,~) app.savePdfReportCallback());
            app.MenuBtn.ContextMenu = app.KebabMenu;
        end

        function menuButtonCallback(app)
            % Left-click on the kebab indicator opens the sample chooser
            % (the same menu is available via right-click > Open sample image).
            if isempty(app.SamplePaths)
                app.setStatus('No samples available.', 'err');
                return;
            end
            sel = listdlg('PromptString', 'Select a sample fundus image:', ...
                'ListString', app.SampleItems(2:end), ...
                'SelectionMode', 'single', ...
                'Name', 'DRISHTI sample images');
            if isempty(sel)
                return;
            end
            app.selectSample(sel(1));
        end

        function selectSample(app, idx)
            if idx < 1 || idx > numel(app.SamplePaths)
                return;
            end
            app.SuspendSampleCallback = true;
            try
                app.SampleDropdown.Value = app.SampleItems{idx + 1};
            catch
            end
            app.SuspendSampleCallback = false;
            app.CurrentImagePath = app.SamplePaths{idx};
            showImage(app, app.CurrentImagePath);
            app.AnalyzeButton.Enable = 'on';
            [~, fname] = fileparts(app.SamplePaths{idx});
            app.FilenameLabel.Text = fname;
            app.setStatus(sprintf('Loaded: %s', fname), 'ok');
        end

        function uploadCallback(app)
            [file, path] = uigetfile({'*.png;*.jpg;*.jpeg', 'Fundus images'}, 'Select a fundus image');
            if isequal(file, 0)
                return;
            end
            app.CurrentImagePath = fullfile(path, file);
            showImage(app, app.CurrentImagePath);
            app.AnalyzeButton.Enable = 'on';
            app.FilenameLabel.Text = file;
            app.setStatus(sprintf('Loaded: %s', file), 'ok');
        end

        function sampleCallback(app)
            if app.SuspendSampleCallback
                return;
            end
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
                app.FilenameLabel.Text = fileName;
                app.setStatus(sprintf('Loaded: %s', fileName), 'ok');
            else
                app.setStatus('Sample file not found.', 'err');
            end
        end

        function showImage(app, imgPath)
            try
                img = imread(imgPath);
                imshow(img, 'Parent', app.ImageAxes);
                title(app.ImageAxes, '');
            catch
                app.setStatus('Failed to load image.', 'err');
            end
        end

        function analyzeCallback(app)
            if isempty(app.CurrentImagePath) || ~exist(app.CurrentImagePath, 'file')
                app.setStatus('No valid image selected.', 'err');
                return;
            end

            app.AnalyzeButton.Enable = 'off';
            app.setStatus('Analyzing...', 'busy');
            drawnow;

            try
                result = predictSingleFundus(app.CurrentImagePath, ...
                    'ShowFigure', false, 'RunLesions', true, ...
                    'RunBranchB', true, 'SkipModelOnFail', true);
                app.CurrentResult = result;
                cacheViews(app, result);
                displayResults(app, result);
                app.setStatus('System Ready', 'ok');
            catch e
                app.setStatus(sprintf('Error: %s', e.message), 'err');
            end

            app.AnalyzeButton.Enable = 'on';
        end

        function setStatus(app, txt, kind)
            % Header status: text + colored system indicator dot.
            app.StatusLabel.Text = txt;
            switch kind
                case 'ok',   app.StatusDot.FontColor = [0.20 0.78 0.35];
                case 'busy', app.StatusDot.FontColor = [0.90 0.66 0.18];
                case 'err',  app.StatusDot.FontColor = [0.88 0.30 0.28];
                otherwise,   app.StatusDot.FontColor = [0.20 0.78 0.35];
            end
        end

        function displayResults(app, r)
            % Per-metric quality readout uses the SAME Day-3 quality module
            % on the SAME raw image the pipeline assessed (deterministic).
            [qres, qmet] = app.assessQualityForDisplay();
            displayQualityRows(app, r, qres, qmet);
            if isfield(r, 'binaryDecision') && startsWith(r.binaryDecision, 'WITHHELD')
                displayWithheld(app, r, qres);
                return;
            end
            displayGradeRows(app, r);
            displayAdvice(app, r);
            updateModelInfoLine(app, r);
            showView(app, 'Overlay');
            displayReport(app, r);
        end

        function [qres, qmet] = assessQualityForDisplay(app)
            qres = struct('overall', '', 'checks', {});
            qmet = struct();
            try
                if ~isempty(app.ViewOriginal)
                    raw = app.ViewOriginal;
                else
                    raw = imread(app.CurrentImagePath);
                end
                [qres, qmet] = assessImageQuality(raw);
            catch
            end
        end

        function t = qualityJudgeTerm(~, status)
            switch status
                case 'PASS',    t = 'ACCEPT (PASS)';
                case 'WARNING', t = 'BORDERLINE (WARNING)';
                case 'FAIL',    t = 'REJECT (FAIL)';
                otherwise,      t = status;
            end
        end

        function st = checkStatusFor(~, qres, metricName)
            st = '';
            for k = 1:numel(qres.checks)
                if strcmp(qres.checks(k).metric, metricName)
                    st = qres.checks(k).status;
                    return;
                end
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
            switch name
                case 'Original', app.VizTitle.Text = 'Fundus Image';
                case 'Enhanced', app.VizTitle.Text = 'Enhanced Fundus';
                case 'Grad-CAM', app.VizTitle.Text = 'Grad-CAM Attention Map';
                otherwise,       app.VizTitle.Text = 'Fundus + Grad-CAM Overlay';
            end
            % selected view is highlighted blue, the rest stay neutral
            for vi = 1:numel(app.ViewButtons)
                if strcmp(app.ViewButtons(vi).Text, name)
                    app.ViewButtons(vi).BackgroundColor = [0.16 0.42 0.86];
                    app.ViewButtons(vi).FontColor = [1 1 1];
                else
                    app.ViewButtons(vi).BackgroundColor = [0.20 0.22 0.26];
                    app.ViewButtons(vi).FontColor = [0.63 0.65 0.70];
                end
            end
            if isempty(img)
                cla(app.GradCAMAxes);
                text(app.GradCAMAxes, 0.5, 0.5, [name ' view unavailable'], ...
                    'Units', 'normalized', 'HorizontalAlignment', 'center', ...
                    'FontSize', 11, 'Color', [0.55 0.57 0.60]);
            else
                imshow(img, 'Parent', app.GradCAMAxes);
                title(app.GradCAMAxes, '');
            end
        end

        function displayWithheld(app, r, qres)
            if nargin < 3
                qres = struct('overall', '', 'checks', {});
            end
            app.SeverityValue.Text = '—';
            app.IcdrValue.Text = '— / 4';
            app.ReferableValue.Text = '—';
            app.ReferableValue.FontColor = [0.63 0.65 0.70];
            app.ScoreValue.Text = '—';
            app.setAdviceBox('REVIEW BY HEALTHCARE PROFESSIONAL', 'warn');
            app.ModelInfoLabel.Text = 'Margin — · — · TTA off · SO n/a';
            cla(app.GradCAMAxes);
            text(app.GradCAMAxes, 0.5, 0.5, 'No Grad-CAM: analysis withheld (quality FAIL)', ...
                'Units', 'normalized', 'HorizontalAlignment', 'center', ...
                'FontSize', 11, 'Color', [0.55 0.57 0.60]);
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
            lines{end+1} = 'AI GRADING: SKIPPED (model stack not executed)';
            lines{end+1} = '';
            lines{end+1} = 'Threshold detail:';
            try
                det = quality_failure_detail(qres.checks);
                if isempty(det)
                    lines{end+1} = ' - (no per-metric detail available)';
                end
                for k = 1:numel(det)
                    if isfinite(det(k).threshold)
                        lines{end+1} = sprintf(' - %s = %.4g  (bound %s = %.4g)', ...
                            det(k).metric, det(k).value, det(k).bound, det(k).threshold);
                    else
                        lines{end+1} = sprintf(' - %s: %s', det(k).metric, det(k).status);
                    end
                end
            catch
                lines{end+1} = ' - (no per-metric detail available)';
            end
            lines{end+1} = '';
            lines{end+1} = ['Recapture advice: ' r.qualityRecaptureAdvice];
            lines{end+1} = '';
            lines{end+1} = 'ENGINEERING DEMO - NOT a clinical device.';
            app.ReportTextArea.Value = lines;
        end

        function displayQualityRows(app, r, qres, qmet)
            status = r.qualityStatus;
            % judge-terms badge (hidden; headless verification contract)
            app.QualityBadge.Text = app.qualityJudgeTerm(status);

            % per-metric statuses from the same quality module
            focusStatus    = app.checkStatusFor(qres, 'focus');
            brightStatus   = app.checkStatusFor(qres, 'brightness');
            contrastStatus = app.checkStatusFor(qres, 'contrast');
            fgStatus       = app.checkStatusFor(qres, 'foreground');

            app.FocusValue.Text = sprintf('%.4f', qmet.focusScore);
            setCheckMark(app.FocusCheck, focusStatus);

            app.IllumValue.Text = sprintf('%.3f (sd %.3f)', qmet.brightness, qmet.contrast);
            setCheckMark(app.IllumCheck, worstStatus(brightStatus, contrastStatus));

            if isfield(qmet, 'foregroundFrac') && isfinite(qmet.foregroundFrac)
                app.FovValue.Text = sprintf('%.1f%%', qmet.foregroundFrac * 100);
            else
                app.FovValue.Text = '—';
            end
            setCheckMark(app.FovCheck, fgStatus);

            % Overall line (prototype thresholds)
            reason = '';
            if isfield(r, 'qualityFailureReasons') && ~isempty(r.qualityFailureReasons)
                reason = r.qualityFailureReasons{1};
            end
            if isempty(reason)
                % WARNING-only images have no failure reasons; use the first
                % non-PASS check message from the same quality module.
                for k = 1:numel(qres.checks)
                    if ~strcmp(qres.checks(k).status, 'PASS')
                        reason = qres.checks(k).message;
                        break;
                    end
                end
            end
            switch status
                case 'PASS'
                    app.OverallValue.Text = 'ACCEPT — Image quality is acceptable.';
                    app.OverallValue.FontColor = [0.42 0.86 0.52];
                case 'WARNING'
                    app.OverallValue.Text = ['BORDERLINE — ' reason];
                    app.OverallValue.FontColor = [0.98 0.78 0.35];
                otherwise
                    app.OverallValue.Text = ['REJECT — ' reason];
                    app.OverallValue.FontColor = [0.98 0.48 0.45];
            end

            % Enhancement (Day-4 module is display-only; model input unchanged)
            switch status
                case 'PASS'
                    app.EnhanceLabel.Text = 'Not needed';
                case 'WARNING'
                    app.EnhanceLabel.Text = 'Applied (display aid — model input unchanged)';
                otherwise
                    app.EnhanceLabel.Text = '—';
            end
            app.EnhanceLabel.FontColor = [0.63 0.65 0.70];
        end

        function displayGradeRows(app, r)
            app.SeverityValue.Text = r.gradeLabel;
            app.IcdrValue.Text = sprintf('%d / 4', r.grade);

            if strcmp(r.binaryDecision, 'REFERABLE')
                app.ReferableValue.Text = 'YES';
                app.ReferableValue.FontColor = [0.98 0.48 0.45];
            else
                app.ReferableValue.Text = 'NO';
                app.ReferableValue.FontColor = [0.42 0.86 0.52];
            end

            % Model score: referable probability from the binary screening
            % model (consistent with the Referable DR decision + margin line)
            app.ScoreValue.Text = sprintf('%.2f%%', r.binaryProbability * 100);
        end

        function updateModelInfoLine(app, r)
            % Margin: distance between the two binary screening outcomes in
            % percentage points (|P(non-ref) - P(ref)|).
            marginPP = abs(1 - 2 * r.binaryProbability) * 100;

            conf = r.confidence;
            if conf >= 0.75        % == cascade reviewConf: confident route
                confLevel = 'high';
            elseif conf >= 0.50    % == cascade abstainConf
                confLevel = 'medium';
            else
                confLevel = 'low';
            end

            soText = 'n/a';
            if isfield(r, 'fusion') && r.fusion.available
                if r.fusion.discrepancy
                    soText = 'DISCREPANCY';
                elseif r.fusion.agree
                    soText = 'agree';
                else
                    soText = sprintf('%.0f%%', r.fusion.branchB * 100);
                end
            end

            % TTA (test-time augmentation) is not used anywhere in this
            % pipeline, so the honest value is 'off'.
            app.ModelInfoLabel.Text = sprintf('Margin %.1fpp · %s · TTA off · SO %s', ...
                marginPP, confLevel, soText);
        end

        function displayAdvice(app, r)
            % Same referral logic as the pipeline cascade: referable grades
            % refer; cascade REVIEW/ABSTAIN or an enforced quality gate goes
            % to a healthcare professional; everything else is routine.
            if r.qualityGate.enforced
                app.setAdviceBox('REVIEW BY HEALTHCARE PROFESSIONAL', 'warn');
            elseif r.grade >= 3
                app.setAdviceBox('REFER FOR OPHTHALMOLOGIST REVIEW', 'ref');
            elseif r.grade == 2 || strcmp(r.binaryDecision, 'REFERABLE')
                app.setAdviceBox('REFER FOR OPHTHALMOLOGIST REVIEW', 'ref');
            elseif strcmp(r.cascade.route, 'REVIEW') || strcmp(r.cascade.route, 'ABSTAIN')
                app.setAdviceBox('REVIEW BY HEALTHCARE PROFESSIONAL', 'warn');
            else
                app.setAdviceBox('NO IMMEDIATE REFERRAL - ROUTINE SCREENING', 'ok');
            end
        end

        function setAdviceBox(app, txt, tone)
            app.AdviceBox.Text = txt;
            switch tone
                case 'ok'    % non-referable: light green
                    app.AdviceBox.BackgroundColor = [0.16 0.33 0.21];
                    app.AdviceBox.FontColor = [0.78 0.96 0.80];
                case 'ref'   % referable: light red/pink
                    app.AdviceBox.BackgroundColor = [0.38 0.16 0.17];
                    app.AdviceBox.FontColor = [1.00 0.78 0.78];
                otherwise    % uncertain / review: amber
                    app.AdviceBox.BackgroundColor = [0.40 0.30 0.10];
                    app.AdviceBox.FontColor = [1.00 0.90 0.65];
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

% -------------------------------------------------------------------------
function setCheckMark(lbl, status)
%SETCHECKMARK Render the per-metric quality mark (PASS/WARNING/FAIL).
    switch status
        case 'PASS'
            lbl.Text = char(10003);   % check mark
            lbl.FontColor = [0.20 0.78 0.35];
        case 'WARNING'
            lbl.Text = '!';
            lbl.FontColor = [0.90 0.66 0.18];
        case 'FAIL'
            lbl.Text = char(10007);   % ballot X
            lbl.FontColor = [0.88 0.30 0.28];
        otherwise
            lbl.Text = '—';
            lbl.FontColor = [0.63 0.65 0.70];
    end
end

% -------------------------------------------------------------------------
function st = worstStatus(a, b)
%WORSTSTATUS Aggregate two check statuses (FAIL > WARNING > PASS > ...).
    ra = statusRank(a); rb = statusRank(b);
    if ra >= rb
        st = a;
    else
        st = b;
    end
end

function r = statusRank(s)
    switch s
        case 'FAIL',    r = 3;
        case 'WARNING', r = 2;
        case 'PASS',    r = 1;
        otherwise,      r = 0;
    end
end