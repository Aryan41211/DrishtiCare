% _run_verify_report.m - SIMPLE PURE SCRIPT (valid MATLAB, no function defs).
% Runs the REAL verify_drishti_report and writes MATLAB's OWN verdict to
% results\_verify_verdict.txt which the native reader reads off disk. This
% bypasses the corrupt bash->MATLAB stdout pipe entirely.
projectRoot = 'C:\projects\DrishtiCare';
verdictFile = fullfile(projectRoot, 'results', '_verify_verdict.txt');
vid = fopen(verdictFile, 'w');
if vid < 0
    error('Cannot open verdict file for writing');
end
try
    addpath(projectRoot);
    addpath(genpath(fullfile(projectRoot, 'src')));
    if ~exist(fullfile(projectRoot, 'results'), 'dir')
        mkdir(fullfile(projectRoot, 'results'));
    end
    [pdfPath, engine] = verify_drishti_report(projectRoot);
    fprintf(vid, 'VERDICT=PASS\n');
    fprintf(vid, 'PDFPATH=%s\n', pdfPath);
    fprintf(vid, 'ENGINE=%s\n', engine);
    if exist(pdfPath, 'file') == 2
        d = dir(pdfPath);
        fprintf(vid, 'BYTES=%d\n', d.bytes);
        fh = fopen(pdfPath, 'rb');
        if fh > 0
            hdr = fread(fh, 4, '*char')';
            fclose(fh);
            fprintf(vid, 'HEADER=%s\n', hdr);
        end
    else
        fprintf(vid, 'HEADER=NOFILE\n');
    end
catch err
    fprintf(vid, 'VERDICT=FAIL\n');
    fprintf(vid, 'ERR=%s\n', err.message);
    if ~isempty(err.stack)
        fprintf(vid, 'AT=%s:%d\n', err.stack(1).name, err.stack(1).line);
    end
end
fclose(vid);
