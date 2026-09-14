% generateDrishtiReport.m
% Professional PDF screening report generator for the DRISHTI DR screening app.
%
% Flat, single-responsibility house-style function: takes the SAME result
% struct that RetinaAIApp.m's displayReport/displayRecommendation/displayGrade
% callbacks consume (see RetinaAIApp.m L609-651), and produces a BRANDED,
% ARTICULATED, A4 professional PDF screening report designed for the patient
% / referring clinician.
%
% Engine selection (two-tier, no toolbox hard-requirement):
%   tier-1  MATLAB Report Generator (mlreportgen.pdf.Document) - preferred
%   tier-2  headless Edge/Chrome HTML -> PDF fallback (no toolbox needed)
%
% The output is a REAL PDF artifact on disk at OutDir, named
% DrishtiScreeningReport_<patientID>_<yyyyMMdd_HHmmss>.pdf
%
% Signature:
%   [pdfPath] = generateDrishtiReport(result, ...)
%     Name-Value: 'PatientID' (char, default 'ANON'),
%                 'OutDir'    (char, default <projectRoot>/results),
%                 'Engine'    ('auto' | 'mlreportgen' | 'edge')
%
% Returns the absolute path to the written PDF artifact.

function [pdfPath, engine] = generateDrishtiReport(r, varargin)

% --- threshold anon branding (never echo real identifiers unless asked)
patientID = 'ANON';
outDir    = fullfile(fileparts(fileparts(fileparts(mfilename('fullpath')))), 'results');
engineReq = 'auto';
for k = 1:2:numel(varargin)
    switch varargin{k}
        case 'PatientID', patientID = varargin{k+1};
        case 'OutDir',    outDir    = varargin{k+1};
        case 'Engine',    engineReq = lower(varargin{k+1});
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
content = buildDrishtiReportBlocks(r, patientID);

switch engine
    case 'mlreportgen'
        pdfPath = writePdfMlreportgen(content, pdfPath);
    case 'edge'
        pdfPath = writePdfHtmlEdge(content, pdfPath);
end

assert(exist(pdfPath, 'file') == 2, 'PDF artifact written to disk');
end

% -------------------------------------------------------------------------
function blocks = buildDrishtiReportBlocks(r, patientID)
% Single source of truth for the professional report CONTENT. Both engines
% render these identical blocks, so the PDF is engine-agnostic in meaning.

blocks = cell(0, 1);

% --- header + identity (branded, never clinical-device claims)
blocks{end+1} = struct('kind', 'brandheader', ...
    'title', 'DRISHTI \u2013 DR Screening Report', ...
    'subtitle', sprintf('Patient ID: %s', patientID), ...
    'disclaimerTop', 'ENGINEERING DEMO - NOT a clinical device.');

% --- 1. Screening summary (the "at a glance" verdict)
blocks{end+1} = struct('kind', 'heading', 'text', '1. Screening Summary');
if r.qualityStatus
    blocks{end+1} = struct('kind', 'badge', ...
        'label', sprintf('Quality: %s (%.2f)', judgeQuality(r.qualityStatus), r.qualityScore), ...
        'tone', 'green');
else
    blocks{end+1} = struct('kind', 'badge', ...
        'label', sprintf('Image quality FAIL \u2013 analysis withheld'), ...
        'tone', 'red');
end
blocks{end+1} = struct('kind', 'verdict', ...
    'decision', upper(r.binaryDecision), ...
    'score',    sprintf('model score %.0f%% (threshold %.2f)', r.binaryProbability * 100, r.binaryThreshold), ...
    'tone',     iff(strcmp(upper(r.binaryDecision), 'REFERABLE'), 'red', 'green'));

% --- 2. DR grade
blocks{end+1} = struct('kind', 'heading', 'text', '2. Diabetic Retinopathy Grade');
blocks{end+1} = struct('kind', 'statpair', ...
    'leftLabel', 'Grade',    'leftValue',  sprintf('%d / 4', r.grade), ...
    'rightLabel', 'Stage',   'rightValue', upper(r.gradeLabel));

% --- 3. Quality assessment
blocks{end+1} = struct('kind', 'heading', 'text', '3. Image Quality Assessment');
blocks{end+1} = struct('kind', 'stat', ...
    'label', 'Quality status', 'value', judgeQuality(r.qualityStatus), ...
    'score', r.qualityScore);

% --- 4. Explainability (Grad-CAM)
blocks{end+1} = struct('kind', 'heading', 'text', '4. Explainability (Grad-CAM)');
blocks{end+1} = struct('kind', 'text', 'text', ...
    'Grad-CAM highlights the retinal regions that most influenced the model decision.');

% --- 5. Recommendation / referable
blocks{end+1} = struct('kind', 'heading', 'text', '5. Recommendation');
blocks{end+1} = struct('kind', 'verdict', ...
    'decision', sprintf('Referable DR: %s', upper(r.binaryDecision)), ...
    'score',    sprintf('model score %.0f%% (threshold %.2f)', r.binaryProbability * 100, r.binaryThreshold), ...
    'tone',     iff(strcmp(upper(r.binaryDecision), 'REFERABLE'), 'red', 'green'));

% --- 6. Footer / disclaimer (1.0pt legal-style bottom text)
footerText = ['This report was produced by an ENGINEERING DEMO screening ' ...
              'prototype (DRISHTI). It is NOT a clinical device and must not ' ...
              'be used alone to make treatment decisions. Always confirm with ' ...
              'a qualified ophthalmologist.'];
blocks{end+1} = struct('kind', 'footer', 'text', footerText);
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
fprintf(h, '<!DOCTYPE html>\n<html><head><meta charset="utf-8">\n');
fprintf(h, '<style>\n');
fprintf(h, 'body{font-family:Georgia,serif;color:#222;margin:36px;font-size:12px;}\n');
fprintf(h, 'h1{color:#0b3d91;border-bottom:2px solid #0b3d91;font-size:20px;}\n');
fprintf(h, 'h2{color:#0b3d91;font-size:15px;margin-top:18px;}\n');
fprintf(h, '.badge{display:inline-block;padding:3px 9px;border-radius:3px;font-weight:bold;}\n');
fprintf(h, '.green{background:#d8f0dc;color:#166534;}\n');
fprintf(h, '.red{background:#fde8e8;color:#b91c1c;}\n');
fprintf(h, '.verdict{font-size:15px;font-weight:bold;padding:8px;}\n');
fprintf(h, '.row{display:flex;}\n');
fprintf(h, '.cell{flex:1;}\n');
fprintf(h, '.footer{margin-top:30px;border-top:1px solid #ccc;padding-top:8px;font-size:9px;color:#666;}\n');
fprintf(h, '</style></head><body>\n');
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
delete(htmlPath); % clean the intermediate HTML
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
        p = Paragraph([blk.label ': ' blk.value sprintf(' (score %.2f)', blk.score)]);
        add(d, p);
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
        fprintf(h, '<h1>%s</h1>\n', blk.title);
        fprintf(h, '<p><em>%s &mdash; %s</em></p>\n', blk.subtitle, blk.disclaimerTop);
    case 'heading'
        fprintf(h, '<h2>%s</h2>\n', blk.text);
    case 'badge'
        fprintf(h, '<span class="badge %s">%s</span>\n', blk.tone, blk.label);
    case 'verdict'
        fprintf(h, '<div class="verdict %s">%s <span style="font-weight:normal">%s</span></div>\n', ...
            blk.tone, blk.decision, blk.score);
    case 'statpair'
        fprintf(h, '<div class="row"><div class="cell"><strong>%s</strong> %s</div><div class="cell"><strong>%s</strong> %s</div></div>\n', ...
            blk.leftLabel, blk.leftValue, blk.rightLabel, blk.rightValue);
    case 'stat'
        fprintf(h, '<p><strong>%s:</strong> %s (score %.2f)</p>\n', ...
            blk.label, blk.value, blk.score);
    case 'text'
        fprintf(h, '<p>%s</p>\n', blk.text);
    case 'footer'
        fprintf(h, '<div class="footer">%s</div>\n', blk.text);
end
end

% -------------------------------------------------------------------------
function t = toneHex(tone)
if strcmpi(tone, 'red'), t = [0.85 0.15 0.15]; else t = [0.12 0.55 0.30]; end
end

function w = judgeQuality(status)
if status, w = 'PASS'; else w = 'FAIL'; end
end

function z = iff(c, a, b)
if c, z = a; else z = b; end
end
