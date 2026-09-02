# Datasets — Complete Reference

## PS-Specified Datasets

### APTOS 2019 (Primary Training)
- **Size:** 3,662 train images, 1,928 test (hidden labels)
- **Labels:** ICDR 0-4 (1,805/370/999/193/295)
- **Source:** Aravind Eye Hospital, India
- **Download:** `kaggle competitions download -c aptos2019-blindness-detection`
- **Role:** Primary grader training. Best source of realistic poor-quality field images.

### IDRiD (Crown Jewel)
- **Size:** 516 total (413 train/103 test)
- **Labels:** DR 0-4 + DME 0-2 (grading); pixel masks for MA/HE/EX/SE on 81 images (54/27)
- **Source:** Kohli Eye Hospital, Nanded, Maharashtra
- **Camera:** Kowa VX-10α, 4288×2848, 50° FOV
- **Download:** `zenodo.org/records/17219542` (3 ZIPs)
- **Role:** The only lesion-level pixel truth. Everything explainable depends on ~54 training images.

### DRIVE (Vessel Segmentation)
- **Size:** 40 images (20/20 train/test), 33 no-DR + 7 mild-DR
- **Resolution:** 565×584, Canon CR5, 45° FOV
- **Download:** `kaggle datasets download -d andrewmvd/drive-digital-retinal-images-for-vessel-extraction`
- **Role:** Vessel segmentation pretraining only.

### Messidor-2 (External Validation)
- **Size:** 1,748 images / 874 patients (1,744 usable)
- **Source:** ADCIS (license request required)
- **Download:** `adcis.net/en/third-party/messidor2/`
- **Role:** External validation only — never train on it.

## Supplementary Datasets

### EyePACS 2015 (Pretraining)
- **Size:** 88,702 images (~24× APTOS)
- **Download:** `kaggle competitions download -c diabetic-retinopathy-detection`
- **Role:** Pretraining. Single biggest accuracy lever.

### EyeQ (Quality Labels)
- **Size:** 28,792 images, Good/Usable/Reject
- **Source:** GitHub `HzFu/EyeQ` + EyePACS base images
- **Role:** Quality gate training labels.

### e-ophtha (Lesion Enlargement)
- **e-ophtha-MA:** 148 images, 1,306 MA regions
- **e-ophtha-EX:** 47 EX + 35 normal
- **Source:** ADCIS (license request required)
- **Role:** Enlarges tiny lesion training set.

### DIARETDB1
- **Size:** 89 images (84 with DR, 5 normal)
- **Source:** HuggingFace / Academic Torrents
- **Role:** Additional lesion markings.

### STARE
- **Size:** 20 images
- **Source:** Clemson University (direct download)
- **Role:** Vessel segmentation pretraining.

### CHASE_DB1
- **Size:** 28 images (14 children, 2 eyes each)
- **Source:** Kingston University (direct download)
- **Role:** Vessel segmentation pretraining.

### HRF
- **Size:** 45 images (15 healthy, 15 DR, 15 glaucoma), 3504×2336
- **Source:** FAU Erlangen (direct download)
- **Role:** High-resolution vessel + FOV masks.

### ROC
- **Size:** 100 images (50/50 train/test)
- **Source:** University of Iowa (registration required)
- **Role:** MA-specific FROC evaluation.

### DRIMDB
- **Size:** ~216 images, 3-class quality grading
- **Source:** Kaggle / Academic Torrents
- **Role:** Quality assessment testing.
