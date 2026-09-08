function buildTask9bEnhancedSplits()
% BUILDTASK9BENHANCEDSPLITS Precompute enhanced image splits for Task 9B
%   buildTask9bEnhancedSplits()
%
%   Creates data/splits_enhanced/{train,val}/class_0..class_4 as enhanced
%   copies of data/splits/{train,val}. Skips files that already exist.
%   No local functions. ASCII only.

    fprintf('=== Task 9B: Building Enhanced Splits ===\n');
    fprintf('Date: %s\n', datestr(now));

    projectRoot = pwd;
    srcDir = fullfile(projectRoot, 'src');
    addpath(genpath(srcDir));

    srcBase = fullfile(projectRoot, 'data', 'splits');
    dstBase = fullfile(projectRoot, 'data', 'splits_enhanced');
    analysisDir = fullfile(projectRoot, 'data', 'analysis', 'day9');

    if ~exist(analysisDir, 'dir')
        mkdir(analysisDir);
    end

    splits = {'train', 'val'};
    trainCount = 0;
    valCount = 0;
    tic;

    for si = 1:length(splits)
        splitName = splits{si};
        srcSplit = fullfile(srcBase, splitName);
        dstSplit = fullfile(dstBase, splitName);

        if ~exist(srcSplit, 'dir')
            error('Source split not found: %s', srcSplit);
        end

        for c = 0:4
            srcClassDir = fullfile(srcSplit, sprintf('class_%d', c));
            dstClassDir = fullfile(dstSplit, sprintf('class_%d', c));

            if ~exist(dstClassDir, 'dir')
                mkdir(dstClassDir);
            end

            files = dir(fullfile(srcClassDir, '*.png'));
            fprintf('\nProcessing %s/class_%d: %d files\n', splitName, c, length(files));

            for fi = 1:length(files)
                srcFile = fullfile(srcClassDir, files(fi).name);
                dstFile = fullfile(dstClassDir, files(fi).name);

                if exist(dstFile, 'file')
                    continue;
                end

                img = imread(srcFile);
                enhanced = enhanceImage(img);

                if size(enhanced, 3) == 1
                    enhanced = repmat(enhanced, 1, 1, 3);
                end

                if ~isa(enhanced, 'uint8')
                    enhanced = uint8(enhanced);
                end

                imwrite(enhanced, dstFile);

                if strcmp(splitName, 'train')
                    trainCount = trainCount + 1;
                else
                    valCount = valCount + 1;
                end

                if mod(fi, 100) == 0
                    fprintf('  %s/class_%d: %d/%d\n', splitName, c, fi, length(files));
                end
            end
        end
    end

    wallTime = toc;

    fprintf('\n=== Enhanced Splits Complete ===\n');
    fprintf('Train: %d, Val: %d\n', trainCount, valCount);
    fprintf('Total wall time: %.1f seconds (%.1f minutes)\n', wallTime, wallTime/60);

    info = struct();
    info.trainCount = trainCount;
    info.valCount = valCount;
    info.wallTimeSeconds = wallTime;
    info.date = datestr(now);
    save(fullfile(analysisDir, 'task9b_enhanced_splits_info.mat'), 'info');
    fprintf('Saved %s\n', fullfile(analysisDir, 'task9b_enhanced_splits_info.mat'));
end
