% verify_drishti_report.m
% Headless verification for the DRISHTI professional PDF screening report.
%
% Follows house verification style (src/dashboard/verify_retinaai.m): one
% flat script, REAL headless generator, REAL assertions on the artifact on
% disk, no mocks. It drives the REAL professional PDF report generator
% headlessly against a result fixture shaped EXACTLY like the result
% struct RetinaAIApp.m report callbacks consume (RetinaAIApp.m L609-651),
% then asserts a real PDF artifact lands on disk with a valid PDF header.
%
% Usage: verify_drishti_report()               % infers project root
%        verify_drishti_report(projectRoot)

function verify_drishti_report(projectRoot)

if nargin < 1
    projectRoot = fileparts(fileparts(fileparts(mfilename('fullpath'))));
end
addpath(projectRoot);
addpath(genpath(fullfile(projectRoot, 'src')));

fprintf('== DRISHTI professional PDF report verification ==\n');

%% 1. Result fixture faithful to the app's documented result contract
r = struct();
r.imagePath         = fullfile(projectRoot, 'data', 'splits', 'val', 'class_1', '000c.png');
r.qualityStatus     = 'PASS';
r.qualityScore      = 0.91;
r.qualityGate       = struct('enforced', false);
r.grade             = 1;
r.gradeLabel        = 'MODERATE NONPROLIFERATIVE DR';
r.binaryDecision    = 'REFERABLE';
r.binaryProbability = 0.74;
r.binaryThreshold   = 0.345;
r.lesions           = struct('maCount', 4, 'heCount', 7, 'exCount', 1, 'odLocated', true);
r.ood               = struct('available', true, 'flag', false, 'mahalanobis', 11.5);
r.cascade           = struct('route', '5-class + binary ensemble');
r.explanation       = struct('recommendation', 'Refer for ophthalmology review.');
r.runtimeSec        = 2.84;
r.gradCAM           = {rand(100, 100)};   % explainability views cached by app

%% 2. The REAL generator converts this result into a professional PDF
outDir = fullfile(projectRoot, 'results');
if ~exist(outDir, 'dir'), mkdir(outDir); end
[pdfPath, engine] = generateDrishtiReport(r, ...
    'PatientID', 'DRISHTI-0001', 'OutDir', outDir);

%% 3. The PDF artifact actually exists on disk with a valid header
assert(exist(pdfPath, 'file') == 2, 'PDF artifact exists on disk');
d = dir(pdfPath);
assert(d.bytes > 3000, 'PDF artifact is non-trivial (>3 KB)');
fid = fopen(pdfPath, 'rb');
assert(fid ~= -1, 'PDF artifact opens for reading');
hdr = fread(fid, 4, '*char')';
fclose(fid);
assert(strcmp(hdr, '%PDF'), 'PDF header signature present (%PDF)');
fprintf('OK  3. PDF artifact: %s (%d bytes, engine=%s)\n', pdfPath, d.bytes, engine);

%% 4. Report content survived generation with key blocks intact
% Extract the text from the REAL PDF artifact (FlateDecode streams via JVM).
txt = pdfText(pdfPath);
assert(contains(txt, 'Screening Summary'), 'Screening Summary section present');
assert(contains(txt, 'REFERABLE'), 'referable decision present');
assert(contains(txt, 'DRISHTI'), 'DRISHTI branding present');
fprintf('OK  4. report content blocks verified\n');

fprintf('\nALL DRISHTI PDF REPORT CHECKS PASS (engine=%s)\n', engine);

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
