% run_verify_report_headless_direct.m  (plain script - no function blocks)
% Drives the REAL on-disk generateDrishtiReport against the app-contract
% fixture, then writes MATLAB's OWN verdict to results\_verify_report_verdict.txt.
% Native-read that file afterward = ground truth from disk.
projectRoot = 'C:\projects\DrishtiCare';
outDir = fullfile(projectRoot, 'results');
if exist(outDir, 'dir') ~= 7, mkdir(outDir); end
vfile = fullfile(outDir, '_verify_report_verdict.txt');
fid = fopen(vfile, 'w');
if fid < 0, error('cannot open verdict file'); end
try
    addpath(projectRoot);
    addpath(genpath(fullfile(projectRoot, 'src')));

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

    [pdfPath, engine] = generateDrishtiReport(r, ...
        'PatientID', 'DRISHTI-0001', 'OutDir', outDir);

    if exist(pdfPath, 'file') == 2
        d = dir(pdfPath);
        fprintf(fid, 'VERDICT=PASS\n');
        fprintf(fid, 'PDF=%s\n', pdfPath);
        fprintf(fid, 'ENGINE=%s\n', engine);
        fprintf(fid, 'BYTES=%d\n', d.bytes);
        fh = fopen(pdfPath, 'rb');
        hdr = fread(fh, 4, '*char')';
        fclose(fh);
        fprintf(fid, 'HEADER=%s\n', hdr);
    else
        fprintf(fid, 'VERDICT=FAIL\n');
        fprintf(fid, 'MSG=pdf artifact missing\n');
    end
catch err
    fprintf(fid, 'VERDICT=FAIL\n');
    fprintf(fid, 'MSG=%s\n', err.message);
    if ~isempty(err.stack)
        fprintf(fid, 'AT=%s:%d\n', err.stack(1).name, err.stack(1).line);
    end
end
fclose(fid);
