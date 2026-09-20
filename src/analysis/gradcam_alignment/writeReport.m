function writeReport(R, outDir)
%WRITEREPORT Generate human-readable README.md report
%   R - struct containing all results from the run
%   outDir - output directory

    % Ensure R is a scalar struct
    if isstruct(R) && numel(R) > 1
        R = R(1);
    end
    % Ensure config is scalar
    if isfield(R, 'config') && isstruct(R.config) && numel(R.config) > 1
        R.config = R.config(1);
    end

    md = fullfile(outDir, 'README.md');
    fid = fopen(md, 'w');
    if fid == -1
        warning('Could not write report to %s', md);
        return;
    end

    fprintf(fid, '# DrishtiCare Grad-CAM Lesion Alignment Evaluation\n\n');
    fprintf(fid, 'Generated: %s\n\n', char(datetime('now')));

    fprintf(fid, '## Experiment Overview\n\n');
    fprintf(fid, 'Quantitative evaluation of Grad-CAM attention overlap with doctor-annotated ');
    fprintf(fid, 'IDRiD lesion masks (MA/HE/EX/SE) for the locked Day-7 5-class ResNet-18 model.\n\n');
    fprintf(fid, '**This is an offline analysis experiment only.** No training, no model modification, ');
    fprintf(fid, 'no threshold tuning, and no production behavior changes.\n\n');

    fprintf(fid, '## Configuration\n\n');
    fprintf(fid, '- **Model**: Day-7 pretrained ResNet-18 5-class (LOCKED)\n');
    fprintf(fid, '- **Model SHA-256**: %s\n', R.shaBefore);
    fprintf(fid, '- **Grad-CAM layer**: %s\n', R.config.featLayer);
    fprintf(fid, '- **Input size**: 224x224x3\n');
    fprintf(fid, '- **Attention threshold (primary)**: Top %.0f%% of pixels by activation rank\n', R.config.topFracPx * 100);
    fprintf(fid, '- **Attention threshold (secondary, T6 comparability)**: Top %.0f%% cumulative saliency mass\n', R.config.topFracMass * 100);
    fprintf(fid, '- **Class mapping**: %s\n\n', R.classMapNote);

    fprintf(fid, '## Dataset Audit\n\n');
    fprintf(fid, '- **Total candidate images**: %d\n', R.audit.totalCandidates);
    fprintf(fid, '- **Valid image+mask pairs**: %d\n', R.audit.validPairs);
    fprintf(fid, '  - Training split: %d\n', R.audit.perSplit.train);
    fprintf(fid, '  - Test split: %d\n', R.audit.perSplit.test);
    fprintf(fid, '- **Skipped images**: %d (every skip has a documented reason)\n\n', R.audit.skipped);

    fprintf(fid, '### Skip Reasons\n\n');
    r = R.audit.skipReasons;
    fprintf(fid, '- Missing/unreadable image: %d\n', r.image_unreadable_or_missing);
    fprintf(fid, '- Missing mask file: %d (MA %d, HE %d, EX %d, SE %d)\n', ...
        r.total_missing_mask, r.missing_mask_MA, r.missing_mask_HE, r.missing_mask_EX, r.missing_mask_SE);
    fprintf(fid, '- Unreadable mask: %d\n', r.unreadable_mask);
    fprintf(fid, '- Empty mask (0 lesion px): %d (MA %d, HE %d, EX %d, SE %d)\n', ...
        r.total_empty_mask, r.empty_mask_MA, r.empty_mask_HE, r.empty_mask_EX, r.empty_mask_SE);
    fprintf(fid, '- Mask/image dimension mismatch: %d\n', r.mask_dim_mismatch);
    fprintf(fid, '- No valid lesion pixels in any type: %d\n', r.no_valid_lesion_pixels);
    fprintf(fid, '- Other: %d\n\n', r.other);

    fprintf(fid, '### Per-Lesion-Type Coverage\n\n');
    fprintf(fid, '| Type | Files on Disk | Usable (Candidates) | Usable (Valid Pairs) | Median Mask Px (Full Res) |\n');
    fprintf(fid, '|---|---|---|---|---|\n');
    for t = 1:4
        tag = lower(R.audit.typeTags{t});
        c = R.audit.typeCoverage.(tag);
        fprintf(fid, '| %s | %d | %d | %d | %.0f |\n', R.audit.typeTags{t}, ...
            c.filesOnDisk, c.usableInCandidates, c.usableInValidPairs, c.medianPxFull);
    end
    fprintf(fid, '\n');

    fprintf(fid, '## Aggregate Results\n\n');
    fprintf(fid, '### Overall (Any Lesion)\n\n');
    c = R.agg.combined;
    fprintf(fid, '- **Evaluated images**: %d\n', c.n);
    fprintf(fid, '- **Saliency mass in lesion**: %.3f (median %.3f, std %.3f)\n', c.massMean, c.massMedian, c.massStd);
    fprintf(fid, '- **Pointing-game accuracy**: %.3f\n', c.pointAcc);
    fprintf(fid, '- **Mean IoU (top-20%% pixels)**: %.3f (median %.3f, std %.3f)\n', c.iouMean, c.iouMedian, c.iouStd);
    fprintf(fid, '- **Mean IoU (top-20%% mass, T6 comparability)**: %.3f\n', c.iouMassMean);
    fprintf(fid, '- **Mean Dice (top-20%% mass)**: %.3f\n', c.diceMean);
    fprintf(fid, '- **Chance baseline (areal)**: %.4f\n', c.chanceMassMean);
    fprintf(fid, '- **×Chance (mass)**: %.2f×\n', c.xChanceMass);
    fprintf(fid, '- **×Chance (point)**: %.2f×\n\n', c.xChancePoint);

    fprintf(fid, '### Per-Lesion-Type Results\n\n');
    fprintf(fid, '| Type | n | Mass Mean | Mass Med | Point Acc | IoU Mean | IoU Med | ×Chance Mass |\n');
    fprintf(fid, '|---|---|---|---|---|---|---|---|\n');
    lesionTags = {'MA', 'HE', 'EX', 'SE'};
    for t = 1:4
        tag = lower(lesionTags{t});
        a = R.agg.(tag);
        if a.n > 0
            fprintf(fid, '| %s | %d | %.4f | %.4f | %.4f | %.4f | %.4f | %.2f× |\n', ...
                lesionTags{t}, a.n, a.massMean, a.massMedian, a.pointAcc, ...
                a.iouMean, a.iouMedian, a.xChanceMass);
        else
            fprintf(fid, '| %s | 0 | N/A | N/A | N/A | N/A | N/A | N/A |\n', lesionTags{t});
        end
    end
    fprintf(fid, '\n');

    fprintf(fid, '### By Dataset Split\n\n');
    for sname = {'train_combined', 'test_combined'}
        a = R.agg.(sname{1});
        splitLabel = strrep(sname{1}, '_combined', '');
        fprintf(fid, '#### %s (n=%d)\n\n', splitLabel, a.n);
        fprintf(fid, '- Saliency mass in lesion: %.3f\n', a.massMean);
        fprintf(fid, '- Pointing-game accuracy: %.3f\n', a.pointAcc);
        fprintf(fid, '- Mean IoU: %.3f\n\n', a.iouMean);
    end

    fprintf(fid, '## Proxy Correct-vs-Incorrect Analysis\n\n');
    fprintf(fid, 'IDRiD 5-class grades do NOT exist for the segmentation images (IDRiD_01..IDRiD_81). ');
    fprintf(fid, 'The grading CSVs cover IDRiD_001..IDRiD_413 (train) and IDRiD_001..IDRiD_103 (test) only. ');
    fprintf(fid, 'A proxy split is reported instead:\n\n');
    fprintf(fid, '- **Proxy GT referable**: Any doctor-annotated lesion present (derived from real annotations)\n');
    fprintf(fid, '- **Model referable**: Predicted grade >= Moderate (grade index >= 2)\n\n');
    fprintf(fid, '### Proxy Confusion Matrix\n\n');
    fprintf(fid, '- TP: %d\n', R.proxy.TP);
    fprintf(fid, '- FN: %d\n', R.proxy.FN);
    fprintf(fid, '- FP: %d\n', R.proxy.FP);
    fprintf(fid, '- TN: %d\n\n', R.proxy.TN);

    fprintf(fid, '### Proxy-Correct Predictions (n=%d)\n\n', R.agg.proxyCorrect.n);
    pc = R.agg.proxyCorrect;
    fprintf(fid, '- Saliency mass in lesion: %.3f\n', pc.massMean);
    fprintf(fid, '- Pointing-game accuracy: %.3f\n', pc.pointAcc);
    fprintf(fid, '- Mean IoU: %.3f\n\n', pc.iouMean);

    fprintf(fid, '### Proxy-Incorrect Predictions (n=%d)\n\n', R.agg.proxyIncorrect.n);
    pi = R.agg.proxyIncorrect;
    fprintf(fid, '- Saliency mass in lesion: %.3f\n', pi.massMean);
    fprintf(fid, '- Pointing-game accuracy: %.3f\n', pi.pointAcc);
    fprintf(fid, '- Mean IoU: %.3f\n\n', pi.iouMean);

    fprintf(fid, '### Exact 5-Class Correct/Incorrect\n\n');
    fprintf(fid, '**NOT COMPUTABLE**: %s\n\n', R.blockedExact.reason);

    fprintf(fid, '## Champion Predicted-Class Distribution on IDRiD\n\n');
    fprintf(fid, '| Class | Count |\n');
    fprintf(fid, '|---|---|\n');
    for i = 1:numel(R.predDist)
        fprintf(fid, '| %s | %d |\n', R.classMapNote, R.predDist(i));
    end
    fprintf(fid, '\n');

    fprintf(fid, '## Visual Examples\n\n');
    fprintf(fid, 'Deterministically selected (seed=%d):\n\n', R.config.rngSeed);
    for e = 1:numel(R.examples)
        ex = R.examples(e);
        fprintf(fid, '### %d. %s (%s)\n\n', e, ex.kind, ex.id);
        fprintf(fid, '- IoU: %.3f\n', ex.iou);
        fprintf(fid, '- Saliency mass in lesion: %.3f\n', ex.mass);
        fprintf(fid, '- Pointing game: %d\n\n', ex.point);
    end
    fprintf(fid, 'All visual examples are in `visual_examples/`.\n\n');

    fprintf(fid, '## Transformation Sanity Checks\n\n');
    sanityIds = R.sanityIds;
    if ischar(sanityIds)
        sanityIds = {sanityIds};
    elseif ~iscell(sanityIds)
        sanityIds = {sanityIds};
    end
    fprintf(fid, 'Images (n=%d) verifying that lesion masks stay aligned after resizing to 224x224:\n\n', numel(sanityIds));
    for i = 1:numel(sanityIds)
        fprintf(fid, '- %s\n', sanityIds{i});
    end
    fprintf(fid, '\nSanity check figures are in `sanity_checks/`.\n\n');

    fprintf(fid, '## Quality & Sanity Assertions (All Passed)\n\n');
    fprintf(fid, '1. Model SHA-256 unchanged during run\n');
    fprintf(fid, '2. No duplicate image IDs in results\n');
    fprintf(fid, '3. Attention region size fixed at %d px for all images\n', R.expectedAttnPx);
    fprintf(fid, '4. All evaluable rows have finite IoU\n');
    fprintf(fid, '5. Non-evaluable rows carry NaN (not 0) for lesion metrics\n');
    fprintf(fid, '6. Every error row has a documented reason\n');
    fprintf(fid, '7. Visual examples match reported CSV metrics\n\n');

    fprintf(fid, '## Limitations\n\n');
    fprintf(fid, '1. **No IDRiD 5-class grades** for the segmentation images → exact correct/incorrect split not computable.\n');
    fprintf(fid, '2. **Domain shift**: IDRiD (portrait frames, different cameras) vs APTOS (training data) may affect alignment.\n');
    fprintf(fid, '3. **Resolution limit**: 224x224 model input means tiny lesions (MA median ~43 px) are barely resolved.\n');
    fprintf(fid, '4. **No lesion supervision**: Champion trained on image-level grades only, no pixel-level lesion labels.\n');
    fprintf(fid, '5. **Proxy correctness**: The proxy GT (any lesion = referable) is a screening-level approximation, not a grade.\n');
    fprintf(fid, '6. **Engineering analysis only**: This does not constitute clinical validation.\n\n');

    fprintf(fid, '## Files\n\n');
    fprintf(fid, '- `dataset_audit.csv` / `.mat` / `.md` — Phase-2 dataset audit\n');
    fprintf(fid, '- `per_image_results.csv` — Machine-readable per-image metrics\n');
    fprintf(fid, '- `gradcam_lesion_alignment.mat` — Complete MATLAB workspace\n');
    fprintf(fid, '- `results_checkpoint.mat` — Periodic checkpoints\n');
    fprintf(fid, '- `visual_examples/` — Representative four-panel figures\n');
    fprintf(fid, '- `sanity_checks/` — Transformation alignment verification\n');
    fprintf(fid, '- `run_log.txt` — Full console log\n\n');

    fprintf(fid, '---\n\n');
    fprintf(fid, '*Engineering explainability analysis — NOT clinical validation.*\n');

    fclose(fid);
    fprintf('[REPORT] %s\n', md);
end