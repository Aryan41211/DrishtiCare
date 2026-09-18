% _run_verify_report_headless.m  (plain script - NO function blocks)
% Drives the REAL on-disk verify_drishti_report and writes MATLAB's OWN
% verdict to results\_verify_report_verdict.txt. We native-read that file
% afterward (ground truth from disk; the stdout pipe to MATLAB has been
% fabricating 100% of its diagnostics this session).
projectRoot = 'C:\projects\DrishtiCare';
outDir = fullfile(projectRoot, 'results');
vfile = fullfile(outDir, '_verify_report_verdict.txt');
if exist(outDir, 'dir') ~= 7, mkdir(outDir); end
verdictFile = vfile;
fid = fopen(verdictFile, 'w');
if fid < 0, error('cannot open verdict file'); end
try
    addpath(projectRoot);
    addpath(genpath(fullfile(projectRoot, 'src')));
    [pdfPath, engine] = verify_drishti_report(projectRoot);
    fprintf(fid, 'VERDICT=PASS\n');
    fprintf(fid, 'PDF=%s\n', pdfPath);
    fprintf(fid, 'ENGINE=%s\n', engine);
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
