# Day 2 — Data Exploration (Sep 3)

## Focus
Data exploration + repo/folder structure

## Deliverables
- Class distribution analysis of dataset
- Shared folder structure agreed
- Sample images viewed for quality variation

## Checklist

### Morning
- [ ] Analyze APTOS class distribution
- [ ] View sample images from each class (0-4)
- [ ] Note quality variations (blur, lighting, etc.)

### Afternoon
- [ ] Create folder structure in GitHub repo
- [ ] Set up `src/` folders for each module
- [ ] Set up `data/` folder structure

### Evening
- [ ] Document quality observations
- [ ] Plan preprocessing approach based on what you see
- [ ] Prepare for Day 3 (quality assessment)

## MATLAB Analysis

```matlab
% Load APTOS dataset
dataRoot = 'data/aptos2019';
ds = imageDatastore(dataRoot, 'IncludeSubfolders', true, 'LabelSource', 'foldernames');

% Class distribution
countEachLabel(ds)

% View sample images
figure;
for i = 1:5
    img = readimage(ds, i);
    subplot(1,5,i);
    imshow(img);
    title(string(ds.Labels(i)));
end
```

## Folder Structure

```
DrishtiCare/
├── src/
│   ├── quality/          # Quality assessment
│   ├── enhancement/      # CLAHE, denoising
│   ├── segmentation/     # OD, vessels
│   ├── grading/          # Classifier
│   ├── explainability/   # Grad-CAM
│   ├── simulink/         # Throughput model
│   └── utils/            # Helpers
├── data/
│   ├── aptos2019/        # Training data
│   ├── idrid/            # Reference data
│   └── drive/            # Vessel segmentation
├── docs/
└── pitch/
```

## End of Day Check
- [ ] Class distribution documented
- [ ] Folder structure in GitHub
- [ ] Quality observations written down
- [ ] Ready for Day 3
