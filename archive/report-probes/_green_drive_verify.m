% _green_drive_verify.m  (plain script -- NO function blocks, NO captured
% outputs from verify -- verify_drishti_report(projectRoot) has NO outputs
% per its on-disk signature at L14; capturing outputs was MY bug).
% Drives the REAL verify_drishti_report, then scans results\ for the freshest
% PDF artifact and writes MATLAB's OWN verdict to results\_green_verdict.txt.
projectRoot = 'C:\projects\DrishtiCare';
outDir = fullfile(projectRoot, 'results');
vfile = fullfile(outDir, '_green_verdict.txt');
fid = fopen(vfile, 'w');
if fid < 0, error('cannot open green verdict file'); end
try
    addpath(projectRoot);
    addpath(genpath(fullfile(projectRoot, 'src')));

    % 1. run the REAL verifier (it internally asserts the real generator)
    verify_drishti_report(projectRoot);
    fprintf(fid, 'VERIFY=RAN-OK\n');

    % 2. locate the freshest PDF artifact the verifier wrote
    pat = fullfile(outDir, 'DrishtiScreeningReport_*.pdf');
    pdirs = dir(pat);
    if isempty(pdirs)
        fprintf(fid, 'ARTIFACT=NOFILE\n');
    else
        [~, ix] = max([pdirs.datenum]);
        pdfPath = fullfile(outDir, pdirs(ix).name);
        fprintf(fid, 'ARTIFACT=%s\n', pdfPath);
        fprintf(fid, 'BYTES=%d\n', pdirs(ix).bytes);
        fh = fopen(pdfPath, 'rb');
        hdr = fread(fh, 4, '*char')';
        fclose(fh);
        fprintf(fid, 'HEADER=%s\n', hdr);
        if strcmp(hdr, '%PDF') && pdirs(ix).bytes > 3000
            fprintf(fid, 'VERDICT=PASS\n');
        else
            fprintf(fid, 'VERDICT=FAIL\n');
        end
    end
catch err
    fprintf(fid, 'VERDICT=FAIL\n');
    fprintf(fid, 'ERR=%s\n', err.message);
    if ~isempty(err.stack)
        fprintf(fid, 'AT=%s:%d\n', err.stack(1).name, err.stack(1).line);
    end
end
fclose(fid);
