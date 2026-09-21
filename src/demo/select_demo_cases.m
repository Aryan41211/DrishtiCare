function cases = select_demo_cases(varargin)
% SELECT_DEMO_CASES Pick a small, REAL demo case set from the held-out split
%   cases = select_demo_cases()
%   cases = select_demo_cases('Rescan', true)
%
%   Scans the project's held-out validation split
%   (data/splits/val/class_*/*.png) with the existing Day-3 quality module
%   (assessImageQuality) and selects a deterministic, representative set of
%   REAL images - no synthetic degradation is created.
%
%   Selected roles:
%       pass_referable  - quality PASS, true grade folder class_2..class_4
%       pass_nodr       - quality PASS, true grade folder class_0
%       warning         - quality WARNING (prefers an illumination warning)
%       fail_blur       - quality FAIL on focus (lowest focus score)
%       fail_dark       - quality FAIL on brightness (underexposed)
%       fail_bright     - quality FAIL on brightness (overexposed) if present
%       fail_fov        - quality FAIL on foreground (field of view)
%       fail_contrast   - quality FAIL on contrast, if present
%       fail_mask       - quality FAIL on mask validity, if present
%
%   A role is marked available=0 when no natural example exists in the split.
%
%   Outputs (data/analysis/failure_aware_demo/):
%       quality_scan.csv  - every scanned image + metrics + per-check status
%       demo_cases.csv    - the selected case set (input to the demo driver)
%
%   ENGINEERING demo selection only. No model is run here; no training.

    p = inputParser;
    addParameter(p, 'Rescan', false, @islogical);
    parse(p, varargin{:});

    projectRoot = fileparts(fileparts(fileparts(mfilename('fullpath'))));
    addpath(fullfile(projectRoot, 'src', 'quality'));
    cfg = defaultQualityConfig();
    valDir = fullfile(projectRoot, 'data', 'splits', 'val');
    outDir = fullfile(projectRoot, 'data', 'analysis', 'failure_aware_demo');
    if ~exist(outDir, 'dir'); mkdir(outDir); end

    scanFile = fullfile(outDir, 'quality_scan.csv');
    classDirs = {'class_0', 'class_1', 'class_2', 'class_3', 'class_4'};

    %% 1. Scan (or reuse cached scan)
    if exist(scanFile, 'file') && ~p.Results.Rescan
        T = readtable(scanFile, 'TextType', 'char');
        fprintf('Reusing cached quality scan: %s (%d images)\n', scanFile, height(T));
    else
        fprintf('Scanning held-out val split with the Day-3 quality module...\n');
        rows = {};
        for c = 1:numel(classDirs)
            files = dir(fullfile(valDir, classDirs{c}, '*.png'));
            names = sort({files.name});   % deterministic (OS-independent)
            for i = 1:numel(names)
                relPath = fullfile(classDirs{c}, names{i});
                img = imread(fullfile(valDir, relPath));
                [qres, m] = assessImageQuality(img);
                rows(end+1,:) = {relPath, classDirs{c}, names{i}, qres.overall, ...
                    m.brightness, m.contrast, m.focusScore, m.foregroundFrac, ...
                    m.illumination, double(m.maskValid), ...
                    statusOf(qres, 'focus'), statusOf(qres, 'brightness'), ...
                    statusOf(qres, 'contrast'), statusOf(qres, 'foreground'), ...
                    statusOf(qres, 'illumination'), statusOf(qres, 'maskValid'), ...
                    strjoin(qres.failureCategories, '|')}; %#ok<AGROW>
            end
        end
        T = cell2table(rows, 'VariableNames', {'relPath','classFolder','fileName', ...
            'overall','brightness','contrast','focusScore','foregroundFrac', ...
            'illumination','maskValid','focusStatus','brightnessStatus', ...
            'contrastStatus','foregroundStatus','illuminationStatus','maskValidStatus', ...
            'failureCategories'});
        writetable(T, scanFile);
        fprintf('Scanned %d images -> %s\n', height(T), scanFile);
    end

    %% 2. Select representative cases (deterministic, distinct where possible)
    sel = struct('id', {}, 'role', {}, 'available', {}, 'classFolder', {}, ...
                 'fileName', {}, 'relPath', {}, 'expectedQuality', {}, ...
                 'reasonCategory', {}, 'selectionRule', {});
    used = {};

    isP = @(s) strcmp(s, 'PASS');
    isW = @(s) strcmp(s, 'WARNING');
    isF = @(s) strcmp(s, 'FAIL');
    inRef = @(cf) ismember(cf, {'class_2','class_3','class_4'});

    addCase('case_pass_referable', 'pass_referable', ...
        isP(T.overall) & inRef(T.classFolder), ...
        T.focusScore, 'PASS quality, true grade class_2..4', 'PASS', '');
    addCase('case_pass_nodr', 'pass_nodr', ...
        isP(T.overall) & strcmp(T.classFolder, 'class_0'), ...
        T.focusScore, 'PASS quality, true grade class_0', 'PASS', '');
    addCase('case_warning', 'warning', ...
        isW(T.overall) & strcmp(T.illuminationStatus, 'WARNING'), ...
        T.illumination, 'WARNING overall, illumination check WARNING', 'WARNING', 'Uneven Illumination');
    if ~hasRole('warning')
        addCase('case_warning', 'warning', isW(T.overall), zeros(height(T),1), ...
            'WARNING overall (any cause)', 'WARNING', '');
    end
    addCase('case_fail_blur', 'fail_blur', ...
        isF(T.overall) & strcmp(T.focusStatus, 'FAIL'), ...
        T.focusScore, 'FAIL overall, focus check FAIL (lowest focus score)', 'FAIL', 'Blur');
    addCase('case_fail_dark', 'fail_dark', ...
        isF(T.overall) & strcmp(T.brightnessStatus, 'FAIL') & ...
        T.brightness < cfg.thresholds.brightness.lowerFail, ...
        T.brightness, 'FAIL overall, brightness below lowerFail (underexposed)', 'FAIL', 'Underexposure');
    addCase('case_fail_bright', 'fail_bright', ...
        isF(T.overall) & strcmp(T.brightnessStatus, 'FAIL') & ...
        T.brightness > cfg.thresholds.brightness.upperFail, ...
        -T.brightness, 'FAIL overall, brightness above upperFail (overexposed)', 'FAIL', 'Overexposure');
    addCase('case_fail_illumination', 'fail_illumination', ...
        isF(T.overall) & strcmp(T.illuminationStatus, 'FAIL'), ...
        -abs(T.illumination - 1.0), 'FAIL overall, illumination check FAIL (most extreme)', 'FAIL', 'Uneven Illumination');
    addCase('case_fail_fov', 'fail_fov', ...
        isF(T.overall) & strcmp(T.foregroundStatus, 'FAIL'), ...
        T.foregroundFrac, 'FAIL overall, foreground check FAIL (lowest foreground)', 'FAIL', 'Low Foreground');
    addCase('case_fail_contrast', 'fail_contrast', ...
        isF(T.overall) & strcmp(T.contrastStatus, 'FAIL'), ...
        T.contrast, 'FAIL overall, contrast check FAIL (lowest contrast)', 'FAIL', 'Low Contrast');
    addCase('case_fail_mask', 'fail_mask', ...
        isF(T.overall) & strcmp(T.maskValidStatus, 'FAIL'), ...
        zeros(height(T),1), 'FAIL overall, mask validity check FAIL', 'FAIL', 'Mask Failure');

    cases = struct2table(sel);
    writetable(cases, fullfile(outDir, 'demo_cases.csv'));
    fprintf('Selected %d demo cases (%d available) -> %s\n', ...
        height(cases), sum(cases.available), fullfile(outDir, 'demo_cases.csv'));

    fprintf('\n%-22s %-10s %-10s %s\n', 'id', 'available', 'expected', 'relPath');
    for i = 1:height(cases)
        fprintf('%-22s %-10d %-10s %s\n', cases.id{i}, cases.available(i), ...
            cases.expectedQuality{i}, cases.relPath{i});
    end

    %% ---- nested helpers (share parent workspace) ----
    function addCase(id, role, mask, sortKey, rule, expected, reason)
        entry = struct('id', id, 'role', role, 'available', false, ...
            'classFolder', '', 'fileName', '', 'relPath', '', ...
            'expectedQuality', expected, 'reasonCategory', reason, ...
            'selectionRule', rule);
        idx = find(mask);
        if ~isempty(idx)
            keys = sortKey(idx);
            keys(~isfinite(keys)) = realmax;   % deterministic fallback
            [~, order] = sort(keys, 'ascend');
            pick = idx(order(1));
            for k = order(:)'
                if ~any(strcmp(used, T.relPath{idx(k)}))
                    pick = idx(k); break;
                end
            end
            used{end+1} = T.relPath{pick}; %#ok<AGROW>
            entry.available = true;
            entry.classFolder = T.classFolder{pick};
            entry.fileName = T.fileName{pick};
            entry.relPath = T.relPath{pick};
        end
        sel(end+1) = entry; %#ok<AGROW>
    end

    function tf = hasRole(role)
        tf = false;
        for ii = 1:numel(sel)
            if strcmp(sel(ii).role, role) && sel(ii).available
                tf = true; return;
            end
        end
    end
end

% ------------------------------------------------------------------------
function s = statusOf(qres, metric)
    s = '';
    for k = 1:numel(qres.checks)
        if strcmp(qres.checks(k).metric, metric)
            s = qres.checks(k).status; return;
        end
    end
end
