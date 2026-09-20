function [audit, pairs] = audit_idrid_lesion_dataset(projRoot, outDir)
%AUDIT_IDRID_LESION_DATASET Phase-2 audit of the Grad-CAM evaluation dataset
%   [audit, pairs] = audit_idrid_lesion_dataset(projRoot, outDir)
%
%   Enumerates every candidate IDRiD segmentation image on disk and checks,
%   per image:
%     - image exists and is readable
%     - required lesion mask exists (MA / HE / EX / SE)
%     - mask can be read
%     - image dimensions vs mask dimensions (must match at full resolution)
%     - mask contains valid (nonzero) pixels
%     - which lesion types exist for the image
%
%   NOTHING is silently skipped: every candidate gets a status and, when it
%   is not usable, a documented reason. Results are written to
%     <outDir>/dataset_audit.csv, dataset_audit.mat, dataset_audit.md
%
%   Outputs:
%     audit - summary struct: totals, skip-reason counts, per-type coverage
%     pairs - struct array, one record per candidate image with fields
%             id, split, imagePath, status ('valid'|'skip'), skipReason,
%             imgW, imgH, lesionTypes, nLesionTypes, hasAnyLesionPx,
%             maskPaths, maskExists, maskReadable, maskDimsMatch, maskPxFull
%
%   READ-ONLY analysis: no dataset/model/pipeline files are modified.

    segRoot  = fullfile(projRoot, 'data', 'idrid', 'A. Segmentation');
    origDirs = struct( ...
        'train', fullfile(segRoot, '1. Original Images', 'a. Training Set'), ...
        'test',  fullfile(segRoot, '1. Original Images', 'b. Testing Set'));
    gtRoot   = fullfile(segRoot, '2. All Segmentation Groundtruths');
    gtSets   = struct('train', 'a. Training Set', 'test', 'b. Testing Set');
    typeDirs = {'1. Microaneurysms', '2. Haemorrhages', '3. Hard Exudates', '4. Soft Exudates'};
    typeTags = {'MA', 'HE', 'EX', 'SE'};
    nTypes   = numel(typeTags);

    pairsCell = {};
    for splitName = ["train", "test"]
        files = dir(fullfile(origDirs.(splitName), '*.jpg'));
        for f = 1:numel(files)
            id        = regexprep(files(f).name, '\.jpg$', '');
            imagePath = fullfile(origDirs.(splitName), files(f).name);
            rec       = initPairRecord(nTypes);
            rec.id    = id;
            rec.split = char(splitName);
            rec.imagePath = imagePath;

            reasons = {};
            try
                im = imread(imagePath);
                rec.imgH = size(im, 1); rec.imgW = size(im, 2);
                clear im;
            catch me
                reasons{end+1} = sprintf('image_unreadable_or_missing:%s', me.message); %#ok<AGROW>
            end

            for t = 1:nTypes
                mp = fullfile(gtRoot, gtSets.(splitName), typeDirs{t}, ...
                    sprintf('%s_%s.tif', id, typeTags{t}));
                rec.maskPaths{t} = mp;
                if exist(mp, 'file') ~= 2
                    rec.maskExists(t) = false;
                    reasons{end+1} = sprintf('missing_mask:%s', typeTags{t}); %#ok<AGROW>
                    continue;
                end
                rec.maskExists(t) = true;
                try
                    mm = imread(mp);
                    rec.maskReadable(t) = true;
                    rec.maskPxFull(t) = nnz(double(mm(:)) > 0);
                    rec.maskDimsMatch(t) = (size(mm,1) == rec.imgH) && ...
                                           (size(mm,2) == rec.imgW);
                    clear mm;
                catch me2
                    rec.maskReadable(t) = false;
                    reasons{end+1} = sprintf('unreadable_mask:%s (%s)', ...
                        typeTags{t}, me2.message); %#ok<AGROW>
                    continue;
                end
                if rec.maskPxFull(t) == 0
                    reasons{end+1} = sprintf('empty_mask:%s', typeTags{t}); %#ok<AGROW>
                elseif ~rec.maskDimsMatch(t) && rec.imgH > 0
                    reasons{end+1} = sprintf('mask_dim_mismatch:%s', typeTags{t}); %#ok<AGROW>
                end
            end

            usable = rec.maskExists & rec.maskReadable & ...
                     (rec.maskPxFull > 0) & rec.maskDimsMatch;
            rec.lesionTypes   = strjoin(typeTags(usable), '+');
            rec.nLesionTypes  = nnz(usable);
            rec.hasAnyLesionPx = rec.nLesionTypes > 0;

            if rec.imgH > 0 && rec.hasAnyLesionPx
                rec.status = 'valid';
                rec.skipReason = '';
            else
                rec.status = 'skip';
                if ~rec.hasAnyLesionPx
                    reasons{end+1} = 'no_valid_lesion_pixels'; %#ok<AGROW>
                end
                rec.skipReason = strjoin(reasons, '; ');
            end
            pairsCell{end+1} = rec; %#ok<AGROW>
        end
    end

    % Convert cell array of structs to struct array
    if numel(pairsCell) > 0
        pairs = [pairsCell{:}];
    else
        pairs = struct([]);
    end

    % Debug: check pairs structure
    fprintf('[DEBUG] pairs size: %s\n', mat2str(size(pairs)));
    fprintf('[DEBUG] pairs fields: %s\n', strjoin(fieldnames(pairs), ', '));
    if numel(pairs) > 0
        fprintf('[DEBUG] first element fields: %s\n', strjoin(fieldnames(pairs(1)), ', '));
    end

    % ---- summary ----
    validIdx = strcmp({pairs.status}, 'valid');
    audit = struct();
    audit.totalCandidates   = numel(pairs);
    audit.validPairs        = nnz(validIdx);
    audit.skipped           = audit.totalCandidates - audit.validPairs;
    audit.perSplit          = struct('train', nnz(strcmp({pairs.split},'train') & validIdx), ...
                                     'test',  nnz(strcmp({pairs.split},'test')  & validIdx));
    audit.skipReasons       = countReasonKinds(pairs);
    audit.typeCoverage      = struct();
    for t = 1:nTypes
        cov = arrayfun(@(p) p.maskExists(t) && p.maskReadable(t) && ...
                             p.maskPxFull(t) > 0 && p.maskDimsMatch(t), pairs);
        audit.typeCoverage.(lower(typeTags{t})) = struct( ...
            'filesOnDisk', nnz(arrayfun(@(p) p.maskExists(t), pairs)), ...
            'usableInCandidates', nnz(cov), ...
            'usableInValidPairs', nnz(cov & validIdx), ...
            'medianPxFull', median(arrayfun(@(p) p.maskPxFull(t), pairs(cov))));
    end
    audit.typeTags = {typeTags{:}};

    % ---- write outputs ----
    % Convert per-image mask arrays to cell arrays for table compatibility
    maskExistsCell = arrayfun(@(p) p.maskExists, pairs, 'UniformOutput', false);
    maskPxFullCell = arrayfun(@(p) p.maskPxFull, pairs, 'UniformOutput', false);
    
    % Make all variables column vectors (81x1) for table compatibility
    idCol = {pairs.id}';
    splitCol = {pairs.split}';
    imgWCol = arrayfun(@(p) p.imgW, pairs)';
    imgHCol = arrayfun(@(p) p.imgH, pairs)';
    statusCol = {pairs.status}';
    skipReasonCol = {pairs.skipReason}';
    nLesionTypesCol = arrayfun(@(p) p.nLesionTypes, pairs)';
    lesionTypesCol = {pairs.lesionTypes}';
    hasAnyLesionPxCol = arrayfun(@(p) double(p.hasAnyLesionPx), pairs)';
    maskExistsCol = maskExistsCell';
    maskPxFullCol = maskPxFullCell';
    
    % Debug: check sizes
    fprintf('[DEBUG] idCol: %s\n', mat2str(size(idCol)));
    fprintf('[DEBUG] splitCol: %s\n', mat2str(size(splitCol)));
    fprintf('[DEBUG] imgWCol: %s\n', mat2str(size(imgWCol)));
    fprintf('[DEBUG] imgHCol: %s\n', mat2str(size(imgHCol)));
    fprintf('[DEBUG] statusCol: %s\n', mat2str(size(statusCol)));
    fprintf('[DEBUG] skipReasonCol: %s\n', mat2str(size(skipReasonCol)));
    fprintf('[DEBUG] nLesionTypesCol: %s\n', mat2str(size(nLesionTypesCol)));
    fprintf('[DEBUG] lesionTypesCol: %s\n', mat2str(size(lesionTypesCol)));
    fprintf('[DEBUG] hasAnyLesionPxCol: %s\n', mat2str(size(hasAnyLesionPxCol)));
    fprintf('[DEBUG] maskExistsCol: %s\n', mat2str(size(maskExistsCol)));
    fprintf('[DEBUG] maskPxFullCol: %s\n', mat2str(size(maskPxFullCol)));
    
    T = table(idCol, splitCol, imgWCol, imgHCol, statusCol, skipReasonCol, ...
        nLesionTypesCol, lesionTypesCol, hasAnyLesionPxCol, maskExistsCol, maskPxFullCol, ...
        'VariableNames', {'image_id', 'split', 'img_w', 'img_h', 'status', ...
        'skip_reason', 'n_lesion_types', 'lesion_types', 'has_any_lesion_px', ...
        'mask_exists_ma_he_ex_se', 'mask_px_full_ma_he_ex_se'});
    writetable(T, fullfile(outDir, 'dataset_audit.csv'));

    md = fullfile(outDir, 'dataset_audit.md');
    fid = fopen(md, 'w');
    fprintf(fid, '# IDRiD lesion dataset audit (Grad-CAM alignment evaluation)\n\n');
    fprintf(fid, 'Generated: %s\n\n', char(datetime('now')));
    fprintf(fid, '## Summary\n\n');
    fprintf(fid, '- Total candidate images: %d\n', audit.totalCandidates);
    fprintf(fid, '- Valid image+mask pairs (usable for evaluation): %d\n', audit.validPairs);
    fprintf(fid, '-   of which train split: %d, test split: %d\n', audit.perSplit.train, audit.perSplit.test);
    fprintf(fid, '- Skipped images: %d (every skip has a documented reason)\n\n', audit.skipped);
    fprintf(fid, '## Skip reasons (an image can carry several)\n\n');
    r = audit.skipReasons;
    fprintf(fid, '- missing/unreadable image: %d\n', r.image_unreadable_or_missing);
    fprintf(fid, '- missing mask file: %d (per type: MA %d, HE %d, EX %d, SE %d)\n', ...
        r.total_missing_mask, r.missing_mask_MA, r.missing_mask_HE, ...
        r.missing_mask_EX, r.missing_mask_SE);
    fprintf(fid, '- unreadable mask: %d\n', r.unreadable_mask);
    fprintf(fid, '- empty mask (0 lesion px): %d (per type: MA %d, HE %d, EX %d, SE %d)\n', ...
        r.total_empty_mask, r.empty_mask_MA, r.empty_mask_HE, ...
        r.empty_mask_EX, r.empty_mask_SE);
    fprintf(fid, '- mask/image dimension mismatch: %d\n', r.mask_dim_mismatch);
    fprintf(fid, '- no valid lesion pixels in any type: %d\n', r.no_valid_lesion_pixels);
    fprintf(fid, '- other: %d\n\n', r.other);
    fprintf(fid, '## Per-lesion-type coverage (usable masks)\n\n');
    fprintf(fid, '| Type | files on disk | usable (candidates) | usable (valid pairs) | median mask px (full res) |\n');
    fprintf(fid, '|---|---|---|---|---|\n');
    for t = 1:nTypes
        c = audit.typeCoverage.(lower(typeTags{t}));
        fprintf(fid, '| %s | %d | %d | %d | %.0f |\n', typeTags{t}, ...
            c.filesOnDisk, c.usableInCandidates, c.usableInValidPairs, c.medianPxFull);
    end
    fprintf(fid, '\nNote: the IDRiD Disease-Grading label CSVs cover IDRiD_001..IDRiD_413\n');
    fprintf(fid, '(train) and IDRiD_001..IDRiD_103 (test) only; the segmentation images\n');
    fprintf(fid, 'IDRiD_01..IDRiD_81 are a distinct image set with NO 5-class grade labels.\n');
    fprintf(fid, 'Lesion metrics therefore do not require a grade label (documented\n');
    fprintf(fid, 'limitation; see the main report for the proxy correctness definition).\n');
    fclose(fid);

    save(fullfile(outDir, 'dataset_audit.mat'), 'audit', 'pairs', 'typeTags');
    fprintf('[AUDIT] candidates=%d valid=%d skipped=%d (train=%d test=%d)\n', ...
        audit.totalCandidates, audit.validPairs, audit.skipped, ...
        audit.perSplit.train, audit.perSplit.test);
end

% --------------------------------------------------------------------------
function rec = initPairRecord(nTypes)
%INITPAIRRECORD Field-complete record so struct-array growth stays uniform.
    rec = struct('id', '', 'split', '', 'imagePath', '', 'status', '', ...
        'skipReason', '', 'imgH', -1, 'imgW', -1, 'lesionTypes', '', ...
        'nLesionTypes', 0, 'hasAnyLesionPx', false, ...
        'maskPaths', {{'' '' '' ''}}, ...
        'maskExists', false(1, nTypes), 'maskReadable', false(1, nTypes), ...
        'maskDimsMatch', false(1, nTypes), 'maskPxFull', -ones(1, nTypes));
end

% --------------------------------------------------------------------------
function r = countReasonKinds(pairs)
%COUNTREASONKINDS Classify every documented skip reason token by kind.
    r = struct('image_unreadable_or_missing', 0, 'total_missing_mask', 0, ...
        'missing_mask_MA', 0, 'missing_mask_HE', 0, 'missing_mask_EX', 0, ...
        'missing_mask_SE', 0, 'unreadable_mask', 0, 'total_empty_mask', 0, ...
        'empty_mask_MA', 0, 'empty_mask_HE', 0, 'empty_mask_EX', 0, ...
        'empty_mask_SE', 0, 'mask_dim_mismatch', 0, ...
        'no_valid_lesion_pixels', 0, 'other', 0);
    for i = 1:numel(pairs)
        if strcmp(pairs(i).status, 'valid') || isempty(pairs(i).skipReason)
            continue;
        end
        toks = strtrim(strsplit(pairs(i).skipReason, ';'));
        for k = 1:numel(toks)
            tok = strtrim(toks{k});
            if isempty(tok), continue; end
            kindTok = regexp(tok, '^([^:]+)', 'tokens', 'once');
            kind = kindTok{1};
            tagTok = regexp(tok, ':(\w+)', 'tokens', 'once');
            switch kind
                case 'image_unreadable_or_missing'
                    r.image_unreadable_or_missing = r.image_unreadable_or_missing + 1;
                case 'missing_mask'
                    r.total_missing_mask = r.total_missing_mask + 1;
                    fld = ['missing_mask_', tagTok{1}];
                    r.(fld) = r.(fld) + 1;
                case 'unreadable_mask'
                    r.unreadable_mask = r.unreadable_mask + 1;
                case 'empty_mask'
                    r.total_empty_mask = r.total_empty_mask + 1;
                    fld = ['empty_mask_', tagTok{1}];
                    r.(fld) = r.(fld) + 1;
                case 'mask_dim_mismatch'
                    r.mask_dim_mismatch = r.mask_dim_mismatch + 1;
                case 'no_valid_lesion_pixels'
                    r.no_valid_lesion_pixels = r.no_valid_lesion_pixels + 1;
                otherwise
                    r.other = r.other + 1;
            end
        end
    end
end


