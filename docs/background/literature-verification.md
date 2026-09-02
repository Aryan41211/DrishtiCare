# Literature Verification — Benchmark Claims

## Landmark Papers (Verified)

### Gulshan et al. 2016 (JAMA)
- **High-specificity point:** Sensitivity 90.3%, Specificity 98.5% on Messidor-2
- **High-sensitivity point:** Sensitivity 96.1%, Specificity 93.9% on Messidor-2
- EyePACS-1: 9,963 images, 4,997 patients, 7.8% RDR prevalence
- Messidor-2: 1,748 images, 874 patients, 14.6% RDR prevalence
- **TRAP:** Two operating points — quoting one without naming which misrepresents the paper
- **Replication failure:** 2019 PLOS ONE reproduction got AUC 0.951 (EyePACS) and 0.853 (Messidor-2) vs original 0.99/0.99

### Abràmoff et al. 2016 (IDx-DR, IOVS)
- Sensitivity 96.8%, Specificity 87.0% on Messidor-2
- AUC 0.980
- No cases of severe NPDR, PDR, or ME missed

### Ting et al. 2017 (JAMA)
- Primary validation: 71,896 images, 14,880 patients
- Referable DR: Sensitivity 90.5%, Specificity 91.6%
- Vision-threatening DR: Sensitivity 100%, Specificity 91.1%

### Krause et al. 2018 (Ophthalmology)
- Weighted-kappa between majority-decision and full adjudication: 0.91
- Individual specialists: 74.4%-82.1% sensitivity before adjudication
- Most common discrepancy cause: missed microaneurysm

### IDx-DR FDA Clearance (April 2018)
- Published figures: 87.2% sensitivity, 90.7% specificity, 96.1% imageability
- FDA De Novo summary: 87.4% sensitivity, 89.5% specificity (pre-adjustment)
- 900-patient trial at 10 primary care sites

## Recent Deployments (2024-2026)

### MONA.health (Nature Sci Rep, Feb 2026)
- **Task:** Referable DR detection
- **Results:** AUC 0.965, Sensitivity 88.9%, Specificity 98.7%
- **Key contribution:** Real-world clinical deployment at Erasmus MC (405 patients)

### Google ARDA at Aravind (JAMA Network Open, Mar 2025)
- **Task:** DR screening at 71 vision centers in Tamil Nadu
- **Results:** 0% miss rate for referable DR
- **Key contribution:** Largest deployed AI screening system in India (128K training images)

### EyeArt Meta-Analysis (AJO, 2026)
- **Task:** Referable DR screening
- **Results:** Sensitivity 95% (92-97), Specificity 81% (74-87)
- **Scale:** 162,695 exams analyzed

### Remidio Medios DR AI (2024)
- **Context:** Rural India (Himachal Pradesh, West Bengal)
- **Results:** CDSCO-approved; offline AI; 9+ clinical trials
- **Key contribution:** First Indian ophthalmic AI software approved

### India National AI DR Screening (Dec 2025)
- **Context:** Country-wide programme
- **Key contribution:** First AI-driven national DR screening programme

## Dataset Verification

| Dataset | Confirmed Size | Notes |
|---------|---------------|-------|
| APTOS 2019 | 3,662 train (1,805/370/999/193/295 for grades 0-4) | Test: 1,928 images, hidden labels |
| IDRiD | 516 total (413 train/103 test) grading; 81 images (54/27) with pixel masks | Kowa VX-10α, 4288×2848, Nanded Maharashtra |
| DRIVE | 40 images (20/20), 33 no-DR + 7 mild-DR | 565×584, Canon CR5, 45° FOV |
| Messidor-2 | 1,748 images / 874 patients; 1,744 usable (4 ungradable excluded) | External validation only |
| EyePACS 2015 | 88,702 images (~24× APTOS) | kaggle.com/c/diabetic-retinopathy-detection |

## Unverified (Check Before Citing)

- IDRiD ISBI-2018 per-lesion segmentation scores (Porwal et al., Med Image Analysis 59, 2020)
- APTOS winning private-leaderboard QWK (check Kaggle leaderboard)
- DRIVE vessel-segmentation SOTA (modern deep learning)
- MA sensitivity at fixed FP/image from ROC challenge / e-ophtha

## Supplementary Datasets (Verified)

| Dataset | Size | Source |
|---------|------|--------|
| EyeQ | 28,792 images, Good/Usable/Reject | GitHub HzFu/EyeQ |
| e-ophtha-MA | 148 images, 1,306 MA regions | ADCIS |
| e-ophtha-EX | 47 EX + 35 normal | ADCIS |
| DIARETDB1 | 89 images | HuggingFace / Academic Torrents |
| ROC | 100 images (50/50) | University of Iowa |
| STARE | 20 images | Clemson University |
| CHASE_DB1 | 28 images | Kingston University |
| HRF | 45 images (3504×2336) | FAU Erlangen |
| DRIMDB | ~216 images, 3-class quality grading | Kaggle / Academic Torrents |
