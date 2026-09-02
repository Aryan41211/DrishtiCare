# Team Roles

## Role Assignments

| Role | Responsibility | Days Active |
|------|---------------|-------------|
| **Preprocessing Lead** (1-2 people) | Image quality assessment + CLAHE/illumination/denoising pipeline | Days 3-4 |
| **ML/Classifier Lead** (1-2 people) | Transfer learning setup, training, Grad-CAM integration | Days 5-7 |
| **Systems/Simulink Lead** (1 person) | Simulink throughput model | Day 8 |
| **Integration + Report Lead** (1 person) | Pipeline wiring, auto-generated report mockup | Day 9 |
| **Pitch/Documentation Lead** (1 person) | Slide deck, demo script, limitations framing | Day 10 |

## Role Details

### Preprocessing Lead
- **Days 3-4:** Build quality assessment and enhancement modules
- **Handoff:** Clean images to classifier team
- **Deliverables:**
  - `assessImageQuality(img)` function
  - `enhanceImage(img)` function
  - Sample outputs on 10-15 images

### ML/Classifier Lead
- **Days 5-7:** Set up and train DR classifier
- **Owns:** Accuracy/sensitivity/specificity numbers
- **Deliverables:**
  - Trained ResNet-18/50 on APTOS
  - Performance metrics on test set
  - Grad-CAM overlays

### Systems/Simulink Lead
- **Day 8:** Build throughput model
- **Owns:** Resource-allocation story for pitch
- **Deliverables:**
  - Simulink block diagram
  - Queue backlog graph
  - Bottleneck analysis

### Integration + Report Lead
- **Day 9:** Wire everything together
- **Deliverables:**
  - End-to-end pipeline script
  - Auto-generated report mockup
  - Demo-ready flow

### Pitch/Documentation Lead
- **Day 10:** Final deck and rehearsal
- **Deliverables:**
  - Slide deck
  - Demo script
  - Backup video

## Communication

- Daily standup: What did you do? What's blocking you?
- Shared folder: Google Drive or GitHub repo
- Handoff protocol: Preprocessing → Classifier → Integration
