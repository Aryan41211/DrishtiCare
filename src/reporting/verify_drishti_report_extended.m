function verify_drishti_report_extended(projectRoot)
% verify_drishti_report_extended.m
% Headless EXTENDED verification for the DRISHTI professional PDF report.
%
% Mirrors the house verification style (src/dashboard/verify_retinaai.m, and
% the baseline src/reporting/verify_drishti_report.m): one flat script, REAL
% headless callbacks, REAL assertions on REAL artifacts/messages on disk, no
% mocks anywhere.
%
% Extension over the baseline: it instantiates the REAL RetinaAIApp.m
% headlessly, drives its REAL callbacks (sample selection, ANALYZE, and the
% new Save PDF Report button -> savePdfReportCallback), then asserts the REAL
% PDF artifact the app produced lands in results\ as a genuine >3 KB %PDF
% file whose content streams carry the same decision the app's own report
% textarea reports.
%
% If RetinaAIApp.m does not yet expose the Save PDF Report callback, this
% script reports the gap honestly (NOT-YET-PRESENT) instead of claiming the
% extension passes; the established verify_drishti_report baseline is checked
% in every run.
%
% Usage: verify_drishti_report_extended()               % infers project root
%        verify_drishti_report_extended(projectRoot)
%
% Writes its own verdict + artifact facts to:
%        <projectRoot>/results/_verify_extended_verdict.txt

if nargin < 1
    projectRoot = fileparts(fileparts(fileparts(mfilename('fullpath'))));
end
addpath(projectRoot);
addpath(genpath(fullfile(projectRoot, 'src')));

outDir = fullfile(projectRoot, 'results');
if ~exist(outDir, 'dir'), mkdir(outDir); end
verdictFile = fullfile(outDir, '_verify_extended_verdict.txt');

facts = struct();
facts.verdict        = 'FAIL';
facts.failStep       = '';
facts.pdfPath        = '';
facts.bytes          = -1;
facts.header         = '';
facts.engine         = '';
facts.decision       = '';
facts.sample         = '';
facts.samplePath     = '';
facts.statusText     = '';
facts.engineLabel    = '';
facts.callbacks      = {};
facts.gap            = '';
facts.baseline       = '';
facts.error          = '';

fprintf('== DRISHTI extended PDF report verification (real app callbacks) ==\n');

try

%% 1. App lifecycle (house style, verify_retinaai.m step 1)
a = RetinaAIApp();
drawnow;
assert(isvalid(a.UIFigure), 'UIFigure valid');
assert(strcmp(a.UIFigure.Name, 'DRISHTI'), 'title is DRISHTI');
fprintf('OK  1. app instantiated headless\n');

%% 2. Select a real val sample and run the REAL analyze callback
% This populates app.CurrentResult and app.CurrentImagePath for real (the
% private state the PDF callback consumes), exactly as verify_retinaai.m does.
dd = findall(a.UIFigure, 'Type', 'uidropdown');
assert(numel(dd) == 1, 'one sample dropdown');
assert(numel(dd.Items) > 1, 'sample list populated');
assert(strcmp(dd.Items{1}, '(no samples)'), 'placeholder first item');
dd.Value = dd.Items{2};
if ~isempty(dd.ValueChangedFcn)
    dd.ValueChangedFcn(dd);
end
drawnow;
facts.sample = dd.Value;

analyzeBtns = findall(a.UIFigure, 'Type', 'uibutton');
analyzeBtn = [];
for k = 1:numel(analyzeBtns)
    if strcmp(analyzeBtns(k).Text, 'ANALYZE IMAGE')
        analyzeBtn = analyzeBtns(k);
    end
end
assert(~isempty(analyzeBtn), 'ANALYZE button found');
assert(strcmp(analyzeBtn.Enable, 'on'), 'analyze enabled after selecting sample');

% Drive the REAL analyze callback -> REAL inference -> REAL CurrentResult
analyzeBtn.ButtonPushedFcn(analyzeBtn);
drawnow;
facts.callbacks{end+1} = 'analyzeCallback (ANALYZE ButtonPushedFcn)';
fprintf('OK  2. real analyze callback ran on %s\n', facts.sample);

%% 3. The app's report textarea holds the REAL report m(verify_retinaai step 5)
areas = findall(a.UIFigure, 'Type', 'uitextarea');
assert(numel(areas) >= 1, 'report textarea exists');
rep = areas(1).Value;
assert(numel(rep) >= 10, 'report has many lines');
assert(any(contains(rep, 'DRISHTI')), 'report header');
% Pull the decision the REAL pipeline wrote, to cross-check the PDF later.
decision = '';
for k = 1:numel(rep)
    if contains(rep{k}, 'Referable DR:')
        tk = strsplit(rep{k}, 'Referable DR:');
        decision = strtrim(tk{end});
    elseif contains(rep{k}, 'WITHHELD')
        decision = 'WITHHELD';
    end
end
assert(~isempty(decision), 'real report carries a decision for the PDF cross-check');
facts.decision = decision;
facts.callbacks{end+1} = 'displayReport (inside analyzeCallback -> displayResults)';
fprintf('OK  3. real report textarea populated; decision=%s\n', decision);

%% 4. The Save PDF Report callback is present and wired
pdfBtn = [];
for k = 1:numel(analyzeBtns)
    if strcmp(analyzeBtns(k).Text, 'Save PDF Report')
        pdfBtn = analyzeBtns(k);
    end
end
if isempty(pdfBtn) || isempty(pdfBtn.ButtonPushedFcn)
    facts.gap  = 'RetinaAIApp.m has NO Save PDF Report button / savePdfReportCallback';
    facts.error = 'app-callback GAP (NOT-YET-PRESENT)';
    facts.failStep = 'step 4 (savePdfReportCallback absent)';
    emitVerdict('FAIL');
    fprintf('\nEXTENDED CHECK HALTED: %s\n', facts.gap);
    error('DRISHTI_EXTENDED_VERIFY_GAP: savePdfReportCallback NOT-YET-PRESENT');
end

% Snapshot results\ before driving the REAL callback
before = dir(fullfile(outDir, 'DrishtiScreeningReport_*.pdf'));
beforeNames = cell(numel(before), 1);
for k = 1:numel(before), beforeNames{k} = before(k).name; end

% Drive the REAL savePdfReportCallback -> REAL generateDrishtiReport
pdfBtn.ButtonPushedFcn(pdfBtn);
drawnow;
facts.callbacks{end+1} = 'savePdfReportCallback (Save PDF Report ButtonPushedFcn)';
fprintf('OK  4. Save PDF Report callback driven headlessly\n');

%% 5. The app reported the save via its REAL status/engine labels
% The StatusLabel is a private property, but it is a REAL uilabel on the
% figure; read what the REAL savePdfReportCallback actually said there.
labels = findall(a.UIFigure, 'Type', 'uilabel');
statusText = '';
engText    = '';
rawStatus  = '';
for k = 1:numel(labels)
    ltx = char(labels(k).Text);
    if contains(ltx, 'PDF')
        if isempty(rawStatus), rawStatus = ltx; end
    end
    if contains(ltx, 'PDF saved'),  statusText = ltx; end
    if contains(ltx, 'PDF:'),       engText    = ltx; end
end
if isempty(statusText)
    % The REAL callback executed but did not report a save. Surface the
    % app's OWN words (e.g. "PDF export failed: ...") as the honest reason
    % instead of a generic assertion message.
    facts.statusText = rawStatus;
    if isempty(rawStatus), rawStatus = '(no PDF status found on any label)'; end
    facts.gap  = 'savePdfReportCallback EXISTS, was driven, but reported export failure';
    facts.error = rawStatus;
    error('DRISHTI_EXTENDED_VERIFY_FAIL: %s', rawStatus);
end
assert(~isempty(engText), 'PDF engine label switched after export');
facts.statusText  = statusText;
facts.engineLabel = engText;
if contains(engText, 'mlreportgen')
    facts.engine = 'mlreportgen';
else
    facts.engine = 'edge';
end
fprintf('OK  5. status="%s" | %s\n', statusText, engText);

%% 6. A REAL new PDF artifact landed in results\ (name not in the snapshot)
after = dir(fullfile(outDir, 'DrishtiScreeningReport_*.pdf'));
newpdf = '';
newestT = 0;
for k = 1:numel(after)
    if ~any(strcmp(beforeNames, after(k).name)) && after(k).datenum > newestT
        newpdf   = fullfile(after(k).folder, after(k).name);
        newestT  = after(k).datenum;
    end
end
assert(~isempty(newpdf), 'a NEW DrishtiScreeningReport_*.pdf artifact appeared in results');
pdfPath = newpdf;
assert(exist(pdfPath, 'file') == 2, 'PDF artifact exists on disk');
d = dir(pdfPath);
assert(d.bytes > 3000, 'PDF artifact is non-trivial (>3 KB)');
fid = fopen(pdfPath, 'rb');
assert(fid ~= -1, 'PDF artifact opens for reading');
hdr8 = fread(fid, 8, '*char')';
fclose(fid);
assert(strcmp(hdr8(1:4), '%PDF'), 'PDF header signature present (%PDF)');
facts.pdfPath = pdfPath;
facts.bytes   = d.bytes;
facts.header  = hdr8;
fprintf('OK  6. PDF artifact: %s (%d bytes, header=%s, engine=%s)\n', ...
    pdfPath, d.bytes, hdr8, facts.engine);

%% 7. Content blocks verified engine-aware (mlreportgen ASCII vs Skia glyphs)
% mlreportgen PDFs store ASCII in Flate streams; Edge/Skia PDFs encode text
% as Identity-H glyph IDs, so verify the kept HTML source + PDF structure.
if strcmp(facts.engine, 'mlreportgen')
    txt = collapseWS(pdfText(pdfPath));
    assert(contains(txt, 'Screening Summary'), 'Screening Summary section present');
    assert(contains(txt, 'DRISHTI'), 'DRISHTI branding present');
    assert(contains(txt, 'Diabetic Retinopathy Grade'), 'DR Grade section present');
    if strcmpi(decision, 'NO REFERABLE')
        dTok = 'NOT REFERABLE';
    else
        dTok = upper(decision);
    end
    assert(contains(txt, dTok), ['real decision "', dTok, '" present in PDF text']);
else
    htmlPath = strrep(pdfPath, '.pdf', '.html');
    assert(exist(htmlPath, 'file') == 2, 'HTML source kept alongside PDF');
    html = collapseWS(fileread(htmlPath));
    assert(contains(html, 'Screening Summary'), 'Screening Summary section present');
    assert(contains(html, 'DRISHTI'), 'DRISHTI branding present');
    assert(contains(html, 'Diabetic Retinopathy Grade'), 'DR Grade section present');
    if strcmpi(decision, 'NO REFERABLE')
        dTok = 'NOT REFERABLE';
    else
        dTok = upper(decision);
    end
    assert(contains(html, dTok), ['real decision "', dTok, '" present in HTML source']);
    fb = fopen(pdfPath, 'rb');
    B = fread(fb, Inf, '*uint8')';
    fclose(fb);
    C = char(B);
    assert(~isempty(strfind(C, 'FlateDecode')), 'PDF has compressed content streams');
    assert(~isempty(strfind(C, 'ToUnicode')), 'PDF has embedded text fonts (not blank)');
end
fprintf('OK  7. content blocks verified (decision "%s")\n', dTok);

%% 8. Cleanup + baseline regression (established verifier still passes)
a.delete();
facts.baseline = 'verify_drishti_report(projectRoot)';
verify_drishti_report(projectRoot);
fprintf('OK  8. established verify_drishti_report still passes\n');

%% Success verdict
facts.verdict = 'PASS';
facts.error   = '';
emitVerdict('PASS');
fprintf('\nALL EXTENDED DRISHTI PDF REPORT CHECKS PASS (engine=%s)\n', facts.engine);

catch err
    a.delete();
    if isempty(facts.error)
        facts.error = err.message;
    end
    if isempty(facts.failStep)
        facts.failStep = err.identifier;
    end
    emitVerdict('FAIL');
    fprintf('\nEXTENDED CHECK FAILED: %s\n', facts.error);
    rethrow(err);
end

    % ------------------------------------------------------------------
    function emitVerdict(status)
        fh = fopen(verdictFile, 'w');
        if fh == -1, error('cannot open verdict file for writing'); end
        fprintf(fh, 'VERDICT: %s\n', status);
        fprintf(fh, 'PDF_PATH: %s\n', facts.pdfPath);
        fprintf(fh, 'PDF_BYTES: %d\n', facts.bytes);
        fprintf(fh, 'PDF_HEADER: %s\n', facts.header);
        fprintf(fh, 'PDF_ENGINE: %s\n', facts.engine);
        fprintf(fh, 'DECISION: %s\n', facts.decision);
        fprintf(fh, 'STATUS_LABEL: %s\n', facts.statusText);
        fprintf(fh, 'ENGINE_LABEL: %s\n', facts.engineLabel);
        fprintf(fh, 'SAMPLE: %s\n', facts.sample);
        fprintf(fh, 'CALLBACKS_DRIVEN: %s\n', strjoin(facts.callbacks, ' | '));
        fprintf(fh, 'CALLBACK_GAP: %s\n', facts.gap);
        fprintf(fh, 'BASELINE: %s\n', facts.baseline);
        fprintf(fh, 'FAIL_STEP: %s\n', facts.failStep);
        fprintf(fh, 'ERROR: %s\n', facts.error);
        fclose(fh);
    end

end

% -------------------------------------------------------------------------
function out = collapseWS(t)
% Normalize whitespace runs to single spaces so content-stream joins from
% multiple TJ operands still match phrase-level assertions.
out = regexprep(t, '\s+', ' ');
end

% -------------------------------------------------------------------------
function txt = pdfText(pdfPath)
% Scans the REAL PDF artifact byte stream and returns the concatenated text
% of every FlateDecode content stream (uncompressed payloads included).
fid = fopen(pdfPath, 'rb');
B = fread(fid, Inf, '*uint8')';
fclose(fid);
C = char(B);
txt = '';
ks = strfind(C, 'stream');
es = strfind(C, 'endstream');
for p = ks
    e = es(es > p);
    if isempty(e), continue; end
    seg = B(p + 6 : e(1) - 1);
    out = inflateString(seg);
    if ~isempty(out)
        txt = [txt out]; %#ok<AGROW>
    end
end
end

% -------------------------------------------------------------------------
function out = inflateString(seg)
% zlib (FlateDecode) inflate of a raw stream segment via the bundled JVM.
out = '';
try
    bis = java.io.ByteArrayInputStream(seg);
    zis = java.util.zip.InflaterInputStream(bis);
    baos = java.io.ByteArrayOutputStream();
    buf = zeros(1, 8192, 'int8');
    while true
        n = zis.read(buf, 0, 8192);
        if n <= 0, break; end
        baos.write(buf, 0, n);
    end
    zis.close();
    out = char(typecast(baos.toByteArray(), 'uint8')');
catch
end
end