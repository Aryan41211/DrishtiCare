function run_day7(mode)
% RUN_DAY7 Grad-CAM explainability for DR champions (validation only)
%   run_day7('verify') - single-image smoke test
%   run_day7('full')   - curated correct + error cases, both champions
%
%   Saves overlays + manifest under data/analysis/day7/

    if nargin < 1, mode = 'verify'; end

    project_root = pwd;
    addpath(fullfile(project_root, 'src', 'setup'));
    addpath(fullfile(project_root, 'src', 'quality'));
    addpath(fullfile(project_root, 'src', 'enhancement'));
    addpath(fullfile(project_root, 'src', 'grading'));

    fprintf('============================================\n');
    fprintf('   DrishtiCare - Day 7 Explainability        \n');
    fprintf('============================================\n');
    fprintf('Mode: %s  Date: %s\n\n', upper(mode), datestr(now));

    config = defaultTrainingConfig();
    outDir = fullfile(project_root, 'data', 'analysis', 'day7');
    if ~exist(outDir, 'dir'), mkdir(outDir); end

    % Load champions (read-only)
    S5 = load(fullfile(config.dataset.modelDir, 'day5_resnet18_baseline_stage2.mat'), 'trainedNet');
    SB = load(fullfile(config.dataset.modelDir, 'day6_binary_referable_v1_stage2.mat'), 'trainedNet');
    net5 = S5.trainedNet;
    netB = SB.trainedNet;
    fprintf('[PASS] Both champions loaded\n');

    valDir = fullfile(config.dataset.splitDir, 'val');
    valDSraw = imageDatastore(valDir, 'IncludeSubfolders', true, ...
        'LabelSource', 'foldernames');
    valDSraw.Files = sort(valDSraw.Files);

    if strcmp(mode, 'verify')
        img = imread(valDSraw.Files{1});
        [overlay, heatmap, scores] = gradcamExplain(net5, img);
        assert(~any(isnan(heatmap(:))), 'NaN in heatmap');
        fprintf('[PASS] Grad-CAM smoke test: overlay %s, max score %.3f\n', ...
            mat2str(size(overlay)), max(scores));
        imwrite(overlay, fullfile(outDir, 'verify_smoke.png'));
        fprintf('Saved verify_smoke.png\n');
        return;
    end

    if strcmp(mode, 'full')
        fileCount = length(valDSraw.Files);
        YTrue5 = zeros(fileCount,1); YPred5 = zeros(fileCount,1);
        YTrueB = false(fileCount,1); PRefB = zeros(fileCount,1);
        fprintf('Scanning %d validation images...\n', fileCount);
        for i = 1:fileCount
            img = imresize(imread(valDSraw.Files{i}), [224 224]);
            [~, folderName] = fileparts(fileparts(valDSraw.Files{i}));
            t = regexp(folderName, 'class_(\d+)', 'tokens');
            YTrue5(i) = str2double(t{1}{1}) + 1;
            s5 = predict(net5, img); s5 = s5(:)';
            [~, YPred5(i)] = max(s5);
            sB = predict(netB, img); sB = sB(:)';
            PRefB(i) = sB(2);  % referable is 2nd (alphabetical) class
            YTrueB(i) = YTrue5(i) >= 3;  % Moderate/Severe/Proliferative
            if mod(i,200)==0, fprintf('  %d/%d\n', i, fileCount); end
        end

        % Curate 5-class cases: 1 correct + 1 error per class
        classNames = config.classes.names;
        cases = {};
        for c = 1:5
            ok = find(YTrue5 == c & YPred5 == c, 1);
            bad = find(YTrue5 == c & YPred5 ~= c, 1);
            if ~isempty(ok), cases{end+1} = struct('idx', ok, 'kind', 'correct'); end
            if ~isempty(bad), cases{end+1} = struct('idx', bad, 'kind', 'error'); end
        end
        % Binary: 2 referable FN + 2 FP
        YPredB = PRefB >= 0.60;  % chosen operating threshold
        fns = find(YTrueB & ~YPredB); fps = find(~YTrueB & YPredB);
        for k = 1:min(2,length(fns)), cases{end+1} = struct('idx', fns(k), 'kind', 'binary_FN'); end
        for k = 1:min(2,length(fps)), cases{end+1} = struct('idx', fps(k), 'kind', 'binary_FP'); end

        manifest = struct('file', {}, 'true5', {}, 'pred5', {}, ...
            'trueRef', {}, 'pRef', {}, 'kind', {});
        for k = 1:length(cases)
            i = cases{k}.idx;
            img = imread(valDSraw.Files{i});
            [~, f, e] = fileparts(valDSraw.Files{i});
            [overlay5, ~, s5] = gradcamExplain(net5, img, 'TargetClass', YPred5(i));
            [overlayB, ~, sB] = gradcamExplain(netB, img);
            imwrite(overlay5, fullfile(outDir, sprintf('case%02d_5class_%s.png', k, cases{k}.kind)));
            imwrite(overlayB, fullfile(outDir, sprintf('case%02d_binary_%s.png', k, cases{k}.kind)));
            manifest(k).file = [f e];
            manifest(k).true5 = classNames{YTrue5(i)};
            manifest(k).pred5 = classNames{YPred5(i)};
            manifest(k).trueRef = YTrueB(i);
            manifest(k).pRef = PRefB(i);
            manifest(k).kind = cases{k}.kind;
            fprintf('Case %d/%d: %s true=%s pred=%s pRef=%.3f [%s]\n', ...
                k, length(cases), manifest(k).file, manifest(k).true5, ...
                manifest(k).pred5, manifest(k).pRef, manifest(k).kind);
        end
        save(fullfile(outDir, 'day7_manifest.mat'), 'manifest');
        fprintf('\nSaved %d cases + manifest to %s\n', length(cases), outDir);
        return;
    end

    error('Unknown mode: %s (use verify/full)', mode);
end