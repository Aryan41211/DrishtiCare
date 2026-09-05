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

    if strcmp(mode, 'contrast')
        % For each 5-class error case: heatmap for TRUE class vs PREDICTED
        % class + their correlation (same region or different evidence?).
        M = load(fullfile(outDir, 'day7_manifest.mat'), 'manifest');
        manifest = M.manifest;
        classNames = config.classes.names;
        fprintf('%-24s %-14s %-14s %-8s\n', 'file', 'true', 'pred', 'corr');
        contrast = struct('file', {}, 'trueClass', {}, 'predClass', {}, 'corr', {});
        n = 0;
        for k = 1:length(manifest)
            if ~strcmp(manifest(k).kind, 'error'), continue; end
            n = n + 1;
            img = imresize(imread(fullfile( ...
                config.dataset.dataRoot, 'train_images', manifest(k).file)), [224 224]);
            ti = find(strcmp(classNames, manifest(k).true5));
            pi = find(strcmp(classNames, manifest(k).pred5));
            hmT = mat2gray(gradCAM(net5, img, ti, 'FeatureLayer', 'res5b_relu'));
            hmP = mat2gray(gradCAM(net5, img, pi, 'FeatureLayer', 'res5b_relu'));
            c = corr(hmT(:), hmP(:));
            [~, f, e] = fileparts(manifest(k).file);
            imwrite(imfuse(repmat(imresize(hmT, [224 224]), 1, 1, 3), ...
                im2double(img), 'blend', 'Scaling', 'joint'), ...
                fullfile(outDir, sprintf('contrast%02d_true_%s.png', n, manifest(k).true5)));
            fprintf('%-24s %-14s %-14s %-8.3f\n', manifest(k).file, ...
                manifest(k).true5, manifest(k).pred5, c);
            contrast(n).file = [f e];
            contrast(n).trueClass = manifest(k).true5;
            contrast(n).predClass = manifest(k).pred5;
            contrast(n).corr = c;
        end
        save(fullfile(outDir, 'day7_contrast.mat'), 'contrast');
        fprintf('Saved %d contrast pairs.\n', n);
        return;
    end

    if strcmp(mode, 'avgmaps')
        % Class-average attention: 20 correctly classified images per grade.
        fileCount = length(valDSraw.Files);
        YTrue5 = zeros(fileCount,1); YPred5 = zeros(fileCount,1);
        fprintf('Scanning %d images for correct-per-class pools...\n', fileCount);
        for i = 1:fileCount
            img = imresize(imread(valDSraw.Files{i}), [224 224]);
            [~, folderName] = fileparts(fileparts(valDSraw.Files{i}));
            t = regexp(folderName, 'class_(\d+)', 'tokens');
            YTrue5(i) = str2double(t{1}{1}) + 1;
            s = predict(net5, img); [~, YPred5(i)] = max(s(:)');
            if mod(i,200)==0, fprintf('  %d/%d\n', i, fileCount); end
        end
        classNames = config.classes.names;
        avgResult = struct('class', {}, 'n', {}, 'meanMassInside', {}, 'meanCorrToMean', {});
        for c = 1:5
            pool = find(YTrue5 == c & YPred5 == c);
            pool = pool(1:min(20, length(pool)));
            first = mat2gray(gradCAM(net5, ...
                imresize(imread(valDSraw.Files{pool(1)}), [224 224]), c, ...
                'FeatureLayer', 'res5b_relu'));
            acc = zeros(size(first));
            maps = zeros([size(first), length(pool)]);
            inside = zeros(length(pool), 1);
            for j = 1:length(pool)
                img = imresize(imread(valDSraw.Files{pool(j)}), [224 224]);
                hm = mat2gray(gradCAM(net5, img, c, 'FeatureLayer', 'res5b_relu'));
                maps(:, :, j) = hm;
                acc = acc + hm;
                mask = imresize(createRetinalMask(img), size(hm)) > 0.5;
                inside(j) = sum(hm(mask)) / (sum(hm(:)) + eps);
            end
            avgMap = acc / length(pool);
            imwrite(mat2gray(avgMap), fullfile(outDir, ...
                sprintf('avgmap_class%d_%s.png', c-1, classNames{c})));
            % Mean correlation of individual maps to the average
            v = avgMap(:);
            cc = zeros(length(pool), 1);
            for j = 1:length(pool)
                mj = maps(:, :, j);
                cc(j) = corr(mj(:), v);
            end
            avgResult(c).class = classNames{c};
            avgResult(c).n = length(pool);
            avgResult(c).meanMassInside = mean(inside);
            avgResult(c).meanCorrToMean = mean(cc);
            fprintf('%-14s n=%2d massInside=%.3f selfCorr=%.3f\n', ...
                classNames{c}, length(pool), mean(inside), mean(cc));
        end
        save(fullfile(outDir, 'day7_avgmaps.mat'), 'avgResult');
        fprintf('Saved class-average maps.\n');
        return;
    end

    error('Unknown mode: %s (use verify/full/contrast/avgmaps)', mode);
end