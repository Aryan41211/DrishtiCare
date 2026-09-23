classdef RetinaAIApp < matlab.apps.AppBase
%RETINAAIAPP DRISHTI single-image DR screening demo for DrishtiCare.
%   RetinaAIApp()
%
%   App Designer-style application (programmatic, convertible to .mlapp)
%   that wraps predictSingleFundus() with a professional medical-AI layout:
%
%     [ RETINAL IMAGE ] | [ AI SCREENING RESULT ] | [ VISUAL EVIDENCE ]
%     [ --------------- IMAGE QUALITY | PIPELINE STATUS | REPORT ------ ]
%
%   pipeline: image -> quality gate -> DR grade -> Grad-CAM -> report.
%
%   The full decision logic, quality thresholds and referral rules are the
%   EXISTING pipeline outputs; this class only owns PRESENTATION. All
%   colors / typography / Grad-CAM rendering live in src/ui (drishtiTheme,
%   renderGradCAMViews) and are shared with the PDF report.
%
%   ENGINEERING demo tool. NOT a clinical device.

    properties (Access = public)
        UIFigure           matlab.ui.Figure
    end

    properties (Access = private)
        ProjectRoot        char
        CurrentImagePath   char
        CurrentResult      struct
        ImageRawSize       double = [0 0]
        LastQualityStatus  char = ''

        % ---- layout containers -------------------------------------------
        HeaderPanel        matlab.ui.container.Panel
        LeftPanel          matlab.ui.container.Panel
        MiddlePanel        matlab.ui.container.Panel
        RightPanel         matlab.ui.container.Panel
        BottomBar          matlab.ui.container.Panel

        % ---- header -------------------------------------------------------
        EngTag             matlab.ui.control.Label
        StatusDot          matlab.ui.control.Label
        StatusLabel        matlab.ui.control.Label

        % ---- left panel: retinal image ------------------------------------
        FilenameLabel      matlab.ui.control.Label
        MenuBtn            matlab.ui.control.Button
        ImageAxes          matlab.ui.control.UIAxes
        MetaLabel          matlab.ui.control.Label
        UploadButton       matlab.ui.control.Button
        SampleDropdown     matlab.ui.control.DropDown
        AnalyzeButton      matlab.ui.control.Button

        % ---- center panel: AI screening result ----------------------------
        SeverityValue      matlab.ui.control.Label
        IcdrValue          matlab.ui.control.Label
        ReferralPanel      matlab.ui.container.Panel
        ReferralDot        matlab.ui.control.Label
        ReferableValue     matlab.ui.control.Label
        ReferralNote       matlab.ui.control.Label
        ConfidenceBar      matlab.ui.control.Label
        ConfChip           matlab.ui.control.Label
        ScoreValue         matlab.ui.control.Label
        ModelInfoLabel     matlab.ui.control.Label
        AdviceBox          matlab.ui.control.Label

        % ---- bottom bar: image quality ------------------------------------
        FocusCard          matlab.ui.container.Panel
        FocusValue         matlab.ui.control.Label
        FocusCheck         matlab.ui.control.Label
        IllumCard          matlab.ui.container.Panel
        IllumValue         matlab.ui.control.Label
        IllumCheck         matlab.ui.control.Label
        FovCard            matlab.ui.container.Panel
        FovValue           matlab.ui.control.Label
        FovCheck           matlab.ui.control.Label
        OverallChip        matlab.ui.container.Panel
        OverallValue       matlab.ui.control.Label
        EnhanceLabel       matlab.ui.control.Label
        QualityReasonLabel matlab.ui.control.Label
        QualityBadge       matlab.ui.control.Label

        % ---- bottom bar: pipeline status ----------------------------------
        PipelineChips
        PipelineDots
        PipelineNames

        % ---- right panel: visual evidence ---------------------------------
        VizTitle           matlab.ui.control.Label
        ViewOriginal
        ViewEnhanced
        ViewHeatmap
        ViewOverlay
        ViewButtons
        GradCAMAxes        matlab.ui.control.UIAxes
        ColorbarAxes       matlab.ui.control.UIAxes
        DisclaimerLabel    matlab.ui.control.Label

        % ---- report -------------------------------------------------------
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
            % Window: presentation-sized, fixed layout. Deep-navy theme.
            th = drishtiTheme();
            app.UIFigure = uifigure('Name', 'DRISHTI - Explainable AI for DR Screening', ...
                'Position', [40 8 1360 760], ...
                'Color', th.background, ...
                'Resize', 'off');

            createHeader(app);
            createImageSection(app);
            createResultSection(app);
            createEvidenceSection(app);
            createBottomBar(app);
            createFooter(app);
            app.setStatus('System Ready', 'ok');
            app.setPipelineState('idle');
        end

        function createHeader(app)
            th = drishtiTheme();
            app.HeaderPanel = uipanel(app.UIFigure, ...
                'Position', [0 716 1360 44], ...
                'BackgroundColor', th.panelDeep, ...
                'BorderType', 'line', 'BorderColor', th.border, 'BorderWidth', 1);

            uilabel(app.HeaderPanel, 'Text', 'DRISHTI', ...
                'Position', [16 23 170 20], ...
                'FontSize', th.type.appTitle, 'FontWeight', 'bold', ...
                'FontColor', th.text, 'HorizontalAlignment', 'left');

            uilabel(app.HeaderPanel, 'Text', ...
                'Explainable AI for Diabetic Retinopathy Screening', ...
                'Position', [18 5 540 14], ...
                'FontSize', th.type.labelSmall, ...
                'FontColor', th.textMuted, 'HorizontalAlignment', 'left');

            uipanel(app.HeaderPanel, ...
                'Position', [596 8 1 30], ...
                'BackgroundColor', th.borderLight, 'BorderType', 'none');

            app.EngTag = uilabel(app.HeaderPanel, ...
                'Text', 'ENGINEERING PROTOTYPE  ·  NOT A CLINICAL DEVICE', ...
                'Position', [620 24 460 14], ...
                'FontSize', th.type.labelSmall, ...
                'FontColor', th.textFaint, 'HorizontalAlignment', 'right');

            app.StatusDot = uilabel(app.HeaderPanel, ...
                'Text', char(9679), ...
                'Position', [1150 20 16 20], ...
                'FontSize', 15, 'FontColor', th.success, ...
                'BackgroundColor', th.panelDeep);

            app.StatusLabel = uilabel(app.HeaderPanel, ...
                'Text', 'System Ready', ...
                'Position', [1170 20 176 20], ...
                'FontSize', th.type.label, 'FontColor', th.text, ...
                'BackgroundColor', th.panelDeep);
        end

        function createImageSection(app)
            % Left column: RETINAL IMAGE - metadata row, fundus preview,
            % resolution line, and the primary Upload / Analyze actions.
            th = drishtiTheme();
            app.LeftPanel = uipanel(app.UIFigure, ...
                'Title', ' RETINAL IMAGE ', ...
                'FontSize', th.type.sectionTitle, 'FontWeight', 'bold', ...
                'ForegroundColor', th.textMuted, ...
                'BackgroundColor', th.panel, ...
                'BorderType', 'line', 'BorderColor', th.border, ...
                'Position', [8 144 330 564]);

            app.FilenameLabel = uilabel(app.LeftPanel, ...
                'Text', 'Image ID : —', ...
                'Position', [16 530 272 20], ...
                'FontSize', th.type.label, 'FontColor', th.textMuted, ...
                'BackgroundColor', th.panel, ...
                'HorizontalAlignment', 'left');

            app.MenuBtn = uibutton(app.LeftPanel, 'push', ...
                'Text', char(8943), ...
                'Position', [298 532 18 20], ...
                'FontSize', th.type.label, 'FontWeight', 'bold', ...
                'BackgroundColor', th.panel, ...
                'FontColor', th.textFaint, ...
                'ButtonPushedFcn', @(~,~) app.menuButtonCallback());

            app.ImageAxes = uiaxes(app.LeftPanel, ...
                'Position', [16 136 298 388], ...
                'Box', 'off', ...
                'XTick', [], 'YTick', [], ...
                'Toolbar', [], ...
                'BackgroundColor', th.panelDeep);
            texto = text(app.ImageAxes, 0.5, 0.5, 'No image selected', ...
                'Units', 'normalized', ...
                'HorizontalAlignment', 'center', ...
                'FontSize', th.type.value, ...
                'Color', th.textFaint);

            app.MetaLabel = uilabel(app.LeftPanel, ...
                'Text', 'Resolution: —  ·  Quality: —', ...
                'Position', [16 112 298 18], ...
                'FontSize', th.type.labelSmall, 'FontColor', th.textMuted, ...
                'BackgroundColor', th.panel, ...
                'HorizontalAlignment', 'left');

            app.UploadButton = uibutton(app.LeftPanel, 'push', ...
                'Text', 'Upload Image', ...
                'Position', [16 48 144 46], ...
                'FontSize', th.type.label, ...
                'BackgroundColor', th.panelAlt, ...
                'FontColor', th.text, ...
                'ButtonPushedFcn', @(~,~) app.uploadCallback());

            app.AnalyzeButton = uibutton(app.LeftPanel, 'push', ...
                'Text', 'ANALYZE IMAGE', ...
                'Position', [168 48 144 46], ...
                'FontSize', th.type.value, ...
                'FontWeight', 'bold', ...
                'BackgroundColor', th.primary, ...
                'FontColor', [1 1 1], ...
                'Enable', 'off', ...
                'ButtonPushedFcn', @(~,~) app.analyzeCallback());

            app.SampleDropdown = uidropdown(app.LeftPanel, ...
                'Items', {'(no samples)'}, ...
                'Position', [16 8 100 22], ...
                'FontSize', 11, ...
                'Visible', 'off', ...
                'ValueChangedFcn', @(~,~) app.sampleCallback());
        end

        function createResultSection(app)
            % Center column: AI SCREENING RESULT - severity, ICDR grade,
            % referral status card, confidence bar, score, advice card.
            th = drishtiTheme();
            app.MiddlePanel = uipanel(app.UIFigure, ...
                'Title', ' AI SCREENING RESULT ', ...
                'FontSize', th.type.sectionTitle, 'FontWeight', 'bold', ...
                'ForegroundColor', th.textMuted, ...
                'BackgroundColor', th.panel, ...
                'BorderType', 'line', 'BorderColor', th.border, ...
                'Position', [346 144 420 564]);

            secLabel('DR SEVERITY', [16 528 388 14]);
            app.SeverityValue = uilabel(app.MiddlePanel, ...
                'Text', '—', ...
                'Position', [16 502 388 26], ...
                'FontSize', th.type.valueLarge, 'FontWeight', 'bold', ...
                'FontColor', th.text, 'BackgroundColor', th.panel, ...
                'HorizontalAlignment', 'left', 'VerticalAlignment', 'bottom');

            secLabel('ICDR GRADE', [16 466 388 14]);
            app.IcdrValue = uilabel(app.MiddlePanel, ...
                'Text', '— / 4', ...
                'Position', [16 440 388 22], ...
                'FontSize', th.type.value, 'FontWeight', 'bold', ...
                'FontColor', th.text, 'BackgroundColor', th.panel, ...
                'HorizontalAlignment', 'left', 'VerticalAlignment', 'bottom');

            app.ReferralPanel = uipanel(app.MiddlePanel, ...
                'Position', [16 348 388 84], ...
                'BackgroundColor', th.panelAlt, ...
                'BorderType', 'line', 'BorderColor', th.borderLight, 'BorderWidth', 1);
            uilabel(app.ReferralPanel, 'Text', 'REFERRAL STATUS', ...
                'Position', [20 62 220 13], ...
                'FontSize', th.type.labelSmall, 'FontWeight', 'bold', ...
                'FontColor', th.textMuted, ...
                'BackgroundColor', th.panelAlt);
            app.ReferralDot = uilabel(app.ReferralPanel, ...
                'Text', char(9679), ...
                'Position', [20 36 16 24], ...
                'FontSize', th.type.valueHero, ...
                'FontColor', th.textFaint, ...
                'BackgroundColor', th.panelAlt, ...
                'HorizontalAlignment', 'center');
            app.ReferableValue = uilabel(app.ReferralPanel, ...
                'Text', '—', ...
                'Position', [42 32 250 30], ...
                'FontSize', th.type.valueHero, 'FontWeight', 'bold', ...
                'FontColor', th.text, ...
                'BackgroundColor', th.panelAlt, ...
                'HorizontalAlignment', 'left', 'VerticalAlignment', 'center');
            app.ReferralNote = uilabel(app.ReferralPanel, ...
                'Text', 'Run an analysis to see the referral decision', ...
                'Position', [20 5 350 26], ...
                'FontSize', th.type.labelSmall, ...
                'FontColor', th.textMuted, ...
                'BackgroundColor', th.panelAlt, ...
                'HorizontalAlignment', 'left', 'VerticalAlignment', 'top', ...
                'WordWrap', 'on');

            secLabel('MODEL CONFIDENCE', [16 316 220 14]);
            app.ConfidenceBar = uilabel(app.MiddlePanel, ...
                'Text', '—', ...
                'Position', [16 288 296 26], ...
                'FontSize', th.type.value, 'FontWeight', 'bold', ...
                'FontColor', th.textMuted, ...
                'BackgroundColor', th.panel, ...
                'HorizontalAlignment', 'left', 'VerticalAlignment', 'center');
            app.ConfChip = uilabel(app.MiddlePanel, ...
                'Text', '—', ...
                'Position', [324 288 80 26], ...
                'FontSize', th.type.labelSmall, 'FontWeight', 'bold', ...
                'FontColor', th.textMuted, ...
                'BackgroundColor', th.panelAlt, ...
                'HorizontalAlignment', 'center', 'VerticalAlignment', 'center');

            secLabel('P(REFERABLE) · LOCKED THRESHOLD 0.60', [16 256 388 14]);
            app.ScoreValue = uilabel(app.MiddlePanel, ...
                'Text', '—', ...
                'Position', [16 230 388 22], ...
                'FontSize', th.type.value, 'FontWeight', 'bold', ...
                'FontColor', th.text, 'BackgroundColor', th.panel, ...
                'HorizontalAlignment', 'left', 'VerticalAlignment', 'bottom');

            app.ModelInfoLabel = uilabel(app.MiddlePanel, ...
                'Text', 'Awaiting analysis', ...
                'Position', [16 204 388 18], ...
                'FontSize', th.type.labelSmall, 'FontColor', th.textFaint, ...
                'BackgroundColor', th.panel, ...
                'HorizontalAlignment', 'left');

            app.AdviceBox = uilabel(app.MiddlePanel, ...
                'Text', 'Run an analysis to see the screening advice', ...
                'Position', [16 48 388 148], ...
                'FontSize', th.type.valueLarge, 'FontWeight', 'bold', ...
                'FontColor', th.textFaint, ...
                'BackgroundColor', th.panelDeep, ...
                'HorizontalAlignment', 'center', ...
                'VerticalAlignment', 'center', ...
                'WordWrap', 'on');

            function secLabel(txt, pos)
                uilabel(app.MiddlePanel, 'Text', txt, ...
                    'Position', pos, ...
                    'FontSize', th.type.labelSmall, 'FontWeight', 'bold', ...
                    'FontColor', th.textFaint, ...
                    'BackgroundColor', th.panel, ...
                    'HorizontalAlignment', 'left');
            end
        end

        function createEvidenceSection(app)
            % Right column: VISUAL EVIDENCE - segmented view switcher,
            % Grad-CAM / overlay canvas with centralized colorbar + disclaimer.
            th = drishtiTheme();
            app.RightPanel = uipanel(app.UIFigure, ...
                'Title', ' MODEL EXPLANATION & VISUAL EVIDENCE ', ...
                'FontSize', th.type.sectionTitle, 'FontWeight', 'bold', ...
                'ForegroundColor', th.textMuted, ...
                'BackgroundColor', th.panel, ...
                'BorderType', 'line', 'BorderColor', th.border, ...
                'Position', [774 144 578 564]);

            % segmented control: one row of equal buttons
            app.ViewButtons = gobjects(1, 4);
            viewNames = {'Original', 'Enhanced', 'Grad-CAM', 'Overlay'};
            viewX = [16 154 292 430];
            for vi = 1:4
                app.ViewButtons(vi) = uibutton(app.RightPanel, 'push', ...
                    'Text', viewNames{vi}, ...
                    'Position', [viewX(vi) 528 132 30], ...
                    'FontSize', th.type.label, ...
                    'BackgroundColor', th.panelAlt, ...
                    'FontColor', th.textMuted, ...
                    'ButtonPushedFcn', @(src, ~) app.showView(char(src.Text)));
            end

            app.VizTitle = uilabel(app.RightPanel, ...
                'Text', 'Awaiting analysis', ...
                'Position', [0 498 578 22], ...
                'FontSize', th.type.panelTitle, 'FontWeight', 'bold', ...
                'FontColor', th.text, ...
                'BackgroundColor', th.panel, ...
                'HorizontalAlignment', 'center');

            app.GradCAMAxes = uiaxes(app.RightPanel, ...
                'Position', [16 122 482 368], ...
                'XTick', [], 'YTick', [], ...
                'Toolbar', [], ...
                'Box', 'off', ...
                'BackgroundColor', th.panelDeep);
            text(app.GradCAMAxes, 0.5, 0.5, 'Awaiting analysis', ...
                'Units', 'normalized', ...
                'HorizontalAlignment', 'center', ...
                'FontSize', th.type.value, ...
                'Color', th.textFaint);

            % vertical colorbar: 1 (high activation) on top, 0 (low) at foot
            app.ColorbarAxes = uiaxes(app.RightPanel, ...
                'Position', [512 122 12 368], ...
                'XTick', [], 'YTick', [], ...
                'Toolbar', [], ...
                'Box', 'off', ...
                'BackgroundColor', th.panelDeep);
            stripImg = gradcamColorbarStrip('Pixels', 16);
            image(app.ColorbarAxes, stripImg);
            app.ColorbarAxes.YDir = 'reverse';
            app.ColorbarAxes.XLim = [0.5 1.5];
            app.ColorbarAxes.YLim = [0.5 256.5];
            uilabel(app.RightPanel, 'Text', '1', ...
                'Position', [528 494 26 14], ...
                'FontSize', th.type.labelSmall, 'FontColor', th.textMuted, ...
                'BackgroundColor', th.panel, ...
                'HorizontalAlignment', 'center');
            uilabel(app.RightPanel, 'Text', '0', ...
                'Position', [528 100 26 14], ...
                'FontSize', th.type.labelSmall, 'FontColor', th.textMuted, ...
                'BackgroundColor', th.panel, ...
                'HorizontalAlignment', 'center');

            app.DisclaimerLabel = uilabel(app.RightPanel, ...
                'Text', 'Model attention visualization - not validated lesion localization.', ...
                'Position', [16 88 546 16], ...
                'FontSize', th.type.support, ...
                'FontColor', th.textFaint, ...
                'BackgroundColor', th.panel, ...
                'HorizontalAlignment', 'center');

            % hidden headless-verification controls (preserve report actions)
            app.ReportTextArea = uitextarea(app.RightPanel, ...
                'Position', [0 0 1 1], ...
                'FontSize', 10, 'FontName', 'Consolas', ...
                'Editable', 'off', ...
                'Visible', 'off', ...
                'Value', {'Analysis report will appear here.'});
            app.CopyReportBtn = uibutton(app.RightPanel, 'push', ...
                'Text', 'Copy to Clipboard', ...
                'Position', [0 0 1 1], ...
                'FontSize', 10, ...
                'Visible', 'off', ...
                'ButtonPushedFcn', @(~,~) app.copyReportCallback());
            app.PdfReportBtn = uibutton(app.RightPanel, 'push', ...
                'Text', 'Save PDF Report', ...
                'Position', [0 0 1 1], ...
                'FontSize', 10, ...
                'Visible', 'off', ...
                'ButtonPushedFcn', @(~,~) app.savePdfReportCallback());
        end

        function createBottomBar(app)
            % Bottom bar: IMAGE QUALITY cards | PIPELINE STATUS | REPORT.
            th = drishtiTheme();
            app.BottomBar = uipanel(app.UIFigure, ...
                'Position', [0 48 1360 88], ...
                'BackgroundColor', th.panel, ...
                'BorderType', 'line', 'BorderColor', th.border, 'BorderWidth', 1);

            panLabel('IMAGE QUALITY', [16 71 200 13]);
            panLabel('PIPELINE STATUS', [612 71 220 13]);
            panLabel('REPORT', [1040 71 200 13]);

            % ---- quality metric cards ----
            [app.FocusCard, m1, app.FocusValue, app.FocusCheck] = metricCard( ...
                [16 16 132 50], 'FOCUS');
            [app.IllumCard, m2, app.IllumValue, app.IllumCheck] = metricCard( ...
                [156 16 156 50], 'ILLUMINATION');
            [app.FovCard, m3, app.FovValue, app.FovCheck] = metricCard( ...
                [320 16 124 50], 'FIELD OF VIEW');

            app.OverallChip = uipanel(app.BottomBar, ...
                'Position', [452 16 144 50], ...
                'BackgroundColor', th.panelAlt, ...
                'BorderType', 'line', 'BorderColor', th.borderLight, 'BorderWidth', 1);
            uilabel(app.OverallChip, 'Text', 'OVERALL', ...
                'Position', [8 32 128 12], ...
                'FontSize', th.type.tiny, 'FontWeight', 'bold', ...
                'FontColor', th.textMuted, ...
                'BackgroundColor', th.panelAlt);
            app.OverallValue = uilabel(app.OverallChip, ...
                'Text', '—', ...
                'Position', [8 8 128 22], ...
                'FontSize', th.type.value, 'FontWeight', 'bold', ...
                'FontColor', th.textMuted, ...
                'BackgroundColor', th.panelAlt, ...
                'HorizontalAlignment', 'left', 'VerticalAlignment', 'bottom');

            app.EnhanceLabel = uilabel(app.BottomBar, ...
                'Text', 'Enhancement: —', ...
                'Position', [16 2 300 12], ...
                'FontSize', th.type.tiny, 'FontColor', th.textFaint, ...
                'BackgroundColor', th.panel, ...
                'HorizontalAlignment', 'left');
            app.QualityReasonLabel = uilabel(app.BottomBar, ...
                'Text', '', ...
                'Position', [16 14 440 12], ...
                'FontSize', th.type.tiny, 'FontColor', th.textFaint, ...
                'BackgroundColor', th.panel, ...
                'HorizontalAlignment', 'left');

            % ---- pipeline status chips ----
            stepNames = {'Image', 'Quality', 'Screening', 'Evidence', 'Report'};
            chipW = 79; gap = 4;
            app.PipelineChips = gobjects(1, 5);
            app.PipelineDots  = gobjects(1, 5);
            app.PipelineNames = gobjects(1, 5);
            for k = 1:5
                x = 612 + (k - 1) * (chipW + gap);
                chip = uipanel(app.BottomBar, ...
                    'Position', [x 14 chipW 52], ...
                    'BackgroundColor', th.panelAlt, ...
                    'BorderType', 'line', 'BorderColor', th.border, 'BorderWidth', 1);
                dot = uilabel(chip, ...
                    'Text', char(9675), ...
                    'Position', [6 32 14 14], ...
                    'FontSize', 11, ...
                    'FontColor', th.textFaint, ...
                    'BackgroundColor', th.panelAlt, ...
                    'HorizontalAlignment', 'center', 'VerticalAlignment', 'center');
                nm = uilabel(chip, ...
                    'Text', stepNames{k}, ...
                    'Position', [4 8 70 22], ...
                    'FontSize', th.type.tiny, 'FontWeight', 'bold', ...
                    'FontColor', th.textMuted, ...
                    'BackgroundColor', th.panelAlt, ...
                    'HorizontalAlignment', 'center', 'VerticalAlignment', 'top', ...
                    'WordWrap', 'on');
                app.PipelineChips(k) = chip;
                app.PipelineDots(k)  = dot;
                app.PipelineNames(k) = nm;
            end

            % ---- report actions ----
            app.GenerateReportBtn = uibutton(app.BottomBar, 'push', ...
                'Text', 'Generate Screening Report', ...
                'Position', [1040 16 312 56], ...
                'FontSize', th.type.value, 'FontWeight', 'bold', ...
                'BackgroundColor', th.primary, ...
                'FontColor', [1 1 1], ...
                'ButtonPushedFcn', @(~,~) app.savePdfReportCallback());

            app.PdfEngineLabel = uilabel(app.BottomBar, ...
                'Text', 'PDF engine: auto', ...
                'Position', [1040 2 312 12], ...
                'FontSize', th.type.tiny, ...
                'HorizontalAlignment', 'right', ...
                'VerticalAlignment', 'center', ...
                'FontColor', th.textFaint, ...
                'BackgroundColor', th.panel, ...
                'Visible', 'off');

            % hidden judge-terms badge (headless-verification contract)
            app.QualityBadge = uilabel(app.BottomBar, ...
                'Text', '', ...
                'Position', [1 1 36 16], ...
                'FontSize', 8, ...
                'Visible', 'off');

            function panLabel(txt, pos)
                uilabel(app.BottomBar, 'Text', txt, ...
                    'Position', pos, ...
                    'FontSize', th.type.labelSmall, 'FontWeight', 'bold', ...
                    'FontColor', th.textFaint, ...
                    'BackgroundColor', th.panel, ...
                    'HorizontalAlignment', 'left');
            end

            function [card, nameLbl, valueLbl, checkLbl] = metricCard(pos, titleTxt)
                card = uipanel(app.BottomBar, ...
                    'Position', pos, ...
                    'BackgroundColor', th.panelAlt, ...
                    'BorderType', 'line', 'BorderColor', th.borderLight, 'BorderWidth', 1);
                nameLbl = uilabel(card, 'Text', titleTxt, ...
                    'Position', [8 32 pos(3) - 16 12], ...
                    'FontSize', th.type.tiny, 'FontWeight', 'bold', ...
                    'FontColor', th.textMuted, ...
                    'BackgroundColor', th.panelAlt);
                valueLbl = uilabel(card, ...
                    'Text', '—', ...
                    'Position', [8 8 pos(3) - 40 22], ...
                    'FontSize', th.type.value, 'FontWeight', 'bold', ...
                    'FontColor', th.text, ...
                    'BackgroundColor', th.panelAlt, ...
                    'HorizontalAlignment', 'left', 'VerticalAlignment', 'bottom');
                checkLbl = uilabel(card, ...
                    'Text', '—', ...
                    'Position', [pos(3) - 26 10 22 20], ...
                    'FontSize', th.type.value, 'FontWeight', 'bold', ...
                    'FontColor', th.textFaint, ...
                    'BackgroundColor', th.panelAlt, ...
                    'HorizontalAlignment', 'center');
            end
        end

        function createFooter(app)
            th = drishtiTheme();
            app.FooterLabel = uilabel(app.UIFigure, ...
                'Text', 'Human-in-the-loop: final clinical decision by a qualified ophthalmologist.', ...
                'Position', [16 13 720 18], ...
                'FontSize', th.type.support, ...
                'FontColor', th.textFaint, 'HorizontalAlignment', 'left');

            app.MetricsLabel = uilabel(app.UIFigure, ...
                'Text', ['VALIDATION  ·  Accuracy 82.81%  ·  ' ...
                         'Referable sensitivity 90.60%  ·  Specificity 94.71%  ·  ' ...
                         'APTOS held-out validation  ·  Prototype, not clinically validated'], ...
                'Position', [676 13 668 18], ...
                'FontSize', th.type.support, ...
                'FontColor', th.textFaint, 'HorizontalAlignment', 'right');
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
            app.FilenameLabel.Text = ['Image ID : ' fname];
            app.setStatus(sprintf('Loaded: %s', fname), 'ok');
            app.setPipelineState('loading');
        end

        function uploadCallback(app)
            [file, path] = uigetfile({'*.png;*.jpg;*.jpeg', 'Fundus images'}, 'Select a fundus image');
            if isequal(file, 0)
                return;
            end
            app.CurrentImagePath = fullfile(path, file);
            showImage(app, app.CurrentImagePath);
            app.AnalyzeButton.Enable = 'on';
            app.FilenameLabel.Text = ['Image ID : ' file];
            app.setStatus(sprintf('Loaded: %s', file), 'ok');
            app.setPipelineState('loading');
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
                app.FilenameLabel.Text = ['Image ID : ' fileName];
                app.setStatus(sprintf('Loaded: %s', fileName), 'ok');
                app.setPipelineState('loading');
            else
                app.setStatus('Sample file not found.', 'err');
            end
        end

        function showImage(app, imgPath)
            try
                img = imread(imgPath);
                if size(img, 3) == 1, img = repmat(img, 1, 1, 3); end
                app.ImageRawSize = [size(img, 1) size(img, 2)];
                app.MetaLabel.Text = sprintf('Resolution: %d x %d px   Quality: —', ...
                    app.ImageRawSize(2), app.ImageRawSize(1));
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
            app.GenerateReportBtn.Enable = 'off';
            app.setStatus('ANALYZING IMAGE …', 'busy');
            app.setPipelineState('analyzing');
            drawnow;

            try
                result = predictSingleFundus(app.CurrentImagePath, ...
                    'ShowFigure', false, 'RunLesions', true, ...
                    'RunBranchB', true, 'SkipModelOnFail', true);
                app.CurrentResult = result;
                cacheViews(app, result);
                displayResults(app, result);
                if isfield(result, 'binaryDecision') && startsWith(result.binaryDecision, 'WITHHELD')
                    app.setStatus('QUALITY CHECK FAILED', 'err');
                else
                    app.setStatus('SCREENING COMPLETE', 'ok');
                end
            catch e
                app.setStatus(sprintf('Error: %s', e.message), 'err');
            end

            app.AnalyzeButton.Enable = 'on';
            app.GenerateReportBtn.Enable = 'on';
        end

        function setStatus(app, txt, kind)
            % Header status: text + colored system indicator dot.
            th = drishtiTheme();
            app.StatusLabel.Text = txt;
            switch kind
                case 'ok',   app.StatusDot.FontColor = th.success;
                case 'busy', app.StatusDot.FontColor = th.warning;
                case 'err',  app.StatusDot.FontColor = th.danger;
                otherwise,   app.StatusDot.FontColor = th.success;
            end
        end

        function displayResults(app, r)
            [qres, qmet] = app.assessQualityForDisplay();
            displayQualityRows(app, r, qres, qmet);
            app.LastQualityStatus = r.qualityStatus;
            if isfield(r, 'binaryDecision') && startsWith(r.binaryDecision, 'WITHHELD')
                displayWithheld(app, r, qres);
                return;
            end
            displayGradeRows(app, r);
            displayAdvice(app, r);
            updateModelInfoLine(app, r);
            showView(app, 'Overlay');
            app.setPipelineState('complete');
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
            % Cache the four explainability views. The model input pipeline
            % inside predictSingleFundus is never re-fed; these are only
            % display renders using the centralized Grad-CAM pipeline.
            th = drishtiTheme();
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
            if isfield(r, 'gradCAMMap') && ~isempty(r.gradCAMMap) ...
                    && isfield(r, 'binaryDecision') && ~startsWith(r.binaryDecision, 'WITHHELD')
                [ov, hm, ~] = renderGradCAMViews(r.gradCAMMap, raw);
                app.ViewOverlay = ov;
                app.ViewHeatmap = hm;
            end
        end

        function showView(app, name)
            th = drishtiTheme();
            switch name
                case 'Original', img = app.ViewOriginal;
                case 'Enhanced', img = app.ViewEnhanced;
                case 'Grad-CAM', img = app.ViewHeatmap;
                otherwise,       img = app.ViewOverlay;
            end
            switch name
                case 'Original', app.VizTitle.Text = 'Raw Fundus Image';
                case 'Enhanced', app.VizTitle.Text = 'Adaptive Enhanced Fundus';
                case 'Grad-CAM', app.VizTitle.Text = 'Grad-CAM Attention Map (model attention)';
                otherwise,       app.VizTitle.Text = 'Fundus + Grad-CAM Overlay (attention blend)';
            end
            for vi = 1:numel(app.ViewButtons)
                if strcmp(app.ViewButtons(vi).Text, name)
                    app.ViewButtons(vi).BackgroundColor = th.primary;
                    app.ViewButtons(vi).FontColor = [1 1 1];
                else
                    app.ViewButtons(vi).BackgroundColor = th.panelAlt;
                    app.ViewButtons(vi).FontColor = th.textMuted;
                end
            end
            if isempty(img)
                cla(app.GradCAMAxes);
                text(app.GradCAMAxes, 0.5, 0.5, [name ' view unavailable'], ...
                    'Units', 'normalized', 'HorizontalAlignment', 'center', ...
                    'FontSize', th.type.value, 'Color', th.textFaint);
            else
                imshow(img, 'Parent', app.GradCAMAxes);
                title(app.GradCAMAxes, '');
            end
        end

        function displayWithheld(app, r, qres)
            th = drishtiTheme();
            if nargin < 3
                qres = struct('overall', '', 'checks', {});
            end
            app.SeverityValue.Text = '—';
            app.IcdrValue.Text = '— / 4';
            app.ScoreValue.Text = '—';
            app.setConfidenceBar(NaN);
            app.setReferralState('danger', 'BLOCKED', ...
                'Image failed the quality gate - AI screening not run. Recapture the image.');
            app.setAdviceBox('RECAPTURE IMAGE REQUIRED', 'err');
            app.ModelInfoLabel.Text = 'Models skipped - quality gate FAIL (SkipModelOnFail)';
            cla(app.GradCAMAxes);
            text(app.GradCAMAxes, 0.5, 0.5, 'No Grad-CAM: analysis withheld (quality FAIL)', ...
                'Units', 'normalized', 'HorizontalAlignment', 'center', ...
                'FontSize', 12, 'Color', th.textFaint);
            app.setPipelineState('blocked');

            lines = {};
            lines{end+1} = '=== DRISHTI Analysis Report ===';
            lines{end+1} = '';
            lines{end+1} = sprintf('Image Quality: %s (score %.2f)', ...
                app.qualityJudgeTerm(r.qualityStatus), r.qualityScore);
            lines{end+1} = 'DR decision WITHHELD: quality gate FAIL - no model decision computed.';
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
            th = drishtiTheme();
            status = r.qualityStatus;
            app.QualityBadge.Text = app.qualityJudgeTerm(status);

            focusStatus    = app.checkStatusFor(qres, 'focus');
            brightStatus   = app.checkStatusFor(qres, 'brightness');
            contrastStatus = app.checkStatusFor(qres, 'contrast');
            fgStatus       = app.checkStatusFor(qres, 'foreground');

            app.FocusValue.Text = sprintf('%.4f', qmet.focusScore);
            setCheckMark(app.FocusCheck, focusStatus);

            app.IllumValue.Text = sprintf('%.3f', qmet.brightness);
            setCheckMark(app.IllumCheck, worstStatus(brightStatus, contrastStatus));

            if isfield(qmet, 'foregroundFrac') && isfinite(qmet.foregroundFrac)
                app.FovValue.Text = sprintf('%.1f%%', qmet.foregroundFrac * 100);
            else
                app.FovValue.Text = '—';
            end
            setCheckMark(app.FovCheck, fgStatus);

            % metadata line (resolution + quality chip)
            if app.ImageRawSize(1) > 0
                app.MetaLabel.Text = sprintf('Resolution: %d x %d px   Quality: %s   (%s)', ...
                    app.ImageRawSize(2), app.ImageRawSize(1), status, ...
                    app.qualityJudgeTerm(status));
            end
            app.MetaLabel.FontColor = th.status.(status);

            % overall verdict chip
            reason = '';
            if isfield(r, 'qualityFailureReasons') && ~isempty(r.qualityFailureReasons)
                reason = r.qualityFailureReasons{1};
            end
            if isempty(reason)
                for k = 1:numel(qres.checks)
                    if ~strcmp(qres.checks(k).status, 'PASS')
                        reason = qres.checks(k).message;
                        break;
                    end
                end
            end
            switch status
                case 'PASS'
                    app.OverallValue.Text = 'ACCEPT';
                    app.QualityReasonLabel.Text = 'Image quality acceptable - all checks within tolerance.';
                case 'WARNING'
                    app.OverallValue.Text = 'BORDERLINE';
                    app.QualityReasonLabel.Text = ['Borderline: ' reason];
                otherwise
                    app.OverallValue.Text = 'REJECT';
                    app.QualityReasonLabel.Text = ['Rejected: ' reason];
            end
            app.OverallValue.FontColor = th.status.(status);
            app.OverallChip.BackgroundColor = th.statusBg.(status);
            app.OverallChip.BorderColor = th.status.(status);

            % enhancement note (Day-4 module is display-only; model input unchanged)
            switch status
                case 'PASS'
                    app.EnhanceLabel.Text = 'Enhancement: Not needed (model input unchanged)';
                case 'WARNING'
                    app.EnhanceLabel.Text = 'Enhancement: Applied (display aid - model input unchanged)';
                otherwise
                    app.EnhanceLabel.Text = 'Enhancement: Not applied (quality FAIL)';
            end
            app.EnhanceLabel.FontColor = th.textFaint;
        end

        function displayGradeRows(app, r)
            th = drishtiTheme();
            app.SeverityValue.Text = r.gradeLabel;
            app.IcdrValue.Text = sprintf('%d / 4', r.grade);

            if strcmp(r.binaryDecision, 'REFERABLE')
                app.setReferralState('danger', 'REFERABLE', ...
                    'Specialist review advised by the model.');
            else
                app.setReferralState('success', 'NOT REFERABLE', ...
                    'Routine screening - no immediate referral indicated by the model.');
            end

            app.ScoreValue.Text = sprintf('%.2f%%   (P referable)', r.binaryProbability * 100);
            app.setConfidenceBar(r.confidence);
        end

        function updateModelInfoLine(app, r)
            % Margin: distance between the two binary screening outcomes in
            % percentage points (|P(non-ref) - P(ref)|).
            marginPP = abs(1 - 2 * r.binaryProbability) * 100;
            conf = r.confidence;
            if conf >= 0.75
                confLevel = 'high';
            elseif conf >= 0.50
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
            app.ModelInfoLabel.Text = sprintf('Margin %.1fpp · %s · TTA off · SO %s', ...
                marginPP, confLevel, soText);
        end

        function displayAdvice(app, r)
            % Same referral logic as the pipeline cascade: referable grades
            % refer; cascade REVIEW/ABSTAIN or an enforced quality gate goes
            % to a healthcare professional; everything else is routine.
            if r.qualityGate.enforced
                app.setAdviceBox(sprintf('QUALITY GATE FAIL\nRecapture image - specialist review advised.'), 'err');
            elseif r.grade >= 3
                app.setAdviceBox(sprintf('REFER FOR OPHTHALMOLOGIST REVIEW\nSpecialist review advised by the model.'), 'ref');
            elseif r.grade == 2 || strcmp(r.binaryDecision, 'REFERABLE')
                app.setAdviceBox(sprintf('REFER FOR OPHTHALMOLOGIST REVIEW\nSpecialist review advised by the model.'), 'ref');
            elseif strcmp(r.cascade.route, 'REVIEW') || strcmp(r.cascade.route, 'ABSTAIN')
                app.setAdviceBox(sprintf('REVIEW BY HEALTHCARE PROFESSIONAL\nSpecialist check advised - automated confidence is reduced.'), 'warn');
            else
                app.setAdviceBox(sprintf('ROUTINE SCREENING\nNo immediate specialist referral indicated by the model.'), 'ok');
            end
        end

        function setReferralState(app, tone, headline, note)
            th = drishtiTheme();
            switch tone
                case 'success', c = th.success; bg = th.successBg;
                case 'warning', c = th.warning; bg = th.warningBg;
                case 'danger',  c = th.danger;  bg = th.dangerBg;
                otherwise,      c = th.textFaint; bg = th.panelAlt;
            end
            app.ReferralPanel.BackgroundColor = bg;
            app.ReferralPanel.BorderColor = c;
            app.ReferralDot.FontColor = c;
            app.ReferableValue.Text = headline;
            app.ReferableValue.FontColor = c;
            app.ReferralNote.Text = note;
        end

        function setConfidenceBar(app, conf)
            th = drishtiTheme();
            if isnan(conf)
                app.ConfidenceBar.Text = '—';
                app.ConfidenceBar.FontColor = th.textMuted;
                app.ConfChip.Text = '—';
                app.ConfChip.BackgroundColor = th.panelAlt;
                app.ConfChip.FontColor = th.textMuted;
                return;
            end
            filled = max(0, min(20, round(conf * 20)));
            bar = [repmat('█', 1, filled) repmat('░', 1, 20 - filled) ...
                   '   ' sprintf('%.0f%%', conf * 100)];
            app.ConfidenceBar.Text = bar;
            if conf >= 0.75
                c = th.info; level = 'HIGH';
            elseif conf >= 0.50
                c = th.warning; level = 'MEDIUM';
            else
                c = th.danger; level = 'LOW';
            end
            app.ConfidenceBar.FontColor = c;
            app.ConfChip.Text = level;
            app.ConfChip.BackgroundColor = th.panelAlt;
            app.ConfChip.FontColor = c;
        end

        function setAdviceBox(app, txt, tone)
            th = drishtiTheme();
            app.AdviceBox.Text = txt;
            switch tone
                case 'ok'
                    app.AdviceBox.BackgroundColor = th.successBg;
                    app.AdviceBox.FontColor = th.success;
                case 'ref'
                    app.AdviceBox.BackgroundColor = th.dangerBg;
                    app.AdviceBox.FontColor = th.danger;
                case 'err'
                    app.AdviceBox.BackgroundColor = th.dangerBg;
                    app.AdviceBox.FontColor = th.danger;
                otherwise
                    app.AdviceBox.BackgroundColor = th.warningBg;
                    app.AdviceBox.FontColor = th.warning;
            end
        end

        function setPipelineState(app, state)
            th = drishtiTheme();
            % one style per stage for a given overall state
            styles = getStyles();   % 1x5 struct: dot, dotColor, name, chip, border
            for k = 1:5
                s = styles(k);
                app.PipelineDots(k).FontColor = s.dotColor;
                app.PipelineDots(k).Text = s.dot;
                app.PipelineNames(k).FontColor = s.nameColor;
                app.PipelineChips(k).BackgroundColor = s.chipBg;
                app.PipelineChips(k).BorderColor = s.border;
            end

            function styles = getStyles()
                styles = repmat(struct('dot', '', 'dotColor', [], ...
                    'nameColor', [], 'chipBg', [], 'border', []), 1, 5);
                for k = 1:5
                    styles(k).dot = char(9675);
                    styles(k).dotColor = th.textFaint;
                    styles(k).nameColor = th.textMuted;
                    styles(k).chipBg = th.panelAlt;
                    styles(k).border = th.border;
                end
                switch state
                    case 'loading'
                        styles(1).dot = char(10003);
                        styles(1).dotColor = th.success;
                        styles(1).nameColor = th.text;
                        styles(1).chipBg = th.successBg;
                        styles(1).border = th.success;
                    case 'analyzing'
                        styles(1).dot = char(10003);
                        styles(1).dotColor = th.success;
                        styles(1).nameColor = th.text;
                        styles(1).chipBg = th.successBg;
                        styles(1).border = th.success;
                        styles(2).dot = char(9679);
                        styles(2).dotColor = th.warning;
                        styles(2).nameColor = th.text;
                        styles(2).chipBg = th.warningBg;
                        styles(2).border = th.warning;
                    case 'complete'
                        for k = 1:5
                            styles(k).dot = char(10003);
                            styles(k).dotColor = th.success;
                            styles(k).nameColor = th.text;
                            styles(k).chipBg = th.successBg;
                            styles(k).border = th.success;
                        end
                    case 'blocked'
                        styles(1).dot = char(10003);
                        styles(1).dotColor = th.success;
                        styles(1).nameColor = th.text;
                        styles(1).chipBg = th.successBg;
                        styles(1).border = th.success;
                        for k = 2:5
                            styles(k).dot = char(10007);
                            styles(k).dotColor = th.danger;
                            styles(k).nameColor = th.text;
                            styles(k).chipBg = th.dangerBg;
                            styles(k).border = th.danger;
                        end
                end
            end
        end

        function displayReport(app, r)
            lines = {};
            lines{end+1} = '=== DRISHTI Analysis Report ===';
            lines{end+1} = '';
            lines{end+1} = sprintf('Image Quality: %s (score %.2f)', ...
                app.qualityJudgeTerm(r.qualityStatus), r.qualityScore);
            if strcmp(r.qualityStatus, 'WARNING')
                lines{end+1} = 'Adaptive enhancement: APPLIED (display aid - model input unchanged).';
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
            th = drishtiTheme();
            outDir = fullfile(app.ProjectRoot, 'results');
            patientID = app.derivedPatientId();
            try
                [pdfPath, engine] = generateDrishtiReport(app.CurrentResult, ...
                    'PatientID', patientID, ...
                    'OutDir', outDir, ...
                    'ImagePath', app.CurrentImagePath, ...
                    'GradCAMMap', app.resultGradCAMMap());
                app.LastPdfPath = pdfPath;
                app.PdfEngine  = engine;
                app.PdfEngineLabel.Text = ['PDF: ' engine ' · report saved'];
                app.PdfEngineLabel.Visible = 'on';
                app.PdfEngineLabel.FontColor = th.textFaint;
                [~, baseName, ext] = fileparts(pdfPath);
                app.StatusLabel.Text = sprintf('PDF saved (%s): %s%s', engine, baseName, ext);
            catch e
                app.StatusLabel.Text = sprintf('PDF export failed: %s', e.message);
            end
        end

        function m = resultGradCAMMap(app)
            m = [];
            if isfield(app.CurrentResult, 'gradCAMMap') && ~isempty(app.CurrentResult.gradCAMMap)
                m = app.CurrentResult.gradCAMMap;
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

    end

end

% -------------------------------------------------------------------------
function setCheckMark(lbl, status)
%SETCHECKMARK Render the per-metric quality mark (PASS/WARNING/FAIL).
    switch status
        case 'PASS'
            lbl.Text = char(10003);   % check mark
            lbl.FontColor = [0.235 0.710 0.415];
        case 'WARNING'
            lbl.Text = '!';
            lbl.FontColor = [0.960 0.620 0.160];
        case 'FAIL'
            lbl.Text = char(10007);   % ballot X
            lbl.FontColor = [0.920 0.310 0.300];
        otherwise
            lbl.Text = '—';
            lbl.FontColor = [0.475 0.535 0.645];
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