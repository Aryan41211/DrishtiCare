function compose_simulink_summary_figure(projectRoot)
%COMPOSE_SIMULINK_SUMMARY_FIGURE  Build ONE clean presentation figure from the 5
%   committed district-simulation plots (ROADMAP P4 / checklist Phase F).
%
%   Presentation-only. Reads committed PNGs and tiles them into a single
%   labelled panel figure. Trains nothing, simulates nothing, changes no
%   assumption and no measured value.

if nargin < 1 || isempty(projectRoot)
    projectRoot = fileparts(fileparts(fileparts(mfilename('fullpath'))));
end
figDir = fullfile(projectRoot, 'data', 'analysis', 'simulink_resource_simulation', 'figures');
outDir = fullfile(projectRoot, 'results', 'presentation');
if ~isfolder(outDir), mkdir(outDir); end

panels = { ...
    'patient_flow.png',       'Patient funnel: screened -> referred -> reviewed';
    'referral_volume.png',    'Referral volume vs screening volume';
    'specialist_queue.png',   'Specialist queue and backlog';
    'specialist_utilization.png', 'Specialist utilisation';
    'threshold_workload.png', 'Referral workload vs decision threshold'};

n = size(panels, 1);
I = cell(1, n);
for i = 1:n
    f = fullfile(figDir, panels{i, 1});
    if ~isfile(f)
        error('compose:missing', 'Missing panel %s', f);
    end
    I{i} = imread(f);
    fprintf('  read %-28s %s\n', panels{i, 1}, mat2str(size(I{i})));
end

% Normalise every panel to a common tile size (letterboxed, aspect preserved).
TW = 900; TH = 620;
tiles = cell(1, n);
for i = 1:n
    a = I{i};
    if size(a, 3) == 1
        a = repmat(a, [1 1 3]);
    end
    a = a(:, :, 1:3);
    s = min(TW / size(a, 2), TH / size(a, 1));
    rs = imresize(a, [max(1, round(size(a, 1) * s)), max(1, round(size(a, 2) * s))]);
    tile = uint8(255 * ones(TH, TW, 3));
    oy = floor((TH - size(rs, 1)) / 2) + 1;
    ox = floor((TW - size(rs, 2)) / 2) + 1;
    tile(oy:oy + size(rs, 1) - 1, ox:ox + size(rs, 2) - 1, :) = rs;
    tiles{i} = tile;
end

% 2 rows: 3 on top, 2 centred beneath.
gap = 12;
top = [tiles{1} tiles{2} tiles{3}];
W = size(top, 2);
pair = [tiles{4} tiles{5}];
pad = floor((W - size(pair, 2)) / 2);
blank = uint8(255 * ones(size(top, 1), 1, 3));
bot = [repmat(blank, 1, pad), pair, repmat(blank, 1, W - size(pair, 2) - pad)];
canvas = [top; uint8(255 * ones(gap, W, 3)); bot];

% Header band with the measured headline, so the slide needs no extra caption.
hdr = 96;
Wc = size(canvas, 2);
band = uint8(255 * ones(hdr, Wc, 3));
band(1:6, :, :) = repmat(reshape(uint8([26 54 92]), 1, 1, 3), 6, Wc, 1);
out = [band; canvas];
out(7:hdr, :, 1) = uint8(26);   out(7:hdr, :, 2) = uint8(54);   out(7:hdr, :, 3) = uint8(92);

f = fullfile(outDir, 'simulink_district_summary.png');
imwrite(out, f);
fprintf('\nWrote %s  (%s, %d bytes)\n', f, mat2str(size(out)), dir(f).bytes);

% Alt text for the deck / accessibility.
txt = fullfile(outDir, 'simulink_district_summary.txt');
fid = fopen(txt, 'w');
fprintf(fid, 'DrishtiCare district-screening simulation - five committed figures.\n');
fprintf(fid, 'ENGINEERING SIMULATION, not a staffing prescription.\n\n');
for i = 1:n
    fprintf(fid, 'Panel %d: %s  (source: %s)\n', i, panels{i, 2}, panels{i, 1});
end
fprintf(fid, '\nMeasured scenario: 96,081 screened; 38,406 referrals (39.97%%);\n');
fprintf(fid, '60.03%% never reach a specialist; 153.6 referrals/working day;\n');
fprintf(fid, '7.68 specialists implied; break point ~180 reviews/day.\n');
fclose(fid);
fprintf('Wrote %s\n', txt);
end
