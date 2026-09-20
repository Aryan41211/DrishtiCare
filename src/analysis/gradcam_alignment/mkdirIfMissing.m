function mkdirIfMissing(dirPath)
%MKDIRIFMISSING Create directory if it doesn't exist
    if ~exist(dirPath, 'dir')
        mkdir(dirPath);
    end
end