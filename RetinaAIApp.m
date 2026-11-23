classdef RetinaAIApp < matlab.apps.AppBase
%RETINAAIAPP DRISHTI + Lesion - AI-assisted diabetic retinopathy screening.
%   RetinaAIApp()
%
%   Dark desktop UI recreating the DRISHTI + Lesion reference layout:
%
%     Header (navy) + six-step workflow + three-column body:
%       LEFT   : FUNDUS IMAGE viewer + Upload / Analyze / New Screening
%       MIDDLE : AI SCREENING RESULT | IMAGE QUALITY | MODEL RELIABILITY
%       RIGHT  : Screening / Lesion Evidence / Report tabs
%     Footer (muted)
%
%   pipeline: image -> quality gate -> DR grade -> Grad-CAM -> report.
%   All decision logic, quality thresholds and referral rules come from the
%   EXISTING pipeline (predictSingleFundus). This class only owns PRESENTATION.
%   Colours / typography / Grad-CAM rendering live in src/ui/drishtiThemeDark.
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
        FloorNoticeShown   logical = false

        % ---- layout containers -------------------------------------------
        RootGrid           matlab.ui.container.GridLayout
        BodyGrid           matlab.ui.container.GridLayout
        HeaderPanel        matlab.ui.container.Panel
        WorkflowPanel      matlab.ui.container.Panel
        LeftPanel          matlab.ui.container.Panel
        MiddlePanel        matlab.ui.container.Panel
        RightPanel         matlab.ui.container.Panel
        BottomBar          matlab.ui.container.Panel
        FooterBar          matlab.ui.container.Panel
        TabGroup           matlab.ui.container.TabGroup
        TabScreening       matlab.ui.container.Tab
        TabLesion          matlab.ui.container.Tab
        TabReport          matlab.ui.container.Tab

        % ---- header ------------------------------------------------------
        TitleLabel         matlab.ui.control.Label
        SubtitleLabel      matlab.ui.control.Label
        StatusDot          matlab.ui.control.Label
        StatusLabel        matlab.ui.control.Label

        % ---- workflow indicator (six steps) ------------------------------
        WfDots
        WfNames

        % ---- left panel: retinal image -----------------------------------
        FilenameLabel      matlab.ui.control.Label
        MenuBtn            matlab.ui.control.Button
        ImageAxes          matlab.ui.control.UIAxes
        MetaLabel          matlab.ui.control.Label
        UploadButton       matlab.ui.control.Button
        AnalyzeButton      matlab.ui.control.Button
        NewBtn             matlab.ui.control.Button

        % ---- center panel: AI screening result ---------------------------
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

        % ---- center panel: image quality ---------------------------------
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
        QualityReasonLabel matlab.ui.control.Label
        EnhanceLabel       matlab.ui.control.Label
        QualityBadge       matlab.ui.control.Label

        % ---- center panel: model reliability -----------------------------
        ConfValue          matlab.ui.control.Label
        CalConfValue       matlab.ui.control.Label
        MarginValue        matlab.ui.control.Label
        EntropyValue       matlab.ui.control.Label

        % ---- right panel: visual evidence tabs ---------------------------
        ViewOriginal
        ViewEnhanced
        ViewHeatmap
        ViewOverlay
        ViewButtons
        GradCAMAxes        matlab.ui.control.UIAxes
        ColorbarAxes       matlab.ui.control.UIAxes
        DisclaimerLabel    matlab.ui.control.Label
        VizTitle           matlab.ui.control.Label

        % ---- lesion evidence tab -----------------------------------------
        LesSkipChk         matlab.ui.control.CheckBox
        LesUploadBtn       matlab.ui.control.Button
        LesStatusLabel     matlab.ui.control.Label
        LesBtns
        LesAxes            matlab.ui.control.UIAxes
        LesColorbarAxes    matlab.ui.control.UIAxes
        LesLegendLabel     matlab.ui.control.Label

        % ---- report tab --------------------------------------------------
        ReportTextArea     matlab.ui.control.TextArea
        ReportBtnMinus     matlab.ui.control.Button
        ReportBtnPlus      matlab.ui.control.Button
        PdfReportBtn       matlab.ui.control.Button
        CopyReportBtn      matlab.ui.control.Button
        ReportFontSize     double = 10

        % ---- report actions ----------------------------------------------
        GenerateReportBtn  matlab.ui.control.Button
        PdfEngineLabel     matlab.ui.control.Label
        LastPdfPath        char
        PdfEngine          char

        % ---- kebab menu / sample list state ------------------------------
        KebabMenu
        SampleDropdown
        SamplePaths        cell
        SampleItems        cell
        SuspendSampleCallback logical = false

        % ---- pipeline status chips ---------------------------------------
        PipelineChips
        PipelineDots
        PipelineNames

        % ---- lesion evidence state ---------------------------------------
        LesFovMask         logical      = []
        LesMaOverlay       matlab.ui.control.UIAxes

        FooterLabel        matlab.ui.control.Label
        MetricsLabel       matlab.ui.control.Label
    end

    methods (Access = public)

        function app = RetinaAIApp()
            appRoot = fileparts(mfilename('fullpath'));
            if exist(fullfile(appRoot, 'src'), 'dir')
                app.ProjectRoot = appRoot;
            else
                app.ProjectRoot = fileparts(appRoot);
            end
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
            th = drishtiThemeDark();
            app.UIFigure = uifigure('Name', 'DRISHTI + Lesion', ...
                'Position', [40 60 1600 900], ...
                'Color', th.background, ...
                'Resize', 'on', ...
                'AutoResizeChildren', 'off');

            app.RootGrid = uigridlayout(app.UIFigure, [6 1]);
            app.RootGrid.RowHeight = {70, 44, '1x', 92, 28, 24};
            app.RootGrid.Padding = [0 0 0 0];
            app.RootGrid.RowSpacing = 0;
            app.RootGrid.BackgroundColor = th.background;

            createHeader(app);
            createWorkflow(app);

            app.BodyGrid = uigridlayout(app.RootGrid, [1 3]);
            app.BodyGrid.ColumnWidth = {'26x', '24x', '47x'};
            app.BodyGrid.ColumnSpacing = 10;
            app.BodyGrid.Padding = [0 1 0 1];
            app.BodyGrid.RowSpacing = 0;
            app.BodyGrid.RowHeight = {'1x'};
            app.BodyGrid.BackgroundColor = th.background;

            createImageSection(app);
            createResultSection(app);
            createEvidenceSection(app);
            createBottomBar(app);
            createFooter(app);

            app.setStatus('System Ready', 'ok');
            app.setPipelineState('idle');
            app.enforceMinSize();
            app.UIFigure.SizeChangedFcn = @(~, ~) enforceMinSize(app);
            settleLayout(app);
        end

        function settleLayout(app)
            if ~isvalid(app.UIFigure), return; end
            drawnow;
            getframe(app.UIFigure);
            drawnow;
        end

        function createHeader(app)
            th = drishtiThemeDark();
            app.HeaderPanel = uipanel(app.RootGrid, ...
                'BackgroundColor', th.header, ...
                'BorderType', 'none');

            app.TitleLabel = uilabel(app.HeaderPanel, 'Text', 'DRISHTI + Lesion', ...
                'Position', [10 38 260 28], ...
                'FontSize', th.type.appTitle, 'FontWeight', 'bold', ...
                'FontColor', [1 1 1], 'HorizontalAlignment', 'left', ...
                'BackgroundColor', th.header);

            app.SubtitleLabel = uilabel(app.HeaderPanel, 'Text', ...
                'Explainable AI for Diabetic Retinopathy Screening · Prototype — not clinically validated', ...
                'Position', [12 16 700 14], ...
                'FontSize', th.type.labelSmall, ...
                'FontColor', [0.82 0.82 0.82], 'HorizontalAlignment', 'left', ...
                'BackgroundColor', th.header);

            app.StatusDot = uilabel(app.HeaderPanel, ...
                'Text', char(9679), ...
                'Position', [1510 32 18 20], ...
                'FontSize', 15, 'FontColor', th.success, ...
                'BackgroundColor', th.header);

            app.StatusLabel = uilabel(app.HeaderPanel, ...
                'Text', 'System Ready', ...
                'Position', [1532 32 58 20], ...
                'FontSize', th.type.label, 'FontColor', [1 1 1], ...
                'BackgroundColor', th.header);
        end

        function createWorkflow(app)
            th = drishtiThemeDark();
            app.WorkflowPanel = uipanel(app.RootGrid, ...
                'BackgroundColor', th.background, ...
                'BorderType', 'none');

            stepNames = {'1. Image', '2. Quality', '3. AI Screening', '4. Reliability', '5. Referral', '6. Report'};
            dotX = [30 290 550 810 1070 1330];
            nameX = [46 306 566 826 1086 1346];
            app.WfDots = gobjects(1, 6);
            app.WfNames = gobjects(1, 6);
            for k = 1:6
                app.WfDots(k) = uilabel(app.WorkflowPanel, ...
                    'Text', char(9675), ...
                    'Position', [dotX(k) 12 16 18], ...
                    'FontSize', 13, ...
                    'FontColor', th.textFaint, ...
                    'BackgroundColor', th.background, ...
                    'HorizontalAlignment', 'center', 'VerticalAlignment', 'center');
                app.WfNames(k) = uilabel(app.WorkflowPanel, ...
                    'Text', stepNames{k}, ...
                    'Position', [nameX(k) 10 120 20], ...
                    'FontSize', th.type.tiny, ...
                    'FontColor', th.textMuted, ...
                    'BackgroundColor', th.background, ...
                    'HorizontalAlignment', 'left');
            end
        end

        function createImageSection(app)
            th = drishtiThemeDark();
            app.LeftPanel = uipanel(app.BodyGrid, ...
                'Title', ' FUNDUS IMAGE ', ...
                'FontSize', th.type.sectionTitle, 'FontWeight', 'bold', ...
                'ForegroundColor', th.heading, ...
                'BackgroundColor', th.panel, ...
                'BorderType', 'line', 'BorderColor', th.border);

            app.FilenameLabel = uilabel(app.LeftPanel, ...
                'Text', 'Image ID: —', ...
                'Position', [16 532 300 20], ...
                'FontSize', th.type.label, 'FontColor', th.textMuted, ...
                'BackgroundColor', th.panel, ...
                'HorizontalAlignment', 'left');

            app.MenuBtn = uibutton(app.LeftPanel, 'push', ...
                'Text', '···', ...
                'Position', [330 532 22 20], ...
                'FontSize', th.type.label, 'FontWeight', 'bold', ...
                'BackgroundColor', th.panel, ...
                'FontColor', th.textFaint, ...
                'ButtonPushedFcn', @(~,~) app.menuButtonCallback());

            app.ImageAxes = uiaxes(app.LeftPanel, ...
                'Position', [16 130 300 388], ...
                'Tag', 'fundusAxes', ...
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
                'Position', [16 110 300 18], ...
                'FontSize', th.type.labelSmall, 'FontColor', th.textMuted, ...
                'BackgroundColor', th.panel, ...
                'HorizontalAlignment', 'left');

            app.UploadButton = uibutton(app.LeftPanel, 'push', ...
                'Text', 'Upload Image', ...
                'Position', [16 50 144 44], ...
                'FontSize', th.type.label, ...
                'BackgroundColor', th.secondary, ...
                'FontColor', [1 1 1], ...
                'ButtonPushedFcn', @(~,~) app.uploadCallback());

            app.AnalyzeButton = uibutton(app.LeftPanel, 'push', ...
                'Text', 'ANALYZE IMAGE', ...
                'Position', [172 50 144 44], ...
                'FontSize', th.type.value, ...
                'FontWeight', 'bold', ...
                'BackgroundColor', th.primary, ...
                'FontColor', [1 1 1], ...
                'Enable', 'off', ...
                'ButtonPushedFcn', @(~,~) app.analyzeCallback());

            app.NewBtn = uibutton(app.LeftPanel, 'push', ...
                'Text', 'NEW SCREENING', ...
                'Position', [16 6 300 40], ...
                'FontSize', th.type.label, ...
                'BackgroundColor', th.secondary, ...
                'FontColor', [1 1 1], ...
                'Enable', 'off', ...
                'ButtonPushedFcn', @(~,~) app.newScreeningCallback());

            app.SampleDropdown = uidropdown(app.LeftPanel, ...
                'Items', {'(no samples)'}, ...
                'Position', [16 8 100 22], ...
                'FontSize', 11, ...
                'Visible', 'off', ...
                'ValueChangedFcn', @(~) app.sampleCallback());
        end

        function createResultSection(app)
            th = drishtiThemeDark();
            app.MiddlePanel = uipanel(app.BodyGrid, ...
                'Title', ' AI SCREENING RESULT ', ...
                'FontSize', th.type.sectionTitle, 'FontWeight', 'bold', ...
                'ForegroundColor', th.heading, ...
                'BackgroundColor', th.panel, ...
                'BorderType', 'line', 'BorderColor', th.border);

            % ---- AI screening result -------------------------------------
            % All y-positions are bottom-up within the panel (~600 px usable).
            uilabel(app.MiddlePanel, 'Text', 'DR SEVERITY', ...
                'Position', [16 545 300 13], ...
                'FontSize', th.type.labelSmall, 'FontWeight', 'bold', ...
                'FontColor', th.textFaint, ...
                'BackgroundColor', th.panel, ...
                'HorizontalAlignment', 'left');
            app.SeverityValue = uilabel(app.MiddlePanel, ...
                'Text', '—', ...
                'Position', [16 510 300 35], ...
                'FontSize', th.type.valueHero, 'FontWeight', 'bold', ...
                'FontColor', th.text, 'BackgroundColor', th.panel, ...
                'HorizontalAlignment', 'left', 'VerticalAlignment', 'bottom');

            uilabel(app.MiddlePanel, 'Text', 'ICDR GRADE', ...
                'Position', [16 478 300 13], ...
                'FontSize', th.type.labelSmall, 'FontWeight', 'bold', ...
                'FontColor', th.textFaint, ...
                'BackgroundColor', th.panel, ...
                'HorizontalAlignment', 'left');
            app.IcdrValue = uilabel(app.MiddlePanel, ...
                'Text', '— / 4', ...
                'Position', [16 452 300 26], ...
                'FontSize', th.type.value, 'FontWeight', 'bold', ...
                'FontColor', th.text, 'BackgroundColor', th.panel, ...
                'HorizontalAlignment', 'left', 'VerticalAlignment', 'bottom');

            app.ReferralPanel = uipanel(app.MiddlePanel, ...
                'Position', [16 370 300 78], ...
                'BackgroundColor', th.panelAlt, ...
                'BorderType', 'line', 'BorderColor', th.borderLight, 'BorderWidth', 1);
            uilabel(app.ReferralPanel, 'Text', 'REFERRAL STATUS', ...
                'Position', [20 64 240 13], ...
                'FontSize', th.type.labelSmall, 'FontWeight', 'bold', ...
                'FontColor', th.textMuted, ...
                'BackgroundColor', th.panelAlt);
            app.ReferralDot = uilabel(app.ReferralPanel, ...
                'Text', char(9679), ...
                'Position', [20 40 18 24], ...
                'FontSize', th.type.valueHero, ...
                'FontColor', th.textFaint, ...
                'BackgroundColor', th.panelAlt, ...
                'HorizontalAlignment', 'center');
            app.ReferableValue = uilabel(app.ReferralPanel, ...
                'Text', '—', ...
                'Position', [44 32 240 32], ...
                'FontSize', th.type.valueHero, 'FontWeight', 'bold', ...
                'FontColor', th.text, ...
                'BackgroundColor', th.panelAlt, ...
                'HorizontalAlignment', 'left', 'VerticalAlignment', 'center');
            app.ReferralNote = uilabel(app.ReferralPanel, ...
                'Text', 'Run an analysis to see the referral decision', ...
                'Position', [20 6 270 30], ...
                'FontSize', th.type.labelSmall, ...
                'FontColor', th.textMuted, ...
                'BackgroundColor', th.panelAlt, ...
                'HorizontalAlignment', 'left', 'VerticalAlignment', 'top', ...
                'WordWrap', 'on');

            uilabel(app.MiddlePanel, 'Text', 'MODEL CONFIDENCE', ...
                'Position', [16 342 220 13], ...
                'FontSize', th.type.labelSmall, 'FontWeight', 'bold', ...
                'FontColor', th.textFaint, ...
                'BackgroundColor', th.panel, ...
                'HorizontalAlignment', 'left');
            app.ConfidenceBar = uilabel(app.MiddlePanel, ...
                'Text', '—', ...
                'Position', [16 316 240 28], ...
                'FontSize', th.type.value, 'FontWeight', 'bold', ...
                'FontColor', th.textMuted, ...
                'BackgroundColor', th.panel, ...
                'HorizontalAlignment', 'left', 'VerticalAlignment', 'center');
            app.ConfChip = uilabel(app.MiddlePanel, ...
                'Text', '—', ...
                'Position', [264 316 52 28], ...
                'FontSize', th.type.labelSmall, 'FontWeight', 'bold', ...
                'FontColor', th.textMuted, ...
                'BackgroundColor', th.panelAlt, ...
                'HorizontalAlignment', 'center', 'VerticalAlignment', 'center');

            uilabel(app.MiddlePanel, 'Text', 'P(REFERABLE) · LOCKED THRESHOLD 0.60', ...
                'Position', [16 286 300 13], ...
                'FontSize', th.type.labelSmall, 'FontWeight', 'bold', ...
                'FontColor', th.textFaint, ...
                'BackgroundColor', th.panel, ...
                'HorizontalAlignment', 'left');
            app.ScoreValue = uilabel(app.MiddlePanel, ...
                'Text', '—', ...
                'Position', [16 260 300 26], ...
                'FontSize', th.type.value, 'FontWeight', 'bold', ...
                'FontColor', th.text, 'BackgroundColor', th.panel, ...
                'HorizontalAlignment', 'left', 'VerticalAlignment', 'bottom');

            app.ModelInfoLabel = uilabel(app.MiddlePanel, ...
                'Text', 'Awaiting analysis', ...
                'Position', [16 240 300 18], ...
                'FontSize', th.type.labelSmall, 'FontColor', th.textFaint, ...
                'BackgroundColor', th.panel, ...
                'HorizontalAlignment', 'left');

            app.AdviceBox = uilabel(app.MiddlePanel, ...
                'Text', 'Run an analysis to see the screening advice', ...
                'Position', [16 35 300 190], ...
                'FontSize', th.type.valueLarge, 'FontWeight', 'bold', ...
                'FontColor', th.textFaint, ...
                'BackgroundColor', th.panelDeep, ...
                'HorizontalAlignment', 'center', ...
                'VerticalAlignment', 'center', ...
                'WordWrap', 'on');

            % ---- IMAGE QUALITY -------------------------------------------
            uilabel(app.MiddlePanel, 'Text', 'IMAGE QUALITY (prototype thresholds)', ...
                'Position', [16 210 300 15], ...
                'FontSize', th.type.sectionTitle, 'FontWeight', 'bold', ...
                'FontColor', th.heading, ...
                'BackgroundColor', th.panel, ...
                'HorizontalAlignment', 'left');

            [app.FocusCard, ~, app.FocusValue, app.FocusCheck] = metricCard( ...
                [16 178 92 30], 'FOCUS');
            [app.IllumCard, ~, app.IllumValue, app.IllumCheck] = metricCard( ...
                [112 178 92 30], 'ILLUMINATION');
            [app.FovCard, ~, app.FovValue, app.FovCheck] = metricCard( ...
                [208 178 92 30], 'FIELD OF VIEW');

            app.OverallChip = uipanel(app.MiddlePanel, ...
                'Position', [16 135 300 34], ...
                'BackgroundColor', th.panelAlt, ...
                'BorderType', 'line', 'BorderColor', th.borderLight, 'BorderWidth', 1);
            uilabel(app.OverallChip, 'Text', 'OVERALL', ...
                'Position', [8 22 284 13], ...
                'FontSize', th.type.tiny, 'FontWeight', 'bold', ...
                'FontColor', th.textMuted, ...
                'BackgroundColor', th.panelAlt);
            app.OverallValue = uilabel(app.OverallChip, ...
                'Text', '—', ...
                'Position', [8 6 284 20], ...
                'FontSize', th.type.valueLarge, 'FontWeight', 'bold', ...
                'FontColor', th.textMuted, ...
                'BackgroundColor', th.panelAlt, ...
                'HorizontalAlignment', 'left', 'VerticalAlignment', 'bottom');

            app.QualityReasonLabel = uilabel(app.MiddlePanel, ...
                'Text', '', ...
                'Position', [16 112 300 20], ...
                'FontSize', th.type.labelSmall, 'FontColor', th.textFaint, ...
                'BackgroundColor', th.panel, ...
                'HorizontalAlignment', 'left');

            % ---- MODEL RELIABILITY ---------------------------------------
            uilabel(app.MiddlePanel, 'Text', 'MODEL RELIABILITY', ...
                'Position', [16 88 300 15], ...
                'FontSize', th.type.sectionTitle, 'FontWeight', 'bold', ...
                'FontColor', th.heading, ...
                'BackgroundColor', th.panel, ...
                'HorizontalAlignment', 'left');

            app.ConfValue = reliabilityRow(app, [16 70 300 18], 'Confidence', '—');
            app.CalConfValue = reliabilityRow(app, [16 52 300 18], 'Calibrated confidence', '—');
            app.MarginValue = reliabilityRow(app, [16 34 300 18], 'Margin', '—');
            app.EntropyValue = reliabilityRow(app, [16 16 300 18], 'Entropy', '—');

            function [card, nameLbl, valueLbl, checkLbl] = metricCard(pos, titleTxt)
                card = uipanel(app.MiddlePanel, ...
                    'Position', pos, ...
                    'BackgroundColor', th.panelAlt, ...
                    'BorderType', 'line', 'BorderColor', th.borderLight, 'BorderWidth', 1);
                nameLbl = uilabel(card, 'Text', titleTxt, ...
                    'Position', [8 16 pos(3) - 16 12], ...
                    'FontSize', th.type.tiny, 'FontWeight', 'bold', ...
                    'FontColor', th.textMuted, ...
                    'BackgroundColor', th.panelAlt);
                valueLbl = uilabel(card, ...
                    'Text', '—', ...
                    'Position', [8 2 pos(3) - 40 14], ...
                    'FontSize', th.type.value, 'FontWeight', 'bold', ...
                    'FontColor', th.text, ...
                    'BackgroundColor', th.panelAlt, ...
                    'HorizontalAlignment', 'left', 'VerticalAlignment', 'bottom');
                checkLbl = uilabel(card, ...
                    'Text', '—', ...
                    'Position', [pos(3) - 24 4 20 14], ...
                    'FontSize', th.type.value, 'FontWeight', 'bold', ...
                    'FontColor', th.textFaint, ...
                    'BackgroundColor', th.panelAlt, ...
                    'HorizontalAlignment', 'center');
            end

            function lbl = reliabilityRow(app, pos, labelTxt, valueTxt)
                uilabel(app.MiddlePanel, 'Text', labelTxt, ...
                    'Position', [pos(1) pos(2)+14 pos(3) 13], ...
                    'FontSize', th.type.labelSmall, 'FontWeight', 'bold', ...
                    'FontColor', th.textFaint, ...
                    'BackgroundColor', th.panel, ...
                    'HorizontalAlignment', 'left');
                lbl = uilabel(app.MiddlePanel, ...
                    'Text', valueTxt, ...
                    'Position', [pos(1) pos(2) pos(3) 14], ...
                    'FontSize', th.type.value, 'FontWeight', 'bold', ...
                    'FontColor', th.text, ...
                    'BackgroundColor', th.panel, ...
                    'HorizontalAlignment', 'left', 'VerticalAlignment', 'bottom');
            end
        end

        function createEvidenceSection(app)
            th = drishtiThemeDark();
            app.RightPanel = uipanel(app.BodyGrid, ...
                'Title', ' MODEL EXPLANATION & VISUAL EVIDENCE ', ...
                'FontSize', th.type.sectionTitle, 'FontWeight', 'bold', ...
                'ForegroundColor', th.heading, ...
                'BackgroundColor', th.panel, ...
                'BorderType', 'line', 'BorderColor', th.border);

            % ---- tab group -----------------------------------------------
            app.TabGroup = uitabgroup(app.RightPanel, ...
                'Position', [16 8 480 555], ...
                'TabLocation', 'top');

            app.TabScreening = uitab(app.TabGroup, 'Title', 'Screening');
            app.TabLesion    = uitab(app.TabGroup, 'Title', 'Lesion Evidence');
            app.TabReport    = uitab(app.TabGroup, 'Title', 'Report');

            % ===== SCREENING TAB =========================================
            buildScreeningTab(app);

            % ===== LESION EVIDENCE TAB ===================================
            buildLesionTab(app);

            % ===== REPORT TAB ============================================
            buildReportTab(app);

            % Tab switch: keep header visible, reset per-tab visuals
            app.TabGroup.SelectionChangedFcn = @(src, ev) app.tabChanged(src, ev);
        end

        function buildScreeningTab(app)
            th = drishtiThemeDark();
            p = app.TabScreening;

            app.VizTitle = uilabel(p, ...
                'Text', 'MODEL EXPLANATION (attention, not lesion proof)', ...
                'Position', [16 536 448 17], ...
                'FontSize', th.type.sectionTitle, 'FontWeight', 'bold', ...
                'FontColor', th.heading, ...
                'BackgroundColor', th.panel, ...
                'HorizontalAlignment', 'left');

            viewNames = {'Original', 'Enhanced', 'Grad-CAM', 'Overlay'};
            % 2x2 grid per reference layout
            viewPos = [16 500 110 30;   % Original - top left
                       137 500 110 30;  % Enhanced - top right
                       16 464 110 30;   % Grad-CAM - bottom left
                       258 464 110 30]; % Overlay - bottom right
            app.ViewButtons = gobjects(1, 4);
            for vi = 1:4
                app.ViewButtons(vi) = uibutton(p, 'push', ...
                    'Text', viewNames{vi}, ...
                    'Position', viewPos(vi, :), ...
                    'FontSize', th.type.label, ...
                    'BackgroundColor', th.panelAlt, ...
                    'FontColor', th.textMuted, ...
                    'ButtonPushedFcn', @(src, ~) app.showView(char(src.Text)));
            end

            app.GradCAMAxes = uiaxes(p, ...
                'Position', [16 42 448 410], ...
                'XTick', [], 'YTick', [], ...
                'Toolbar', [], ...
                'Box', 'off', ...
                'BackgroundColor', th.panelDeep);
            text(app.GradCAMAxes, 0.5, 0.5, 'Awaiting analysis', ...
                'Units', 'normalized', ...
                'HorizontalAlignment', 'center', ...
                'FontSize', th.type.value, ...
                'Color', th.textFaint);

            app.ColorbarAxes = uiaxes(p, ...
                'Position', [468 42 12 410], ...
                'XTick', [], 'YTick', [], ...
                'Toolbar', [], ...
                'Box', 'off', ...
                'BackgroundColor', th.panelDeep);
            stripImg = gradcamColorbarStrip('Pixels', 16);
            image(app.ColorbarAxes, stripImg);
            app.ColorbarAxes.YDir = 'reverse';
            app.ColorbarAxes.XLim = [0.5 1.5];
            app.ColorbarAxes.YLim = [0.5 256.5];
            uilabel(p, 'Text', '1', ...
                'Position', [484 446 24 13], ...
                'FontSize', th.type.tiny, 'FontColor', th.textMuted, ...
                'BackgroundColor', th.panel, ...
                'HorizontalAlignment', 'center');
            uilabel(p, 'Text', '0', ...
                'Position', [484 36 24 13], ...
                'FontSize', th.type.tiny, 'FontColor', th.textMuted, ...
                'BackgroundColor', th.panel, ...
                'HorizontalAlignment', 'center');

            app.DisclaimerLabel = uilabel(p, ...
                'Text', 'Model attention visualization - not validated lesion localization.', ...
                'Position', [16 22 448 14], ...
                'FontSize', th.type.support, ...
                'FontColor', th.textFaint, ...
                'BackgroundColor', th.panel, ...
                'HorizontalAlignment', 'center');

            % hidden gate-compat action: the reporting gate drives a
            % 'Save PDF Report' button; it shares savePdfReportCallback with
            % the visible 'Generate Screening Report (PDF)' button.
            app.PdfReportBtn = uibutton(p, 'push', ...
                'Text', 'Save PDF Report', ...
                'Position', [0 0 1 1], ...
                'FontSize', 10, ...
                'Visible', 'off', ...
                'ButtonPushedFcn', @(~,~) app.savePdfReportCallback());
        end

        function buildLesionTab(app)
            th = drishtiThemeDark();
            p = app.TabLesion;

            uilabel(p, ...
                'Text', 'LESION EVIDENCE (prototype, opt-in)', ...
                'Position', [16 536 448 17], ...
                'FontSize', th.type.sectionTitle, 'FontWeight', 'bold', ...
                'FontColor', th.heading, ...
                'BackgroundColor', th.panel, ...
                'HorizontalAlignment', 'left');

            app.LesSkipChk = uicheckbox(p, ...
                'Text', 'Skip lesion evidence (faster screening)', ...
                'Position', [16 504 260 22], ...
                'FontSize', th.type.labelSmall, ...
                'FontColor', th.textMuted, ...
                'Value', false);

            app.LesUploadBtn = uibutton(p, 'push', ...
                'Text', 'Upload FOV mask', ...
                'Position', [16 464 120 28], ...
                'FontSize', th.type.label, ...
                'BackgroundColor', th.secondary, ...
                'FontColor', [1 1 1], ...
                'ButtonPushedFcn', @(~,~) app.uploadFovMaskCallback());

            app.LesStatusLabel = uilabel(p, ...
                'Text', 'No FOV mask — full-frame evidence.', ...
                'Position', [144 468 320 22], ...
                'FontSize', th.type.labelSmall, ...
                'FontColor', th.textMuted, ...
                'BackgroundColor', th.panel, ...
                'HorizontalAlignment', 'left', ...
                'WordWrap', 'on');

            btnNames = {'MA overlay', 'Vessel overlay', 'MA heat', 'Vessel heat'};
            % Four horizontally aligned buttons, fitted within tab width
            btnX = [16 133 250 367];
            app.LesBtns = gobjects(1, 4);
            for bi = 1:4
                app.LesBtns(bi) = uibutton(p, 'push', ...
                    'Text', btnNames{bi}, ...
                    'Position', [btnX(bi) 424 105 30], ...
                    'FontSize', th.type.label, ...
                    'BackgroundColor', th.panelAlt, ...
                    'FontColor', th.textMuted, ...
                    'ButtonPushedFcn', @(src, ~) app.showLesionView(char(src.Text)));
            end

            app.LesAxes = uiaxes(p, ...
                'Position', [16 48 448 366], ...
                'XTick', [], 'YTick', [], ...
                'Toolbar', [], ...
                'Box', 'off', ...
                'BackgroundColor', th.panelDeep);
            text(app.LesAxes, 0.5, 0.5, 'No lesion evidence available', ...
                'Units', 'normalized', ...
                'HorizontalAlignment', 'center', ...
                'FontSize', th.type.value, ...
                'Color', th.textFaint);

            app.LesColorbarAxes = uiaxes(p, ...
                'Position', [468 48 12 366], ...
                'XTick', [], 'YTick', [], ...
                'Toolbar', [], ...
                'Box', 'off', ...
                'BackgroundColor', th.panelDeep);
            hc = parula(256);
            cimg = reshape(hc, [1 256 3]);
            image(app.LesColorbarAxes, cimg);
            app.LesColorbarAxes.YDir = 'reverse';
            app.LesColorbarAxes.XLim = [0.5 1.5];
            app.LesColorbarAxes.YLim = [0.5 256.5];
            uilabel(p, 'Text', '1', ...
                'Position', [484 418 24 13], ...
                'FontSize', th.type.tiny, 'FontColor', th.textMuted, ...
                'BackgroundColor', th.panel, ...
                'HorizontalAlignment', 'center');
            uilabel(p, 'Text', '0', ...
                'Position', [484 44 24 13], ...
                'FontSize', th.type.tiny, 'FontColor', th.textMuted, ...
                'BackgroundColor', th.panel, ...
                'HorizontalAlignment', 'center');

            app.LesLegendLabel = uilabel(p, ...
                'Text', 'Lesion probability heatmap (0–1) — experimental, not clinical.', ...
                'Position', [16 26 448 18], ...
                'FontSize', th.type.support, ...
                'FontColor', th.textFaint, ...
                'BackgroundColor', th.panel, ...
                'HorizontalAlignment', 'center', ...
                'WordWrap', 'on');

            uilabel(p, ...
                'Text', 'Prototype evidence — not clinically validated.', ...
                'Position', [16 8 448 16], ...
                'FontSize', th.type.support, ...
                'FontColor', th.textFaint, ...
                'BackgroundColor', th.panel, ...
                'HorizontalAlignment', 'center', ...
                'WordWrap', 'on');
        end

        function buildReportTab(app)
            th = drishtiThemeDark();
            p = app.TabReport;

            uilabel(p, ...
                'Text', 'SCREENING REPORT', ...
                'Position', [16 536 448 17], ...
                'FontSize', th.type.sectionTitle, 'FontWeight', 'bold', ...
                'FontColor', th.heading, ...
                'BackgroundColor', th.panel, ...
                'HorizontalAlignment', 'left');

            app.ReportTextArea = uitextarea(p, ...
                'Position', [16 42 448 336], ...
                'FontSize', app.ReportFontSize, 'FontName', 'Consolas', ...
                'Editable', 'off', ...
                'BackgroundColor', th.panelDeep, ...
                'FontColor', th.text, ...
                'Value', {'No screening report yet.'});

            app.PdfReportBtn = uibutton(p, 'push', ...
                'Text', 'Generate Screening Report (PDF)', ...
                'Position', [16 386 384 46], ...
                'FontSize', th.type.value, 'FontWeight', 'bold', ...
                'BackgroundColor', th.success, ...
                'FontColor', [1 1 1], ...
                'Enable', 'off', ...
                'ButtonPushedFcn', @(~,~) app.savePdfReportCallback());
            app.ReportBtnMinus = uibutton(p, 'push', ...
                'Text', 'A−', ...
                'Position', [404 386 28 24], ...
                'FontSize', th.type.label, ...
                'BackgroundColor', th.panelAlt, ...
                'FontColor', th.text, ...
                'ButtonPushedFcn', @(~,~) app.reportFontMinusCallback());
            app.ReportBtnPlus = uibutton(p, 'push', ...
                'Text', 'A+', ...
                'Position', [436 386 28 24], ...
                'FontSize', th.type.label, ...
                'BackgroundColor', th.panelAlt, ...
                'FontColor', th.text, ...
                'ButtonPushedFcn', @(~,~) app.reportFontPlusCallback());
        end

        function createBottomBar(app)
            th = drishtiThemeDark();
            app.BottomBar = uipanel(app.RootGrid, ...
                'BackgroundColor', th.panel, ...
                'BorderType', 'line', 'BorderColor', th.border, 'BorderWidth', 1);

            panLabel('IMAGE QUALITY', [16 64 180 13]);
            panLabel('PIPELINE STATUS', [540 64 220 13]);
            panLabel('REPORT', [1040 64 200 13]);

            % ---- quality metric cards ----
            [app.FocusCard, ~, app.FocusValue, app.FocusCheck] = metricCard( ...
                [16 14 132 46], 'FOCUS');
            [app.IllumCard, ~, app.IllumValue, app.IllumCheck] = metricCard( ...
                [156 14 156 46], 'ILLUMINATION');
            [app.FovCard, ~, app.FovValue, app.FovCheck] = metricCard( ...
                [320 14 124 46], 'FIELD OF VIEW');

            app.OverallChip = uipanel(app.BottomBar, ...
                'Position', [452 14 144 46], ...
                'BackgroundColor', th.panelAlt, ...
                'BorderType', 'line', 'BorderColor', th.borderLight, 'BorderWidth', 1);
            uilabel(app.OverallChip, 'Text', 'OVERALL', ...
                'Position', [8 28 128 12], ...
                'FontSize', th.type.tiny, 'FontWeight', 'bold', ...
                'FontColor', th.textMuted, ...
                'BackgroundColor', th.panelAlt);
            app.OverallValue = uilabel(app.OverallChip, ...
                'Text', '—', ...
                'Position', [8 6 128 22], ...
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

            % ---- pipeline status chips (six steps) -----------------------
            stepNames = {'Image', 'Quality', 'Screening', 'Reliability', 'Referral', 'Report'};
            chipW = 79; gap = 4;
            app.PipelineChips = gobjects(1, 6);
            app.PipelineDots  = gobjects(1, 6);
            app.PipelineNames = gobjects(1, 6);
            for k = 1:6
                x = 540 + (k - 1) * (chipW + gap);
                chip = uipanel(app.BottomBar, ...
                    'Position', [x 12 chipW 52], ...
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
                'Position', [1040 14 312 56], ...
                'FontSize', th.type.value, 'FontWeight', 'bold', ...
                'BackgroundColor', th.primary, ...
                'FontColor', [1 1 1], ...
                'Enable', 'off', ...
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
                    'Position', [8 28 pos(3) - 16 12], ...
                    'FontSize', th.type.tiny, 'FontWeight', 'bold', ...
                    'FontColor', th.textMuted, ...
                    'BackgroundColor', th.panelAlt);
                valueLbl = uilabel(card, ...
                    'Text', '—', ...
                    'Position', [8 6 pos(3) - 40 22], ...
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
            th = drishtiThemeDark();
            app.FooterBar = uipanel(app.RootGrid, ...
                'BackgroundColor', th.background, ...
                'BorderType', 'none');

            app.FooterLabel = uilabel(app.FooterBar, ...
                'Text', 'Human-in-the-loop: final clinical decision by a qualified ophthalmologist.   ·   Prototype, not clinically validated.', ...
                'Position', [16 6 800 14], ...
                'FontSize', th.type.support, ...
                'FontColor', th.textMuted, ...
                'BackgroundColor', th.background, ...
                'HorizontalAlignment', 'left');

            app.MetricsLabel = uilabel(app.FooterBar, ...
                'Text', ['VALIDATION · Accuracy 82.81% · Referable sensitivity 90.60% · Specificity 94.71% · ' ...
                         'APTOS held-out validation · Prototype, not clinically validated'], ...
                'FontSize', th.type.support, ...
                'FontColor', th.textMuted, ...
                'BackgroundColor', th.background, ...
                'HorizontalAlignment', 'right');
        end

        function enforceMinSize(app)
            if ~isvalid(app.UIFigure), return; end
            p = app.UIFigure.Position;
            w = max(p(3), 1120);
            h = max(p(4), 680);
            ss = get(groot, 'ScreenSize');
            sL = ss(1); sB = ss(2); sR = ss(1) + ss(3); sT = ss(2) + ss(4);
            cappedW = min(w, max(ss(3), 1));
            cappedH = min(h, max(ss(4), 1));
            if cappedW < w || cappedH < h
                if ~app.FloorNoticeShown
                    app.FloorNoticeShown = true;
                    fprintf(['NOTICE: screen is %dx%d, smaller than the %dx%d ' ...
                        'minimum window size; the floor is abandoned for this ' ...
                        'display and the window is capped to the screen.\n'], ...
                        ss(3), ss(4), 1120, 680);
                end
            end
            w = cappedW; h = cappedH;
            x = p(1) + (p(3) - w) / 2;
            y = p(2) + (p(4) - h) / 2;
            x = min(max(x, sL), max(sL, sR - w));
            y = min(max(y, sB), max(sB, sT - h));
            if w ~= p(3) || h ~= p(4) || x ~= p(1) || y ~= p(2)
                app.UIFigure.Position = [x y w h];
            end
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
                        items{end+1} = sprintf('%s/%s (%s)', classes{c}, d(i).name, labels{c});
                        paths{end+1} = fullfile(valDir, classes{c}, d(i).name);
                    end
                end
            end
            app.SampleDropdown.Items = items;
            app.SampleItems = items;
            app.SamplePaths = paths;
            app.buildKebabMenu();
        end

        function buildKebabMenu(app)
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

        function uploadCallback(app)
            [file, path] = uigetfile({'*.png;*.jpg;*.jpeg', 'Fundus images'}, 'Select a fundus image');
            if isequal(file, 0)
                return;
            end
            app.CurrentImagePath = fullfile(path, file);
            showImage(app, app.CurrentImagePath);
            app.AnalyzeButton.Enable = 'on';
            app.NewBtn.Enable = 'on';
            app.FilenameLabel.Text = ['Image ID: ' file];
            app.setStatus(sprintf('Loaded: %s', file), 'ok');
            app.setPipelineState('loading');
            app.resetResultDisplay();
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
                app.NewBtn.Enable = 'on';
                app.FilenameLabel.Text = ['Image ID: ' fileName];
                app.setStatus(sprintf('Loaded: %s', fileName), 'ok');
                app.setPipelineState('loading');
                app.resetResultDisplay();
            else
                app.setStatus('Sample file not found.', 'err');
            end
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
            app.NewBtn.Enable = 'on';
            [~, fname] = fileparts(app.SamplePaths{idx});
            app.FilenameLabel.Text = ['Image ID: ' fname];
            app.setStatus(sprintf('Loaded: %s', fname), 'ok');
            app.setPipelineState('loading');
            app.resetResultDisplay();
        end

        function showImage(app, imgPath)
            try
                img = imread(imgPath);
                if size(img, 3) == 1, img = repmat(img, 1, 1, 3); end
                app.ImageRawSize = [size(img, 1) size(img, 2)];
                app.MetaLabel.Text = sprintf('Resolution: %d x %d px   Quality: —', ...
                    app.ImageRawSize(2), app.ImageRawSize(1));
                cla(app.ImageAxes);
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

        function resetResultDisplay(app)
            app.CurrentResult = struct();
            app.LastQualityStatus = '';
            app.ImageRawSize = [0 0];
            app.SeverityValue.Text = '—';
            app.IcdrValue.Text = '— / 4';
            app.ScoreValue.Text = '—';
            app.setConfidenceBar(NaN);
            app.setReferralState('muted', '—', 'Run an analysis to see the referral decision');
            app.setAdviceBox('Run an analysis to see the screening advice', 'muted');
            app.ModelInfoLabel.Text = 'Awaiting analysis';
            app.FocusValue.Text = '—';
            app.IllumValue.Text = '—';
            app.FovValue.Text = '—';
            app.OverallValue.Text = '—';
            app.QualityReasonLabel.Text = '';
            app.ConfValue.Text = '—';
            app.CalConfValue.Text = '—';
            app.MarginValue.Text = '—';
            app.EntropyValue.Text = '—';
            app.MetaLabel.Text = 'Resolution: —  ·  Quality: —';
            app.EnhanceLabel.Text = 'Enhancement: —';
            app.VizTitle.Text = 'Awaiting analysis';
            cla(app.GradCAMAxes);
            text(app.GradCAMAxes, 0.5, 0.5, 'Awaiting analysis', ...
                'Units', 'normalized', 'HorizontalAlignment', 'center', ...
                'FontSize', thValue(app).type.value, 'Color', thValue(app).textFaint);
            cla(app.LesAxes);
            text(app.LesAxes, 0.5, 0.5, 'No lesion evidence available', ...
                'Units', 'normalized', 'HorizontalAlignment', 'center', ...
                'FontSize', thValue(app).type.value, 'Color', thValue(app).textFaint);
            app.LesFovMask = [];
            app.LesStatusLabel.Text = 'No FOV mask — full-frame evidence.';
            app.setPipelineState('idle');
            app.ReportTextArea.Value = {'No screening report yet.'};
            app.PdfReportBtn.Enable = 'off';
        end

        function t = thValue(app)
            t = drishtiThemeDark();
        end

        function setStatus(app, txt, kind)
            th = drishtiThemeDark();
            app.StatusLabel.Text = txt;
            switch kind
                case 'ok',   app.StatusDot.FontColor = th.success;
                case 'busy', app.StatusDot.FontColor = th.warning;
                case 'err',  app.StatusDot.FontColor = th.danger;
                otherwise,   app.StatusDot.FontColor = th.success;
            end
        end

        function setPipelineState(app, state)
            th = drishtiThemeDark();
            styles = repmat(struct('dot', char(9675), 'dotColor', th.textFaint, ...
                'nameColor', th.textMuted, 'chipBg', th.panelAlt, 'border', th.border), 1, 6);
            switch state
                case 'idle'
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
                    for k = 1:6
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
                    for k = 2:6
                        styles(k).dot = char(10007);
                        styles(k).dotColor = th.danger;
                        styles(k).nameColor = th.text;
                        styles(k).chipBg = th.dangerBg;
                        styles(k).border = th.danger;
                    end
            end
            for k = 1:6
                s = styles(k);
                app.PipelineDots(k).FontColor = s.dotColor;
                app.PipelineDots(k).Text = s.dot;
                app.PipelineNames(k).FontColor = s.nameColor;
                app.PipelineChips(k).BackgroundColor = s.chipBg;
                app.PipelineChips(k).BorderColor = s.border;
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
                raw = imread(app.CurrentImagePath);
                if size(raw, 3) == 1, raw = repmat(raw, 1, 1, 3); end
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
            th = drishtiThemeDark();
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
            th = drishtiThemeDark();
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
                cla(app.GradCAMAxes);
                imshow(img, 'Parent', app.GradCAMAxes);
                title(app.GradCAMAxes, '');
            end
        end

        function displayWithheld(app, r, qres)
            th = drishtiThemeDark();
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
            th = drishtiThemeDark();
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

            if app.ImageRawSize(1) > 0
                app.MetaLabel.Text = sprintf('Resolution: %d x %d px   Quality: %s   (%s)', ...
                    app.ImageRawSize(2), app.ImageRawSize(1), status, ...
                    app.qualityJudgeTerm(status));
            end
            app.MetaLabel.FontColor = th.status.(status);

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
            th = drishtiThemeDark();
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

        function displayAdvice(app, r)
            th = drishtiThemeDark();
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

        function updateModelInfoLine(app, r)
            th = drishtiThemeDark();
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

            % reliability readouts
            if isnan(conf)
                app.ConfValue.Text = '—';
            else
                app.ConfValue.Text = sprintf('%.1f%%', conf * 100);
            end
            pcal = r.binaryProbabilityCalibrated;
            if isnan(pcal)
                app.CalConfValue.Text = '—';
            else
                app.CalConfValue.Text = sprintf('%.1f%%', pcal * 100);
            end
            app.MarginValue.Text = sprintf('%.1f pp', marginPP);
            if isfield(r, 'classProbabilities') && isvector(r.classProbabilities)
                pp = r.classProbabilities(:);
                if ~any(isnan(pp))
                    pp = pp ./ sum(pp);
                    pp(pp == 0) = realmin;
                    ent = -sum(pp .* log(pp));
                    app.EntropyValue.Text = sprintf('%.3f', ent);
                else
                    app.EntropyValue.Text = '—';
                end
            else
                app.EntropyValue.Text = '—';
            end
        end

        function setReferralState(app, tone, headline, note)
            th = drishtiThemeDark();
            if strcmp(tone, 'muted')
                c = th.textFaint; bg = th.panelAlt;
            elseif strcmp(tone, 'success')
                c = th.success; bg = th.successBg;
            elseif strcmp(tone, 'warning')
                c = th.warning; bg = th.warningBg;
            elseif strcmp(tone, 'danger')
                c = th.danger; bg = th.dangerBg;
            else
                c = th.textFaint; bg = th.panelAlt;
            end
            app.ReferralPanel.BackgroundColor = bg;
            app.ReferralPanel.BorderColor = c;
            app.ReferralDot.FontColor = c;
            app.ReferableValue.Text = headline;
            app.ReferableValue.FontColor = c;
            app.ReferralNote.Text = note;
        end

        function setConfidenceBar(app, conf)
            th = drishtiThemeDark();
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
            th = drishtiThemeDark();
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
                case 'warn'
                    app.AdviceBox.BackgroundColor = th.warningBg;
                    app.AdviceBox.FontColor = th.warning;
                case 'muted'
                    app.AdviceBox.BackgroundColor = th.panelDeep;
                    app.AdviceBox.FontColor = th.textFaint;
                otherwise
                    app.AdviceBox.BackgroundColor = th.warningBg;
                    app.AdviceBox.FontColor = th.warning;
            end
        end

        function displayReport(app, r)
            lines = {};
            lines{end+1} = '=== DRISHTI + Lesion Screening Report ===';
            lines{end+1} = '';
            lines{end+1} = sprintf('Image: %s', app.derivedPatientId());
            lines{end+1} = sprintf('Resolution: %d x %d px', app.ImageRawSize(2), app.ImageRawSize(1));
            lines{end+1} = '';
            lines{end+1} = sprintf('Image Quality: %s (score %.2f)', ...
                app.qualityJudgeTerm(r.qualityStatus), r.qualityScore);
            lines{end+1} = sprintf('Quality assessment: %s', app.qualityJudgeTerm(r.qualityStatus));
            if r.qualityGate.enforced
                lines{end+1} = '  Quality gate ENFORCED: FAIL -> recapture/manual review';
            end
            lines{end+1} = '';
            lines{end+1} = sprintf('DR Grade: %d / 4 - %s', r.grade, r.gradeLabel);
            lines{end+1} = sprintf('ICDR Grade: %d / 4', r.grade);
            lines{end+1} = sprintf('Referable DR: %s', r.binaryDecision);
            lines{end+1} = sprintf('Model Score: %.1f%% (threshold %.2f LOCKED)', ...
                r.binaryProbability * 100, r.binaryThreshold);
            if ~isnan(r.binaryProbabilityCalibrated)
                lines{end+1} = sprintf('Calibrated confidence: %.1f%% (T=%.2f)', ...
                    r.binaryProbabilityCalibrated * 100, r.calibrationTemperature);
            end
            marginPP = abs(1 - 2 * r.binaryProbability) * 100;
            lines{end+1} = sprintf('Margin: %.1f pp', marginPP);
            if isfield(r, 'classProbabilities') && isvector(r.classProbabilities)
                pp = r.classProbabilities(:);
                if ~any(isnan(pp))
                    pp = pp ./ sum(pp);
                    pp(pp == 0) = realmin;
                    ent = -sum(pp .* log(pp));
                    lines{end+1} = sprintf('Entropy: %.3f', ent);
                end
            end
            lines{end+1} = sprintf('Confidence: %.1f%%', r.confidence * 100);
            lines{end+1} = sprintf('Reliability: %s', app.reliabilityLevel(r.confidence));
            lines{end+1} = sprintf('Cascade route: %s', r.cascade.route);
            lines{end+1} = '';
            if isfield(r, 'lesions') && isfield(r.lesions, 'maCount')
                lines{end+1} = sprintf('Lesion candidates: MA=%d HE=%d EX=%d', ...
                    r.lesions.maCount, r.lesions.heCount, r.lesions.exCount);
            end
            gcamTxt = 'unavailable';
            if app.gradcamAvailable()
                gcamTxt = 'computed';
            end
            lines{end+1} = sprintf('Grad-CAM: %s', gcamTxt);
            lesTxt = 'not computed';
            if app.lesionEvidenceAvailable()
                lesTxt = 'available';
            end
            lines{end+1} = sprintf('Lesion evidence: %s (prototype, opt-in)', lesTxt);
            lines{end+1} = '';
            if isfield(r, 'explanation') && isfield(r.explanation, 'recommendation')
                lines{end+1} = sprintf('Recommendation: %s', r.explanation.recommendation);
            end
            lines{end+1} = '';
            lines{end+1} = sprintf('Inference time: %.2fs', r.runtimeSec);
            lines{end+1} = '';
            lines{end+1} = 'ENGINEERING DEMO - NOT a clinical device.';
            lines{end+1} = 'Human-in-the-loop: final clinical decision by a qualified ophthalmologist.';

            app.ReportTextArea.Value = lines;
            app.PdfReportBtn.Enable = 'on';
            app.GenerateReportBtn.Enable = 'on';
        end

        function lvl = reliabilityLevel(app, conf)
            if isnan(conf)
                lvl = '—';
            elseif conf >= 0.75
                lvl = 'high';
            elseif conf >= 0.50
                lvl = 'medium';
            else
                lvl = 'low';
            end
        end

        function ok = gradcamAvailable(app)
            ok = ~isempty(app.ViewHeatmap);
        end

        function ok = lesionEvidenceAvailable(app)
            ok = isfield(app.CurrentResult, 'lesions') && ...
                 isfield(app.CurrentResult.lesions, 'overlay') && ...
                 ~isempty(app.CurrentResult.lesions.overlay);
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
            app.StatusLabel.Text = sprintf('Report saved: %s', file);
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
            th = drishtiThemeDark();
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

        function tabChanged(app, src, ev)
            % Keep the tab header visible while switching; no state reset.
            newTab = ev.SelectedTab;
            if ~isvalid(newTab)
                return;
            end
            t = lower(char(newTab.Title));
            if contains(t, 'lesion')
                app.refreshLesionTab();
            elseif contains(t, 'report')
                % report tab shows live report text
            end
        end

        function refreshLesionTab(app)
            th = drishtiThemeDark();
            if isempty(app.CurrentImagePath)
                cla(app.LesAxes);
                text(app.LesAxes, 0.5, 0.5, 'No image loaded', ...
                    'Units', 'normalized', 'HorizontalAlignment', 'center', ...
                    'FontSize', th.type.value, 'Color', th.textFaint);
                return;
            end
            if isempty(app.CurrentResult)
                cla(app.LesAxes);
                text(app.LesAxes, 0.5, 0.5, 'Run analysis first', ...
                    'Units', 'normalized', 'HorizontalAlignment', 'center', ...
                    'FontSize', th.type.value, 'Color', th.textFaint);
                return;
            end
            % Show MA overlay by default when evidence exists
            app.showLesionView('MA overlay');
        end

        function showLesionView(app, name)
            th = drishtiThemeDark();
            % highlight the pressed button
            for bi = 1:numel(app.LesBtns)
                if strcmp(app.LesBtns(bi).Text, name)
                    app.LesBtns(bi).BackgroundColor = th.primary;
                    app.LesBtns(bi).FontColor = [1 1 1];
                else
                    app.LesBtns(bi).BackgroundColor = th.panelAlt;
                    app.LesBtns(bi).FontColor = th.textMuted;
                end
            end

            if isempty(app.CurrentImagePath) || isempty(app.CurrentResult)
                cla(app.LesAxes);
                text(app.LesAxes, 0.5, 0.5, 'Run analysis first', ...
                    'Units', 'normalized', 'HorizontalAlignment', 'center', ...
                    'FontSize', th.type.value, 'Color', th.textFaint);
                cla(app.LesColorbarAxes);
                return;
            end

            lesions = app.CurrentResult.lesions;
            raw = imread(app.CurrentImagePath);
            if size(raw, 3) == 1, raw = repmat(raw, 1, 1, 3); end

            switch name
                case 'MA overlay'
                    img = app.lesionMaOverlay(raw, lesions);
                    cla(app.LesColorbarAxes);
                case 'Vessel overlay'
                    img = app.lesionVesselOverlay(raw);
                    cla(app.LesColorbarAxes);
                case 'MA heat'
                    img = app.lesionMaHeatmap(raw, lesions);
                    app.drawLesionColorbar();
                case 'Vessel heat'
                    img = app.lesionVesselHeatmap(raw);
                    app.drawLesionColorbar();
                otherwise
                    img = [];
            end

            if isempty(img)
                cla(app.LesAxes);
                text(app.LesAxes, 0.5, 0.5, [name ' unavailable'], ...
                    'Units', 'normalized', 'HorizontalAlignment', 'center', ...
                    'FontSize', th.type.value, 'Color', th.textFaint);
                cla(app.LesColorbarAxes);
            else
                cla(app.LesAxes);
                imshow(img, 'Parent', app.LesAxes);
                title(app.LesAxes, '');
            end
        end

        function img = lesionMaOverlay(app, raw, lesions)
            th = drishtiThemeDark();
            img = raw;
            if isfield(lesions, 'overlay') && isstruct(lesions.overlay) && ...
                    isfield(lesions.overlay, 'overlay') && ~isempty(lesions.overlay.overlay)
                img = imfuse(raw, im2uint8(lesions.overlay.overlay * 255), 'blend', 'Scaling', 'joint');
            else
                img = [];
            end
        end

        function img = lesionVesselOverlay(app, raw)
            try
                seg = segmentVesselsCnn(raw);
                if isfield(seg, 'mask')
                    vesselImg = uint8(repmat(seg.mask .* 255, [1 1 3]));
                    img = imfuse(raw, vesselImg, 'blend', 'Scaling', 'joint');
                else
                    img = [];
                end
            catch
                img = [];
            end
        end

        function img = lesionMaHeatmap(app, raw, lesions)
            th = drishtiThemeDark();
            if isfield(lesions, 'overlay') && isstruct(lesions.overlay) && ...
                    isfield(lesions.overlay, 'maMask') && ~isempty(lesions.overlay.maMask)
                hm = lesions.overlay.maMask;
            else
                hm = [];
            end
            if isempty(hm)
                img = [];
            else
                hm = mat2gray(hm);
                hc = parula(256);
                rgb = hc(reshape(round(hm * 255) + 1, [], 1), :);
                heatmapImg = reshape(rgb, size(hm, 1), size(hm, 2), 3);
                heatmapImg = imresize(heatmapImg, size(raw, [1 2]), 'bicubic');
                img = imfuse(raw, im2uint8(heatmapImg * 255), 'blend', 'Scaling', 'joint');
            end
        end

        function img = lesionVesselHeatmap(app, raw)
            try
                seg = segmentVesselsCnn(raw);
                if isfield(seg, 'map')
                    hm = mat2gray(seg.map);
                    hc = parula(256);
                    rgb = hc(reshape(round(hm * 255) + 1, [], 1), :);
                    heatmapImg = reshape(rgb, size(hm, 1), size(hm, 2), 3);
                    heatmapImg = imresize(heatmapImg, size(raw, [1 2]), 'bicubic');
                    img = imfuse(raw, im2uint8(heatmapImg * 255), 'blend', 'Scaling', 'joint');
                else
                    img = [];
                end
            catch
                img = [];
            end
        end

        function drawLesionColorbar(app)
            th = drishtiThemeDark();
            hc = parula(256);
            cimg = reshape(hc, [1 256 3]);
            cla(app.LesColorbarAxes);
            image(app.LesColorbarAxes, cimg);
            app.LesColorbarAxes.YDir = 'reverse';
            app.LesColorbarAxes.XLim = [0.5 1.5];
            app.LesColorbarAxes.YLim = [0.5 256.5];
        end

        function uploadFovMaskCallback(app)
            [file, path] = uigetfile({'*.png;*.jpg;*.jpeg;*.tif;*.tiff', 'FOV mask images'}, 'Select an FOV mask');
            if isequal(file, 0)
                return;
            end
            try
                mask = imread(fullfile(path, file));
                if size(mask, 3) > 1
                    mask = rgb2gray(mask);
                end
                [H, W] = size(mask);
                raw = imread(app.CurrentImagePath);
                [rH, rW, ~] = size(raw);
                if H ~= rH || W ~= rW
                    app.LesStatusLabel.Text = 'FOV mask dimensions mismatch — not applied.';
                    app.LesFovMask = [];
                    return;
                end
                app.LesFovMask = mask > mean(mask(:));
                app.LesStatusLabel.Text = sprintf('FOV mask loaded (%s) — mask applied.', file);
            catch e
                app.LesStatusLabel.Text = 'Failed to load FOV mask.';
                app.LesFovMask = [];
            end
        end

        function newScreeningCallback(app)
            app.CurrentImagePath = '';
            app.CurrentResult = struct();
            app.ImageRawSize = [0 0];
            app.LastQualityStatus = '';
            app.LesFovMask = [];
            app.AnalyzeButton.Enable = 'off';
            app.NewBtn.Enable = 'off';
            app.GenerateReportBtn.Enable = 'off';
            app.PdfReportBtn.Enable = 'off';
            app.FilenameLabel.Text = 'Image ID: —';
            app.MetaLabel.Text = 'Resolution: —  ·  Quality: —';
            app.SeverityValue.Text = '—';
            app.IcdrValue.Text = '— / 4';
            app.ScoreValue.Text = '—';
            app.setConfidenceBar(NaN);
            app.setReferralState('muted', '—', 'Run an analysis to see the referral decision');
            app.setAdviceBox('Run an analysis to see the screening advice', 'muted');
            app.ModelInfoLabel.Text = 'Awaiting analysis';
            app.FocusValue.Text = '—';
            app.IllumValue.Text = '—';
            app.FovValue.Text = '—';
            app.OverallValue.Text = '—';
            app.QualityReasonLabel.Text = '';
            app.EnhanceLabel.Text = 'Enhancement: —';
            app.ConfValue.Text = '—';
            app.CalConfValue.Text = '—';
            app.MarginValue.Text = '—';
            app.EntropyValue.Text = '—';
            cla(app.ImageAxes);
            text(app.ImageAxes, 0.5, 0.5, 'No image selected', ...
                'Units', 'normalized', 'HorizontalAlignment', 'center', ...
                'FontSize', drishtiThemeDark().type.value, 'Color', drishtiThemeDark().textFaint);
            cla(app.GradCAMAxes);
            text(app.GradCAMAxes, 0.5, 0.5, 'Awaiting analysis', ...
                'Units', 'normalized', 'HorizontalAlignment', 'center', ...
                'FontSize', drishtiThemeDark().type.value, 'Color', drishtiThemeDark().textFaint);
            cla(app.LesAxes);
            text(app.LesAxes, 0.5, 0.5, 'No lesion evidence available', ...
                'Units', 'normalized', 'HorizontalAlignment', 'center', ...
                'FontSize', drishtiThemeDark().type.value, 'Color', drishtiThemeDark().textFaint);
            app.LesStatusLabel.Text = 'No FOV mask — full-frame evidence.';
            app.LesSkipChk.Value = false;
            app.VizTitle.Text = 'Awaiting analysis';
            app.ReportTextArea.Value = {'No screening report yet.'};
            app.setStatus('System Ready', 'ok');
            app.setPipelineState('idle');
        end

        function reportFontMinusCallback(app)
            app.ReportFontSize = max(8, app.ReportFontSize - 1);
            app.ReportTextArea.FontSize = app.ReportFontSize;
        end

        function reportFontPlusCallback(app)
            app.ReportFontSize = min(16, app.ReportFontSize + 1);
            app.ReportTextArea.FontSize = app.ReportFontSize;
        end
    end
end

% -------------------------------------------------------------------------
function setCheckMark(lbl, status)
%SETCHECKMARK Render the per-metric quality mark (PASS/WARNING/FAIL).
    switch status
        case 'PASS'
            lbl.Text = char(10003);   % check mark
            lbl.FontColor = [0.000 0.710 0.169];   % #00B52B success
        case 'WARNING'
            lbl.Text = '!';
            lbl.FontColor = [1.000 0.600 0.000];   % #FF9900 warning
        case 'FAIL'
            lbl.Text = char(10007);   % ballot X
            lbl.FontColor = [0.898 0.224 0.208];   % #E53935 danger
        otherwise
            lbl.Text = '—';
            lbl.FontColor = [0.627 0.627 0.627];   % #A0A0A0 muted
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
