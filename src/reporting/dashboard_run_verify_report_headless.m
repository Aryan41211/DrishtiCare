% run_verify_report_headless.m
% Drives the REAL verify_drishti_report against the REAL generator headless
% and writes MATLAB's OWN verdict + artifact facts to a log FILE on disk.
% The log is then read natively off disk — the ONLY truthful channel this
% session. No reliance on the mutable MATLAB stdout pipe.
projectRoot = 'C:\projects\DrishtiCare';
logPath = fullfile(projectRoot, 'results', '_verify_report_log.txt');
try
    addpath(projectRoot);
    addpath(genpath(fullfile(projectRoot, 'src')));
    [pdfPath, engine] = verify_drishti_report(projectRoot);
    fid = fopen(logPath, 'w');
    fprintf(fid, 'VERDICT=PASS\n');
    fprintf(fid, 'PDF=%s\n', pdfPath);
    fprintf(fid, 'ENGINE=%s\n', engine);
    if exist(pdfPath, 'file') == 2
        d = dir(pdfPath);
        fprintf(fid, 'BYTES=%d\n', d.bytes);
        f = fopen(pdfPath, 'rb');
        hdr = fread(f, 4, '*char')';
        fclose(f);
        fprintf(fid, 'HEADER=%s\n', hdr);
    end
    fclose(fid);
catch err
    fid = fopen(logPath, 'w');
    fprintf(fid, 'VERDICT=FAIL\n');
    fprintf(fid, 'ERR=%s\n', err.message);
    if ~isempty(err.stack)
        fprintf(fid, 'AT=%s:%d\n', err.stack(1).name, err.stack(1).line);
    end
    fclose(fid);
end
