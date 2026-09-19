function run_report_verify_headless(projectRoot)
% run_report_verify_headless.m
% Drives the REAL verify_drishti_report, writes VERDICT + PDF facts to
% results\_verify_report_verdict.txt on disk. Read that file natively to
% learn the truth (the bash->MATLAB stdout pipe is untrustworthy all session).
vd = fullfile(projectRoot, 'results', '_verify_report_verdict.txt');
fid = fopen(vd, 'w');
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
        pf = fopen(pdfPath, 'rb');
        hdr = fread(pf, 4, '*char')';
        fclose(pf);
        fprintf(fid, 'HEADER=%s\n', hdr);
    else
        fprintf(fid, 'HEADER=NOFILE\n');
    end
catch err
    fprintf(fid, 'VERDICT=FAIL\n');
    fprintf(fid, 'MSG=%s\n', err.message);
    if ~isempty(err.stack)
        fprintf(fid, 'AT=%s:%d\n', err.stack(1).name, err.stack(1).line);
    end
    fprintf(fid, 'RESET=stack\n');
end
fclose(fid);
end
