C:\projects\DrishtiCare\results\_run_verify_report.m
% _run_verify_report.m - headless runner that drives the REAL generator and
% writes MATLAB's OWN verdict + artifact facts to results\_cc_verdict.txt.
% We then native-read that file off disk (ground truth), NOT the stdout pipe.

logPath = fullfile(projectRoot, 'results', '_cc_verdict.txt');
function main(logPath)
try
    fid = fopen(logPath, 'w');
    addpath(projectRoot);
    addpath(genpath(fullfile(projectRoot, 'src')));
    [pdfPath, engine] = verify_drishti_report(projectRoot);
    fprintf(fid, 'VERDICT=PASS\n');
    fprintf(fid, 'ARTIFACT=%s\n', pdfPath);
    fprintf(fid, 'ENGINE=%s\n', engine);
    if exist(pdfPath, 'file') == 2
        d = dir(pdfPath);
        fprintf(fid, 'BYTES=%d\n', d.bytes);
        f = fopen(pdfPath, 'rb');
        hdr = fread(f, 4, '*char')';
        fclose(f);
        fprintf(fid, 'HEADER=%s\n', hdr);
    end
catch err
    fprintf(fid, 'VERDICT=FAIL\n');
    fprintf(fid, 'ERR=%s\n', err.message);
    if ~isempty(err.stack)
        fprintf(fid, 'AT=%s:%d\n', err.stack(1).name, err.stack(1).line);
    end
end
if fid > 0, fclose(fid); end
end
