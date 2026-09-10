# DrishtiCare — Third-Party & License Inventory

Compiled: 2026-09-10 (hardening Phase 19). Engineering/research project; NOT a
clinical device. All models were trained and evaluated on the datasets below
under their research/educational terms. Distribution rule: no dataset images are
re-distributed in this repository (only trained model weights under individual
model-files, split lists, and derived analysis artifacts).

## 1. Pretrained model weights (architecture)

| Component | Source | Terms |
|---|---|---|
| `resnet18` network architecture + pretrained weights (champion 5-class & binary, and all 16 experimental .mat files reference the same architecture) | **MathWorks Deep Learning Toolbox** `resnet18` (supporting network, pretrained on ImageNet-1k RN18) | Covered by the MATLAB license agreement (Deep Learning Toolbox, "supported networks"). Not redistributed: weights are embedded in trained `.mat` artifacts generated from a private training run. |

No other architecture is used anywhere in `src` (verified by grep: only
`resnet18`).

## 2. Datasets

| Dataset | Role in project | Source / access | License / terms | Local status | Compliance |
|---|---|---|---|---|---|
| APTOS 2019 (3,662 train / 1,928 test) | Primary 5-class grader training; binary referable training | Kaggle competition `aptos2019-blindness-detection` | Kaggle competition terms; research/educational use. Official test set is public-leaderboard blind (no labels) | `data/aptos2019` present; test images present but **unlabeled** (never used for tuning; excluded from all metric computation) | Compliant |
| IDRiD (516 imgs; DR+segmentation on 81) | Lesion/OD/MA/fovea ground truth; internal test evaluation | Zenodo `zenodo.org/records/17219542` | Research license via Zenodo record | `data/idrid` present | Compliant |
| DRIVE (40 imgs) | Vessel segmentation pretraining | Kaggle `andrewmvd/drive-digital-retinal-images-for-vessel-extraction` | Research terms on distribution sites | used in vessel module | Compliant |
| EyePACS 2015 (88,702 imgs) | Pretraining | Kaggle competition `diabetic-retinopathy-detection` | Kaggle research terms | pretraining only, no images in repo | Compliant |
| EyeQ (28,792) | Quality-gate label source | GitHub `HzFu/EyeQ` (EyePACS-derived) | Research terms (GitHub) | quality gate training labels | Compliant |
| e-ophtha (MA/EX) | Lesion enlargement | ADCIS (license request required) | ADCIS research license | (used in lesion development) | Compliant / pending re-request as needed |
| DIARETDB1 (89) | Additional lesion markings | HuggingFace / Academic Torrents | Research terms | not in current repo scope | Compliant |
| STARE (20) | Vessel pretraining | Clemson University direct | Research terms | not in current repo scope | Compliant |
| CHASE_DB1 (28) | Vessel pretraining | Kingston University | Research terms | not in current repo scope | Compliant |
| HRF (45) | High-res vessel validation | FAU Erlangen | Research terms | not in current repo scope | Compliant |
| **Messidor-2 (1,748)** | **External validation (Blocked)** | ADCIS `adcis.net/en/third-party/messidor2/` | Research/educational only, no redistribution, must acknowledge: *"Kindly provided by the Messidor program partners (see https://www.adcis.net/en/third-party/messidor/)"* + cite Decencière 2014 & Abràmoff 2013 | **Not downloaded** — requires user ADCIS registration/download | Pending (Phase 16) |
| Sin-NP DR 2019 | External validation (candidate) | Internal distribution link (Notion) | Research terms | **Not downloaded** | Pending (Phase 14/16) |
| DRIMDB | Quality assessment testing | Kaggle / Academic Torrents | Research terms | `data/drimdb` present | Compliant |

## 3. Software dependencies

| Dependency | Version (pinned) | License via |
|---|---|---|
| MATLAB | 26.1.0.3346908 (R2026a) Update 5, win64 | MathWorks license |
| Deep Learning Toolbox | per MATLAB install (R2026a) | MathWorks license |
| Image Processing Toolbox | per MATLAB install | MathWorks license |
| Statistics and Machine Learning Toolbox | per MATLAB install | MathWorks license |
| (SimEvents/Simulink) | **NOT installed** — Phase 15 substitutes a scripted discrete-event simulation | n/a |
| External File-Exchange / third-party MATLAB add-ons | **None** (checked via `matlab.addons.installedAddons`) | n/a |

## 4. Obligations summary
1. No dataset images are redistributed in this repo.
2. Pretrained weights are from the licensed MathWorks `resnet18`; the trained
   model `.mat` files are project artifacts (not redistributions of ImageNet).
3. If Messidor-2 is downloaded and used for external validation, publications
   must acknowledge the Messidor partners and cite the two required papers.
4. Clinical disclaimer: this is an engineering/research demonstration; no
   clinical validation is claimed.