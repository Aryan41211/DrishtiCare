%% INTEGRATION TEST: lesion evidence in single-image inference report
%  Runs predictSingleFundus (with lesion branch) on 6 APTOS TRAIN images —
%  a mix of non-referable (0/1) and referable (2/3/4) grades — and verifies
%  the added fields + overlay figure. TRAIN images only; the official test
%  set is CLOSED and never touched.

projRoot = 'C:\projects\DrishtiCare';
cd(projRoot);
addpath('src','src/inference','src/lesions','src/quality', ...
        'src/enhancement','src/grading','src/setup','src/explainability', ...
        'src/ood_detection','src/cascade_router');
outDir = fullfile(projRoot, 'data', 'analysis', 'day8', 'lesion_report');
if ~exist(outDir,'dir'), mkdir(outDir); end

% Select 6 train images: 2 non-referable (grade 0,1) + 4 referable (2,3,4)
trainCsv = fullfile(projRoot, 'data', 'aptos2019', 'train.csv');
fid = fopen(trainCsv,'r'); header = fgetl(fid);
picks = struct('name', {}, 'grade', {});
while ~feof(fid)
    line = fgetl(fid);
    if isempty(line), continue; end
    parts = strsplit(line, ',');
    if numel(parts) < 2, continue; end
    idc = parts{1}; gr = str2double(parts{2});
    if ismember(gr, [0 1 2 3 4])
        picks(end+1).name = idc; %#ok<AGROW>
        picks(end).grade = gr;   %#ok<AGROW>
    end
end
fclose(fid);

sel = [];
for grp = [0 1 2 3 4]
    idx = find([picks.grade] == grp, 1);
    if ~isempty(idx), sel(end+1) = idx; end %#ok<AGROW>  % one per grade
end
if numel(sel) > 6, sel = sel(1:6); end

fprintf('Testing %d images (train):\n', numel(sel));
fprintf('%-15s %s\n', 'id', 'label(grade)');
res = struct();
for k = 1:numel(sel)
    idc = picks(sel(k)).name;
    imgPath = fullfile(projRoot, 'data', 'aptos2019', 'train_images', [idc '.png']);
    if ~exist(imgPath, 'file')
        fprintf('SKIP %s (missing)\n', idc); continue;
    end
    fprintf('%d/%d %s (grade %d)\n', k, numel(sel), idc, picks(sel(k)).grade);
    r = predictSingleFundus(imgPath, 'ShowFigure', false, 'RunLesions', true);
    fprintf('  screen=%s pRef=%.3f grade=%d(%s) conf=%.3f\n', ...
        r.binaryDecision, r.binaryProbability, r.grade, r.gradeLabel, r.confidence);
    if isfield(r, 'lesions')
        fprintf('  MA=%d HE=%d EX=%d quadHE=[%s] odLocated=%d\n', ...
            r.lesions.maCount, r.lesions.heCount, r.lesions.exCount, ...
            num2str(r.lesions.quadrantHemorrhage), r.lesions.odLocated);
        if r.lesions.odLocated
            fprintf('    OD=[%.0f %.0f] r=%.0f\n', r.lesions.od(1), r.lesions.od(2), r.lesions.od(3));
        end
    else
        fprintf('  NO lesions field (RunLesions off or error)\n');
    end
    % save annotated figure (ShowFigure false -> build our own still via figure)
    f = figure('Visible','off','Position',[50 50 1200 400]);
    subplot(1,3,1); imshow(imgPath); title(sprintf('%s (grade %d)', idc, picks(sel(k)).grade));
    subplot(1,3,2); imagesc(r.gradCAM); axis image off; title('Grad-CAM');
    subplot(1,3,3);
    if isfield(r,'lesions') && isfield(r.lesions,'overlay') && ~isempty(r.lesions.overlay)
        held = r.lesions.overlay.overlay;
        imagesc(held); axis image off; hold on;
        [ey,exx] = find(r.lesions.overlay.exMask); plot(exx,ey,'y.','MarkerSize',2);
        [my,mx] = find(r.lesions.overlay.maMask);  plot(mx,my,'r.','MarkerSize',4);
        [hy,hx] = find(r.lesions.overlay.heMask);  plot(hx,hy,'c.','MarkerSize',4);
        if r.lesions.odLocated
            [hh, ww] = size(held);
            imgInfo = imfinfo(imgPath);
            scl = ww / imgInfo.Width;
            viscircles(r.lesions.od(1:2)*scl, r.lesions.od(3)*scl, 'Color','g','LineWidth',1);
        end
        title(sprintf('MA=%d HE=%d EX=%d', r.lesions.maCount, r.lesions.heCount, r.lesions.exCount));
    else
        title('lesions unavailable'); axis off;
    end
    saveas(f, fullfile(outDir, sprintf('report_%s_grade%d.png', idc, picks(sel(k)).grade)));
    close(f);
    res.(sprintf('img_%d', k)) = r;
end
save(fullfile(outDir, 'lesion_report_test.mat'), 'res', 'picks', 'sel');
fprintf('\nFigures + results saved to %s\n', outDir);