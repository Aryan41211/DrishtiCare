function [trainDS, valDS, binInfo] = prepareBinaryData(varargin)
% PREPAREBINARYDATA Build binary referable/non-referable datastores
%   Derives binary labels from the EXISTING 5-class split in data/splits/.
%   Same train/val IDs. Original 5-class folders are never modified.
%
%   Mapping: class_0, class_1 -> nonreferable (0)
%            class_2, class_3, class_4 -> referable (1)
%
%   Output folders: data/splits_binary/{train,val}/{nonreferable,referable}

    p = inputParser;
    addParameter(p, 'Config', [], @(x) isstruct(x));
    parse(p, varargin{:});
    config = p.Results.Config;
    if isempty(config)
        config = defaultTrainingConfig();
    end

    splitDir = config.dataset.splitDir;
    binDir = fullfile(config.dataset.projectRoot, 'data', 'splits_binary');
    assert(exist(fullfile(splitDir, 'train'), 'dir') == 7, ...
        'Run prepareData first: data/splits/train missing');

    nonRef = {'class_0', 'class_1'};
    ref = {'class_2', 'class_3', 'class_4'};

    if exist(binDir, 'dir')
        rmdir(binDir, 's');
    end
    mkdir(fullfile(binDir, 'train', 'nonreferable'));
    mkdir(fullfile(binDir, 'train', 'referable'));
    mkdir(fullfile(binDir, 'val', 'nonreferable'));
    mkdir(fullfile(binDir, 'val', 'referable'));

    counts = struct('trainNonRef', 0, 'trainRef', 0, 'valNonRef', 0, 'valRef', 0);
    splitNames = {'train', 'val'};
    for s = 1:2
        splitName = splitNames{s};
        for c = 0:4
            srcDir = fullfile(splitDir, splitName, sprintf('class_%d', c));
            if c <= 1
                dstDir = fullfile(binDir, splitName, 'nonreferable');
            else
                dstDir = fullfile(binDir, splitName, 'referable');
            end
            files = dir(fullfile(srcDir, '*.png'));
            for f = 1:length(files)
                copyfile(fullfile(srcDir, files(f).name), ...
                    fullfile(dstDir, files(f).name));
            end
            n = length(files);
            if strcmp(splitName, 'train')
                if c <= 1, counts.trainNonRef = counts.trainNonRef + n;
                else, counts.trainRef = counts.trainRef + n; end
            else
                if c <= 1, counts.valNonRef = counts.valNonRef + n;
                else, counts.valRef = counts.valRef + n; end
            end
        end
    end

    fprintf('Binary split (same IDs as 5-class split):\n');
    fprintf('  Train: nonreferable=%d referable=%d\n', counts.trainNonRef, counts.trainRef);
    fprintf('  Val:   nonreferable=%d referable=%d\n', counts.valNonRef, counts.valRef);

    % Data-leakage checks
    trainFiles = getFileNames(fullfile(binDir, 'train'));
    valFiles = getFileNames(fullfile(binDir, 'val'));
    assert(isempty(intersect(trainFiles, valFiles)), 'Leakage: train/val overlap');
    testDir = config.dataset.testImages;
    if exist(testDir, 'dir')
        testFiles = getFileNames(testDir);
        assert(isempty(intersect(trainFiles, testFiles)), 'Leakage: test in train');
        assert(isempty(intersect(valFiles, testFiles)), 'Leakage: test in val');
    end
    fprintf('[PASS] No leakage: train/val disjoint, test set excluded\n');

    trainDS = augmentedImageDatastore(config.input.imageSize, ...
        imageDatastore(fullfile(binDir, 'train'), ...
            'IncludeSubfolders', true, 'LabelSource', 'foldernames'));
    valDS = augmentedImageDatastore(config.input.imageSize, ...
        imageDatastore(fullfile(binDir, 'val'), ...
            'IncludeSubfolders', true, 'LabelSource', 'foldernames'));

    binInfo = struct('date', datestr(now), 'counts', counts, 'binDir', binDir);
end

function names = getFileNames(d)
    files = dir(fullfile(d, '**', '*.png'));
    names = {files.name}';
end