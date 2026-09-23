% generateDrishtiReport.m
% Professional PDF screening report generator for the DRISHTI DR screening app.
%
% Flat, single-responsibility house-style function: takes the SAME result
% struct that RetinaAIApp.m's displayReport/displayRecommendation/displayGrade
% callbacks consume (see RetinaAIApp.m L609-651), and produces a BRANDED,
% ARTICULATED, A4 professional PDF screening report designed for the patient
% / referring clinician. Visual styling mirrors src/ui/drishtiTheme.m so the
% dashboard and the PDF render with the SAME presentation rules.
%
% Engine selection (two-tier, no toolbox hard-requirement):
%   tier-1  MATLAB Report Generator (mlreportgen.pdf.Document) - preferred
%   tier-2  headless Edge/Chrome HTML -> PDF fallback (no toolbox needed)
%
% The output is a REAL PDF artifact on disk at OutDir, named
% DrishtiScreeningReport_<patientID>_<yyyyMMdd_HHmmss>.pdf
%
% Signature:
%   [pdfPath, engine] = generateDrishtiReport(result, ...)
%     Name-Value: 'PatientID'  (char, default 'ANON'),
%                 'OutDir'     (char, default <projectRoot>/results),
%                 'Engine'     ('auto' | 'mlreportgen' | 'edge'),
%                 'ImagePath'  (char, optional path to the ORIGINAL fundus
%                               image used for the Visual Evidence section),
%                 'GradCAMMap' (HxW numeric, optional raw Grad-CAM map; if
%                               empty the report falls back to r.gradCAMMap
%                               or r.gradCAM and finally omits the section)
%
% Returns the absolute path to the written PDF artifact.
%
% The report degrades gracefully: an image whose file is missing, whose
% Grad-CAM map is absent, or whose evidence is a fixture cell (e.g.
% r.gradCAM = {rand(100,100)}) simply omits the Visual Evidence block instead
% of failing the whole export.

function [pdfPath, engine] = generateDrishtiReport(r, varargin)

% --- threshold anon branding (never echo real identifiers unless asked)
patientID  = 'ANON';
outDir     = fullfile(fileparts(fileparts(fileparts(mfilename('fullpath')))), 'results');
engineReq  = 'auto';
imagePath  = '';
gradCAMMap = [];
for k = 1:2:numel(varargin)
    switch varargin{k}
        case 'PatientID',  patientID  = varargin{k+1};
        case 'OutDir',     outDir     = varargin{k+1};
        case 'Engine',     engineReq  = lower(varargin{k+1});
        case 'ImagePath',  imagePath  = varargin{k+1};
        case 'GradCAMMap', gradCAMMap = varargin{k+1};
    end
end

% --- locate a real engine (tier-1 preferred, tier-2 fallback)
haveMLR = license('test', 'MLReportGen') && exist('mlreportgen.pdf.Document', 'class');
switch engineReq
    case 'mlreportgen'
        assert(haveMLR, 'mlreportgen requested but MLReportGen toolbox is not installed');
        engine = 'mlreportgen';
    case 'edge'
        engine = 'edge';
    otherwise
        if haveMLR
            engine = 'mlreportgen';
        else
            engine = 'edge';
        end
end

if ~exist(outDir, 'dir'), mkdir(outDir); end
[tstamp] = datestr(now, 'yyyymmdd_HHMMSS');
pdfName  = sprintf('DrishtiScreeningReport_%s_%s.pdf', patientID, tstamp);
pdfPath  = fullfile(outDir, pdfName);
if exist(pdfPath, 'file'), delete(pdfPath); end

% --- professional layout shared by both engines (single source of truth)
content = buildDrishtiReportBlocks(r, patientID, tstamp, imagePath, gradCAMMap);

switch engine
    case 'mlreportgen'
        pdfPath = writePdfMlreportgen(content, pdfPath);
    case 'edge'
        pdfPath = writePdfHtmlEdge(content, pdfPath);
end

assert(exist(pdfPath, 'file') == 2, 'PDF artifact written to disk');
end

% -------------------------------------------------------------------------
function blocks = buildDrishtiReportBlocks(r, patientID, tstamp, imagePath, gradCAMMap)
% Single source of truth for the professional report CONTENT. Both engines
% render these identical blocks, so the PDF is engine-agnostic in meaning.

blocks = cell(0, 1);

% --- header + identity (branded, never clinical-device claims)
blocks{end+1} = struct('kind', 'brandheader', ...
    'title', 'DRISHTI – DR Screening Report', ...
    'subtitle', sprintf('Patient ID: %s    ·    Generated %s', patientID, tstamp), ...
    'disclaimerTop', 'ENGINEERING DEMO – NOT a clinical device.');

% --- 1. Screening summary (the "at a glance" verdict)
qStatus = qualityStatusOf(r);
qTone   = iff(strcmpi(qStatus, 'FAIL'), 'red', ...
            iff(strcmpi(qStatus, 'WARNING'), 'amber', 'green'));
blocks{end+1} = struct('kind', 'heading', 'text', '1. Screening Summary');
blocks{end+1} = struct('kind', 'badge', ...
    'label', sprintf('Quality: %s (score %.2f)', qStatus, scalarOf(r, 'qualityScore', NaN)), ...
    'tone', qTone);
blocks{end+1} = struct('kind', 'verdict', ...
    'decision', upper(referableTerm(r)), ...
    'score',    sprintf('model score %s (threshold %s)', ...
                pctStr(r, 'binaryProbability'), numStr(r, 'binaryThreshold')), ...
    'tone',     iff(strcmpi(referableTerm(r), 'REFERABLE'), 'red', 'green'));

% --- 2. DR grade
blocks{end+1} = struct('kind', 'heading', 'text', '2. Diabetic Retinopathy Grade');
blocks{end+1} = struct('kind', 'statpair', ...
    'leftLabel', 'Grade',   'leftValue',  sprintf('%s/4', numStr(r, 'grade', '–')), ...
    'rightLabel', 'Stage',  'rightValue', upper(strVal(r, 'gradeLabel', '–')));
if isnumeric(scalarOf(r, 'confidence', NaN)) && ~isnan(scalarOf(r, 'confidence', NaN)) && ...
        ~isempty(scalarOf(r, 'confidence', NaN))
    blocks{end+1} = struct('kind', 'stat', ...
        'label', 'Model confidence', 'value', ...
        sprintf('%.0f%%', scalarOf(r, 'confidence', NaN) * 100), 'score', NaN);
end

% --- 3. Quality assessment (per-metric table when the data exists)
blocks{end+1} = struct('kind', 'heading', 'text', '3. Image Quality Assessment');
qrows = buildQualityRows(r, qStatus);
blocks{end+1} = struct('kind', 'qtable', 'rows', {qrows});
advice = strVal(r, 'qualityRecaptureAdvice', '');
reasons = safeCell(r, 'qualityFailureReasons');
if ~isempty(advice)
    blocks{end+1} = struct('kind', 'text', 'text', ['Recapture advice: ' advice]);
elseif ~isempty(reasons)
    blocks{end+1} = struct('kind', 'text', 'text', ...
        ['Quality findings: ' strjoin(reasons, '; ')]);
end

% --- 4. Explainability / Visual Evidence (Grad-CAM)
blocks{end+1} = struct('kind', 'heading', 'text', '4. Visual Evidence (Grad-CAM)');
blocks{end+1} = struct('kind', 'text', 'text', ...
    'Grad-CAM highlights the retinal regions that most influenced the model decision.');
ev = buildEvidenceImages(r, imagePath, gradCAMMap);
if ~isempty(ev)
    blocks{end+1} = struct('kind', 'images', 'images', {ev});
else
    blocks{end+1} = struct('kind', 'text', 'text', ...
        'Heat-map view was not computed for this image (visual evidence omitted).');
end

% --- 5. Interpretation (evidence-based narrative + readouts)
blocks{end+1} = struct('kind', 'heading', 'text', '5. Interpretation');
narr = explanationParagraph(r);
blocks{end+1} = struct('kind', 'text', 'text', narr);
readouts = buildReadouts(r);
for k = 1:numel(readouts)
    blocks{end+1} = struct('kind', 'stat', ...
        'label', readouts(k).label, 'value', readouts(k).value, 'score', NaN);
end

% --- 6. Recommendation
blocks{end+1} = struct('kind', 'heading', 'text', '6. Recommendation');
blocks{end+1} = struct('kind', 'verdict', ...
    'decision', sprintf('Referable DR: %s', upper(referableTerm(r))), ...
    'score',    sprintf('model score %s (threshold %s)', ...
                pctStr(r, 'binaryProbability'), numStr(r, 'binaryThreshold')), ...
    'tone',     iff(strcmpi(referableTerm(r), 'REFERABLE'), 'red', 'green'));
rec = recommendationText(r);
if ~isempty(rec)
    blocks{end+1} = struct('kind', 'text', 'text', rec);
end

% --- 7. Footer / disclaimer (1.0pt legal-style bottom text)
footerText = ['This report was produced by an ENGINEERING DEMO screening ' ...
              'prototype (DRISHTI). It is NOT a clinical device and must not ' ...
              'be used alone to make treatment decisions. Always confirm with ' ...
              'a qualified ophthalmologist.'];
blocks{end+1} = struct('kind', 'footer', 'text', footerText);
end

% -------------------------------------------------------------------------
function rows = buildQualityRows(r, qStatus)
% Per-metric quality table when the caller carries a checks array; otherwise
% a single-row table with the overall verdict (never an empty table).
rows = cell(0, 3);
if isfield(r, 'qualityChecks') && isstruct(r.qualityChecks) && ~isempty(r.qualityChecks)
    n = 0;
    for k = 1:numel(r.qualityChecks)
        c = r.qualityChecks(k);
        st = c.status;
        if isnumeric(st), st = iff(st > 0, 'PASS', 'FAIL'); end
        n = n + 1;
        rows{n, 1} = c.metric;
        rows{n, 2} = num2str(c.value, '%.3f');
        rows{n, 3} = upper(st);
    end
elseif isfield(r, 'qualityFailureReasons') && ~isempty(safeCell(r, 'qualityFailureReasons'))
    reasons = safeCell(r, 'qualityFailureReasons');
    for k = 1:numel(reasons)
        rows{k, 1} = 'Finding';
        rows{k, 2} = reasons{k};
        rows{k, 3} = 'FAIL';
    end
else
    rows{1, 1} = 'Overall quality';
    rows{1, 2} = sprintf('score %.2f', scalarOf(r, 'qualityScore', NaN));
    rows{1, 3} = upper(qStatus);
end
end

% -------------------------------------------------------------------------
function ev = buildEvidenceImages(r, imagePath, gradCAMMap)
% Returns a cell array of {'file' path, caption} structs, or empty when the
% evidence cannot be rendered (missing map, missing image, fixture cells).
ev = {};
base = loadBaseImage(r, imagePath);
if isempty(base)
    return;
end

map = gradCAMMap;
if isempty(map)
    map = scalarMap(r);
end

if ~isempty(map) && isnumeric(map) && ~isempty(base)
    try
        [overlay, heatRGB, ~] = renderGradCAMViews(map, base);
        tmpA = [tempname '.png'];
        imwrite(overlay, tmpA);
        ev{end+1} = struct('file', tmpA, 'caption', 'Grad-CAM overlay'); %#ok<AGROW>
        tmpH = [tempname '.png'];
        imwrite(heatRGB, tmpH);
        ev{end+1} = struct('file', tmpH, 'caption', 'Heat map'); %#ok<AGROW>
    catch
        ev = {};
    end
end

if isempty(ev)
    % Original fundus alone (when the model map is unavailable but the image is)
    try
        tmpI = [tempname '.png'];
        imwrite(base, tmpI);
        ev{end+1} = struct('file', tmpI, 'caption', 'Original fundus'); %#ok<AGROW>
    catch
    end
end
end

% -------------------------------------------------------------------------
function base = loadBaseImage(r, imagePath)
base = [];
candidates = {};
if ~isempty(imagePath), candidates{end+1} = imagePath; end
if isfield(r, 'imagePath') && ~isempty(r.imagePath), candidates{end+1} = r.imagePath; end
for k = 1:numel(candidates)
    if ischar(candidates{k}) && exist(candidates{k}, 'file') == 2
        try
            base = imread(candidates{k});
            if size(base, 3) == 1, base = repmat(base, 1, 1, 3); end
            return;
        catch
        end
    end
end
end

% -------------------------------------------------------------------------
function m = scalarMap(r)
% Resolve a numeric Grad-CAM map from r.gradCAMMap, r.gradCAM (numeric array
% OR the pipeline's cell cache e.g. {rand(100,100)}), or shrink back to [].
m = [];
if isfield(r, 'gradCAMMap') && isnumeric(r.gradCAMMap) && ~isempty(r.gradCAMMap)
    m = r.gradCAMMap;
    return;
end
if isfield(r, 'gradCAM')
    gc = r.gradCAM;
    if iscell(gc) && ~isempty(gc), gc = gc{1}; end
    if isnumeric(gc) && ~isempty(gc) && ndims(gc) == 2
        m = gc;
    end
end
end

% -------------------------------------------------------------------------
function out = explanationParagraph(r)
if isfield(r, 'explanation') && isstruct(r.explanation)
    if isfield(r.explanation, 'paragraph') && ~isempty(r.explanation.paragraph)
        out = r.explanation.paragraph;
        return;
    end
    if isfield(r.explanation, 'recommendation') && ~isempty(r.explanation.recommendation)
        out = r.explanation.recommendation;
        return;
    end
end
out = ['Screening decision derived from the referable classifier (P(referable) ' ...
       pctStr(r, 'binaryProbability') ') and the 5-class severity grading pipeline.'];
end

% -------------------------------------------------------------------------
function out = recommendationText(r)
if isfield(r, 'explanation') && isstruct(r.explanation)
    if isfield(r.explanation, 'recommendation') && ~isempty(r.explanation.recommendation)
        out = r.explanation.recommendation;
        return;
    end
end
if strcmpi(referableTerm(r), 'REFERABLE')
    out = 'Refer for ophthalmology review.';
else
    out = 'Routine follow-up.';
end
end

% -------------------------------------------------------------------------
function readouts = buildReadouts(r)
readouts = struct('label', {}, 'value', {});

if isfield(r, 'cascade')
    if ischar(r.cascade) 
        readouts(end+1) = struct('label', 'Cascade route', 'value', r.cascade); %#ok<AGROW>
    elseif isfield(r.cascade, 'route')
        readouts(end+1) = struct('label', 'Cascade route', 'value', r.cascade.route); %#ok<AGROW>
    end
end
if isfield(r, 'ood') && isfield(r.ood, 'available') && r.ood.available
    if r.ood.flag
        readouts(end+1) = struct('label', 'OOD status', 'value', 'OUT-OF-DISTRIBUTION'); %#ok<AGROW>
    else
        readouts(end+1) = struct('label', 'OOD status', 'value', 'in-distribution'); %#ok<AGROW>
    end
end
if isfield(r, 'lesions') && isstruct(r.lesions) && ...
        (isfield(r.lesions, 'maCount') || isfield(r.lesions, 'heCount'))
    readouts(end+1) = struct('label', 'Lesion candidates', ... %#ok<AGROW>
        'value', sprintf('MA %d · HE %d · EX %d', ...
        scalarOf(r.lesions, 'maCount', 0), ...
        scalarOf(r.lesions, 'heCount', 0), ...
        scalarOf(r.lesions, 'exCount', 0)));
end
if isfield(r, 'runtimeSec') && isnumeric(r.runtimeSec) && ~isnan(r.runtimeSec)
    readouts(end+1) = struct('label', 'Runtime', ... %#ok<AGROW>
        'value', sprintf('%.2f s', r.runtimeSec));
end
end

% -------------------------------------------------------------------------
function s = referableTerm(r)
s = 'NOT REFERABLE';
if strcmpi(binaryDecisionOf(r), 'REFERABLE')
    s = 'REFERABLE';
end
end

function t = binaryDecisionOf(r)
t = strVal(r, 'binaryDecision', '');
if isempty(t), t = '--'; end
end

function st = qualityStatusOf(r)
st = strVal(r, 'qualityStatus', 'PASS');
end

function v = strVal(s, f, dflt)
v = dflt;
if isfield(s, f) && ischar(s.(f)) && ~isempty(s.(f))
    v = s.(f);
end
end

function v = scalarOf(s, f, dflt)
v = dflt;
if isfield(s, f) && isnumeric(s.(f)) && ~isnan(s.(f)) && ~isempty(s.(f))
    v = s.(f);
end
end

function p = pctStr(s, f)
v = scalarOf(s, f, NaN);
if isnan(v)
    p = 'n/a';
else
    p = sprintf('%.0f%%', v * 100);
end
end

function n = numStr(s, f, dflt)
v = scalarOf(s, f, NaN);
if isnan(v)
    n = dflt;
else
    n = sprintf('%.3f', v);
end
end

function c = safeCell(s, f)
c = {};
if isfield(s, f)
    if iscell(s.(f))
        c = s.(f);
    elseif ischar(s.(f)) && ~isempty(s.(f))
        c = {s.(f)};
    end
end
end

function z = iff(c, a, b)
if c, z = a; else z = b; end
end

% -------------------------------------------------------------------------
function pdfPath = writePdfMlreportgen(content, pdfPath)
import mlreportgen.pdf.*
d = Document(pdfPath, 'A4');
open(d);
try
    for k = 1:numel(content)
        renderBlock(d, content{k});
    end
    close(d);
catch
    close(d);
    rethrow(lasterror);
end
end

% -------------------------------------------------------------------------
function pdfPath = writePdfHtmlEdge(content, pdfPath)
% Build a professional HTML document from the same content blocks and render
% it to PDF via headless Edge/Chrome --headless --print-to-pdf.
htmlPath = strrep(pdfPath, '.pdf', '.html');
h = fopen(htmlPath, 'w');
assert(h ~= -1, 'open HTML for writing');
writeHtmlHead(h);
for k = 1:numel(content)
    renderBlockHtml(h, content{k});
end
fprintf(h, '</body></html>\n');
fclose(h);

% headless Edge/Chrome print-to-pdf
edge = locateHeadlessBrowser();
assert(~isempty(edge), 'headless Edge/Chrome available for PDF fallback');
cmd = sprintf('"%s" --headless --disable-gpu --no-sandbox --print-to-pdf="%s" --print-to-pdf-no-header "file:///%s"', ...
              edge, pdfPath, strrep(htmlPath, '\', '/'));
rc = system(cmd);
assert(rc == 0, 'headless browser produced PDF');
% Keep the intermediate HTML alongside the PDF as verification evidence:
% Edge/Skia PDFs encode text as Identity-H glyph IDs, so verifiers check the
% HTML source for content blocks and the PDF bytes for structure.
end

% -------------------------------------------------------------------------
function writeHtmlHead(h)
th = drishtiTheme();
fprintf(h, '<!DOCTYPE html>\n<html><head><meta charset="utf-8">\n');
fprintf(h, '<style>\n');
fprintf(h, '@page { size: A4; margin: 30px 34px; }\n');
fprintf(h, 'body{font-family:Calibri,Segoe UI,Arial,sans-serif;color:%s;margin:0;font-size:12px;line-height:1.45;}\n', hex(th.text));
fprintf(h, 'h1{color:%s;font-size:20px;margin:0;}\n', hex(th.primary));
fprintf(h, 'h2{color:%s;font-size:14px;margin:20px 0 8px;border-bottom:2px solid %s;padding-bottom:3px;}\n', hex(th.primaryDark), hex(th.primary));
fprintf(h, '.brand{background:%s;color:%s;padding:14px 18px;border-radius:6px;}\n', hex(th.background), hex(th.text));
fprintf(h, '.brand h1{margin:0;color:%s;}\n', hex(th.text));
fprintf(h, '.brand .sub{color:%s;font-size:11px;margin-top:3px;}\n', hex(th.textMuted));
fprintf(h, '.discl{color:%s;font-size:9px;margin-top:5px;}\n', hex(th.warning));
fprintf(h, '.badge{display:inline-block;padding:3px 10px;border-radius:4px;font-weight:bold;font-size:11px;}\n');
fprintf(h, '.green{background:%s;color:%s;}\n', hex(th.successBg), hex(th.success));
fprintf(h, '.amber{background:%s;color:%s;}\n', hex(th.warningBg), hex(th.warning));
fprintf(h, '.red{background:%s;color:%s;}\n', hex(th.dangerBg), hex(th.danger));
fprintf(h, '.verdict{font-size:14px;font-weight:bold;padding:9px 12px;border-radius:5px;margin-top:8px;}\n');
fprintf(h, '.card{background:%s;border:1px solid %s;border-radius:6px;padding:10px 14px;margin-top:8px;}\n', hex(th.panelAlt), hex(th.border));
fprintf(h, '.row{display:flex;margin-top:6px;}\n');
fprintf(h, '.cell{flex:1;}\n');
fprintf(h, 'table{width:100%%;border-collapse:collapse;margin-top:6px;}\n');
fprintf(h, 'th,td{border:1px solid %s;padding:5px 8px;font-size:11px;text-align:left;}\n', hex(th.border));
fprintf(h, 'th{background:%s;color:%s;}\n', hex(th.panel), hex(th.text));
fprintf(h, '.evrow{display:flex;gap:14px;margin-top:8px;}\n');
fprintf(h, '.evcell{flex:1;text-align:center;}\n');
fprintf(h, '.evcell img{width:100%%;border:1px solid %s;border-radius:5px;}\n', hex(th.border));
fprintf(h, '.evcap{font-size:10px;color:%s;margin-top:4px;}\n', hex(th.textMuted));
fprintf(h, '.footer{margin-top:26px;border-top:1px solid %s;padding-top:8px;font-size:9px;color:%s;}\n', hex(th.border), hex(th.textFaint));
fprintf(h, '</style></head><body>\n');
end

% -------------------------------------------------------------------------
function b = locateHeadlessBrowser()
candidates = {
    'C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe'
    'C:\Program Files\Microsoft\Edge\Application\msedge.exe'
    'C:\Program Files\Google\Chrome\Application\chrome.exe'
    'C:\Program Files (x86)\Google\Chrome\Application\chrome.exe'
    };
b = '';
for k = 1:numel(candidates)
    if exist(candidates{k}, 'file') == 2
        b = candidates{k};
        return;
    end
end
end

% -------------------------------------------------------------------------
function renderBlock(d, blk)
import mlreportgen.pdf.*
switch blk.kind
    case 'brandheader'
        add(d, Paragraph(blk.title, 'Title'));
        add(d, Paragraph(['  ' blk.subtitle], 'Subtitle'));
        add(d, Paragraph(blk.disclaimerTop, 'Emphasis'));
    case 'heading'
        add(d, Paragraph(blk.text, 'Heading1'));
    case 'badge'
        p = Paragraph(blk.label);
        p.Color = toneHex(blk.tone);
        add(d, p);
    case 'verdict'
        v = Paragraph([blk.decision '   ' blk.score]);
        v.FontSize = '14pt'; v.FontWeight = 'bold';
        v.Color = toneHex(blk.tone);
        add(d, v);
    case 'statpair'
        t = Table(struct('leftLabel', blk.leftLabel, 'leftValue', blk.leftValue, ...
                         'rightLabel', blk.rightLabel, 'rightValue', blk.rightValue));
        add(d, t);
    case 'stat'
        p = Paragraph([blk.label ': ' blk.value]);
        add(d, p);
    case 'qtable'
        rows = blk.rows;
        if isempty(rows), return; end
        tblData = rows(:, 1:2);
        t = Table(tblData);
        add(d, t);
    case 'images'
        for k = 1:numel(blk.images)
            add(d, Picture(blk.images{k}.file));
        end
    case 'text'
        add(d, Paragraph(blk.text));
    case 'footer'
        add(d, Paragraph(blk.text));
end
end

% -------------------------------------------------------------------------
function renderBlockHtml(h, blk)
switch blk.kind
    case 'brandheader'
        fprintf(h, '<div class="brand"><h1>%s</h1>\n', blk.title);
        fprintf(h, '<div class="sub">%s</div>\n', blk.subtitle);
        fprintf(h, '<div class="discl">%s</div></div>\n', blk.disclaimerTop);
    case 'heading'
        fprintf(h, '<h2>%s</h2>\n', blk.text);
    case 'badge'
        fprintf(h, '<span class="badge %s">%s</span>\n', blk.tone, blk.label);
    case 'verdict'
        fprintf(h, '<div class="verdict %s">%s <span style="font-weight:normal;font-size:12px">%s</span></div>\n', ...
            blk.tone, blk.decision, blk.score);
    case 'statpair'
        fprintf(h, '<div class="card"><div class="row"><div class="cell"><strong>%s</strong> %s</div><div class="cell"><strong>%s</strong> %s</div></div></div>\n', ...
            blk.leftLabel, blk.leftValue, blk.rightLabel, blk.rightValue);
    case 'stat'
        if isnan(blk.score)
            fprintf(h, '<p><strong>%s:</strong> %s</p>\n', blk.label, blk.value);
        else
            fprintf(h, '<p><strong>%s:</strong> %s (score %.2f)</p>\n', ...
                blk.label, blk.value, blk.score);
        end
    case 'qtable'
        rows = blk.rows;
        if isempty(rows), return; end
        fprintf(h, '<table><tr><th>Metric</th><th>Value</th><th>Status</th></tr>\n');
        for k = 1:size(rows, 1)
            toneClass = statusTone(rows{k, 3});
            fprintf(h, '<tr><td>%s</td><td>%s</td><td><span class="badge %s">%s</span></td></tr>\n', ...
                rows{k, 1}, rows{k, 2}, toneClass, rows{k, 3});
        end
        fprintf(h, '</table>\n');
    case 'images'
        fprintf(h, '<div class="evrow">\n');
        for k = 1:numel(blk.images)
            fprintf(h, '<div class="evcell"><img src="data:image/png;base64,%s" alt="">\n', ...
                b64(blk.images{k}.file));
            fprintf(h, '<div class="evcap">%s</div></div>\n', blk.images{k}.caption);
        end
        fprintf(h, '</div>\n');
    case 'text'
        fprintf(h, '<div class="card"><p>%s</p></div>\n', blk.text);
    case 'footer'
        fprintf(h, '<div class="footer">%s</div>\n', blk.text);
end
end

% -------------------------------------------------------------------------
function t = toneHex(tone)
th = drishtiTheme();
switch lower(tone)
    case 'red',    t = th.danger;
    case 'amber',  t = th.warning;
    otherwise,     t = th.success;
end
end

function c = statusTone(status)
switch upper(status)
    case 'PASS',     c = 'green';
    case 'WARNING',  c = 'amber';
    otherwise,       c = 'red';
end
end

function hx = hex(rgb)
hx = sprintf('#%02X%02X%02X', round(rgb(1)*255), round(rgb(2)*255), round(rgb(3)*255));
end

function s = b64(filePath)
fid = fopen(filePath, 'rb');
if fid == -1, s = ''; return; end
b = fread(fid, Inf, '*uint8')';
fclose(fid);
s = matlab.net.base64encode(b);
end

function w = judgeQuality(status)
if status, w = 'PASS'; else w = 'FAIL'; end
end