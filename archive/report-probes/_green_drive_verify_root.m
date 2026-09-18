% _green_drive_verify.m  (flat script, NO function blocks)
% Drives the REAL generateDrishtiReport + REAL verify_drishti_report headlessly.
% verify_drishti_report declares NO output arguments, so it is called BARE
% (capturing outputs would be a bug). MATLAB writes its OWN verdict + artifact
% facts to results\_green_verdict.txt; native-read that file off disk.
projectRoot = 'C:\projects\DrishtiCare';
outDir = fullfile(projectRoot, 'results');
if exist(outDir, 'dir') ~= 7, mkdir(outDir); end
vfile = fullfile(outDir, '_green_verdict.txt');
fid = fopen(vfile, 'w');
if fid < 0, error('cannot open green verdict file'); end
addpath(projectRoot);
addpath(genpath(fullfile(projectRoot, 'src')));

% --- result fixture matching the app-documented result contract
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
r.gradCAM           = {rand(100, 100)};

% --- 1. REAL generator: engine + path come straight from MATLAB's code
try
    [pdfPath, engine] = generateDrishtiReport(r, ...
        'PatientID', 'DRISHTI-0001', 'OutDir', outDir);
    d = dir(pdfPath);
    bytes = d.bytes;
    fh = fopen(pdfPath, 'rb');
    hdr = fread(fh, 4, '*char')';
    fclose(fh);
    fprintf(fid, 'GENERATOR=OK\n');
    fprintf(fid, 'PDF=%s\n', pdfPath);
    fprintf(fid, 'BYTES=%d\n', bytes);
    fprintf(fid, 'HEADER=%s\n', hdr);
    fprintf(fid, 'ENGINE=%s\n', engine);
    if strcmp(hdr, '%PDF') && bytes > 3000
        fprintf(fid, 'ARTIFACT=PASS\n');
    else
        fprintf(fid, 'ARTIFACT=FAIL\n');
    end
    fprintf('GENERATOR=OK %s bytes=%d header=%s engine=%s\n', pdfPath, bytes, hdr, engine);
catch err
    fprintf(fid, 'GENERATOR=FAIL\n');
    fprintf(fid, 'ERR=%s\n', err.message);
    if ~isempty(err.stack)
        fprintf(fid, 'AT=%s:%d\n', err.stack(1).name, err.stack(1).line);
    end
    fprintf('GENERATOR=FAIL %s\n', err.message);
end

% --- 2. REAL verifier, BARE call (it declares no outputs)
try
    verify_drishti_report(projectRoot);
    fprintf(fid, 'VERIFY=RAN-OK\n');
    fprintf('VERIFY=RAN-OK\n');
catch err
    fprintf(fid, 'VERIFY=THREW\n');
    fprintf(fid, 'VERIFY_ERR=%s\n', err.message);
    if ~isempty(err.stack)
        fprintf(fid, 'VERIFY_AT=%s:%d\n', err.stack(1).name, err.stack(1).line);
    end
    fprintf('VERIFY=THREW %s\n', err.message);
end
fclose(fid);
fprintf('GREEN_DRIVE_DONE\n');