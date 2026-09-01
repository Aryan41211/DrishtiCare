# Key Papers — Annotated Bibliography

## DR Screening Systems

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

### AADR-AI (Nature Sci Rep, 2025)
- **Architecture:** CNN-Transformer ensemble
- **Results:** Up to 96.7% accuracy for multi-class DR grading
- **Key contribution:** Attention-augmented models for spatial feature extraction

### STMFNet (Frontiers in Medicine, 2026)
- **Architecture:** Spatial texture multi-scale fusion network
- **Results:** 98.10% accuracy for DR grading
- **Key contribution:** Multi-scale feature fusion for texture analysis

### MadhuNetrAI (Global Epidemiology, 2025)
- **Context:** Resource-poor settings in India
- **Key contribution:** Validation in low-resource environments with limited infrastructure

## Foundation Models & Transformers

### RETFound (Nature, 2023)
- **Architecture:** Self-supervised retinal foundation model
- **Scale:** Pretrained on 1.6M unlabeled retinal images
- **Key contribution:** Strong generalization across ocular diseases

### Vision Foundation Models for DR (arXiv 2608.28207, Aug 2026)
- **Models evaluated:** DINOv2, CLIP, ViT
- **Adaptation strategies:** Full fine-tuning, linear probing, LoRA (Low-Rank Adaptation)
- **Key finding:** Well-designed CNNs with attention still compete with ViT on small datasets

### TOViT (2025)
- **Architecture:** Task-Optimized Vision Transformer
- **Task:** DR detection and severity classification
- **Key contribution:** ViT specifically designed for DR grading

### Cra-Net (2024)
- **Architecture:** Transformer-guided category-relation attention
- **Task:** DR grading
- **Key contribution:** Category-specific attention mechanisms

## Vision-Language Models

### XDR-VLLM (2025)
- **Task:** Explainable VLLM for DR diagnosis
- **Key contribution:** Multimodal explainability for clinical decision support

### Horizon-Aware VLM (NeurIPS 2025)
- **Task:** Forecasting DR progression
- **Input:** Fundus images + clinical text prompts (age, gender, eye laterality)
- **Results:** AUROC improved from 0.654 → 0.683 with demographic context

### Khokhar et al. (2026)
- **Architecture:** CNN-Transformer ensembles + VLM-generated textual rationales
- **Methods:** Grad-CAM++ and VLM-conditioned prompting
- **Key contribution:** Multimodal explainability with textual explanations

## Explainable AI (XAI)

### Grad-CAM (Selvaraju et al., 2017) — ICCV
- **Method:** Gradient-weighted class activation mapping
- **Key contribution:** Baseline visual explanation method

### Grad-CAM++
- **Improvement:** Better localization for multiple objects of same class
- **Application:** DR grading with lesion-level explanations

### Is Grad-CAM Explainable in Medical Images? (Springer, 2024)
- **Finding:** Grad-CAM effective but has limitations — heatmaps can be noisy, inconsistent
- **Recommendation:** Incorporate prior knowledge and sophisticated gradient computation

### TCAV (Testing with Concept Activation Vectors)
- **Method:** Measures model sensitivity to high-level concepts
- **Application:** Can map to clinical entities (MA, HE, EX, SE, NV)
- **Pitfall:** Random images still produce CAVs → significance testing recommended

### ACE (Automatic Concept-based Explanations)
- **Method:** Extends TCAV with automated concept discovery
- **Process:** Segments images → clusters in activation space → TCAV scoring
- **Key contribution:** No manual concept labeling needed

## OOD Detection

### Mahalanobis OOD (UNSURE/MICCAI 2023, Best Paper)
- **Method:** Multi-branch Mahalanobis distance detection
- **Key contribution:** Detect OOD at different network depths
- **Benchmark:** Created OOD dataset with pacemaker devices as OOD class

### Mahalanobis++ (Müller & Hein, 2025)
- **Improvement:** Feature normalization for better separation
- **Key contribution:** Improved in-distribution vs OOD feature distribution separation

### X-Mahalanobis (NeurIPS 2025)
- **Method:** Transformer feature mixing for reliable OOD detection
- **Key contribution:** Combines features from multiple layers

### Energy-Based OOD (Liu et al., NeurIPS 2020)
- **Method:** Energy score: E(x) = -log Σ_k exp(f_k(x))
- **Results:** 18.03% reduction in average FPR (at TPR 95%) vs softmax confidence
- **Key contribution:** Works with any pre-trained classifier, parameter-free

## Cascade Systems

### Efficient Inference with Model Cascades (OpenReview, 2023)
- **Finding:** 2-model cascades provide significant cost savings; 3-model only marginally better
- **Design rule:** Choose models with large computational cost differences

### Confidence-Gated Training (arXiv 2509.17885, 2026)
- **Method:** Conditionally propagates gradients from deeper exits only when preceding exits fail
- **Key contribution:** Reduces average inference cost while improving accuracy

### CalexNet (arXiv 2509.08318, 2026)
- **Method:** Cascade-aligned training + Class Precision Margin calibration
- **Results:** 31.58% FLOP reduction for 1% accuracy tradeoff
- **Key contribution:** Drop-in replacement for any frozen-backbone early-exit cascade

### T-RECX (2023)
- **Method:** Early-view features concatenated with final features as regularizer
- **Key contribution:** Mitigates "overthinking" problem
- **Results:** 87.4% accuracy with reduced FLOPs vs 87.2% baseline

## Mixture of Experts

### Med-MoE (EMNLP 2024)
- **Method:** Lightweight framework for multimodal medical tasks
- **Key contribution:** Trainable router selects domain-specific experts per input modality
- **Efficiency:** Only 30-50% of parameters activated per inference

### Low-Rank MoE (MICCAI 2024)
- **Method:** For continual learning in medical image segmentation
- **Key contribution:** Addresses catastrophic forgetting

### MoE for Computational Pathology (BMC Medical Imaging, 2025)
- **Method:** Experts handle different image quality levels (blur vs sharp)
- **Key contribution:** Improves robustness under variable image conditions

## DR Grading Standards

### ICDR Classification (Nature Eye, 2023)
- **Scale:** ICDR 0-4 mapped to ETDRS levels
- **Key finding:** ICDR developed via international consensus (2002, modified Delphi with 14 experts from 11 countries)
- **Clinical significance:**
  - Grade 0-1: <1% 1-year risk of PDR
  - Grade 2: ~5% risk
  - Grade 3: ~15-20% risk
  - Grade 4: Immediate vision threat

### DAPHNE System (2021)
- **Method:** Feature-based (lesion-level) grading
- **Results:** QWK 0.85 on Kenya dataset; 92% sensitivity for referable DR
- **Key contribution:** Adaptable to any grading scheme without retraining

## Real-World Deployments

| System | Location | Scale | Key Finding |
|--------|----------|-------|-------------|
| Google ARDA at Aravind | Tamil Nadu, India | 71 vision centers | 0% miss rate for referable DR |
| Remidio Medios DR AI | Rural India (Himachal Pradesh, West Bengal) | 50+ healthcare workers | CDSCO-approved; offline AI; 9+ clinical trials |
| AIDRSS | Multi-centric India | Multi-site validation | High sensitivity across diverse populations |
| MONA.health | Erasmus MC, Netherlands | 405 patients | AUC 96.5% in routine clinical care |
| India AI community screening | National programme | Country-wide | First AI-driven national DR screening (Dec 2025) |
