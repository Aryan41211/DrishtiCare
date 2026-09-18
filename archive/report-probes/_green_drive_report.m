% _green_drive_report.m  (plain script; single unit: the REAL generator)
projectRoot = 'C:\projects\DrishtiCare';
outDir = fullfile(projectRoot, 'results');
vfile = fullfile(outDir, '_green_verdict.txt');
if exist(outDir, 'dir') ~= 7, mkdir(outDir); end
fid = fopen(vfile, 'w');
if fid < 0, error('cannot open green verdict file'); end
try
    addpath(projectRoot);
    addpath(genpath(fullfile(projectRoot, 'src')));

    r = struct();
    r.imagePath      = fullfile(projectRoot, 'data', 'splits', 'val', 'class_1', '000c.png');
    r.qualityStatus  = 'PASS';
    r.qualityScore   = 0.91;
    r.qualityGate    = struct('enforced', false);
    r.grade          = 1;
    r.gradeLabel     = 'MODERATE NONPROLIFERATIVE DR';
    r.binaryDecision = 'REFERABLE';
    r.binaryProbability = 0.74;
    r.binaryThreshold   = 0.345;
    r.lesions        = struct('maCount', 4, 'heCount', 7, 'exCount', 1, 'odLocated', true);
    r.ood            = struct('available', true, 'flag', false, 'mahalanobis', 11.5);
    r.cascade        = struct('route', '5-class + binary ensemble');
    r.explanation    = struct('recommendation', 'Refer for ophthalmology review.');
    r.runtimeSec     = 2.84;
    r.gradCAM        = {rand(100, 100)};

    [pdfPath, engine] = generateDrishtiReport(r, ...
        'PatientID', 'DRISHTI-0001', 'OutDir', outDir);

    fprintf(fid, 'VERDICT=PASS\n');
    fprintf(fid, 'PDF=%s\n', pdfPath);
    fprintf(fid, 'ENGINE=%s\n', engineese);
    if exist(pdfPath, 'file') == 2
        d = dir(pdfPath);
        fprintf(fid, 'BYTES=%d\n', d.bytes);
        fh = fopen(pdfPath, 'rb');
        hdr = fread(fh, 4, '*char')';
        fclose(fh);
        fprintf(fid, 'HEADER=%s\n', hdr);
    else
        fprintf(fid, 'HEADER=NOFILE\n');
    end
catch err
    fprintf(fid, 'VERDICT=FAIL\n');
    fprintf(fid, 'ERR=%s\n', err.message);
    if ~isempty(err.stack)
        fprintf(fid, 'AT=%s:%d\n', err.stack(1).name, err.stack(1).line);
    end
end
fclose(fid);
