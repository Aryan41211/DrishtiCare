# Day 1 — Setup (Sep 2)

## Focus
MATLAB access + team setup + dataset download

## Deliverables
- MATLAB running on every teammate's machine
- APTOS 2019 dataset downloaded and inspected
- Roles assigned

## Checklist

### Morning
- [ ] Check MATLAB campus license (mathworks.com with college email)
- [ ] If no license, start MATLAB Online or free trial
- [ ] Verify required toolboxes: `ver` in MATLAB console

### Afternoon
- [ ] Download APTOS 2019 from Kaggle
- [ ] Inspect dataset: view 5-10 sample images
- [ ] Assign team roles (see team/roles.md)

### Evening
- [ ] Confirm everyone can load images in MATLAB
- [ ] Set up shared folder/GitHub repo
- [ ] Review 10-day roadmap together

## MATLAB Commands to Run

```matlab
% Verify toolboxes
ver

% Check for required toolboxes
license('test', 'Image_Toolbox')
license('test', 'Computer_Vision_Toolbox')
license('test', 'Deep_Learning_Toolbox')
license('test', 'Statistics_Toolbox')
license('test', 'Simulink')

% Check GPU
gpuDeviceCount
gpuDevice
```

## Dataset Download

```bash
# If Kaggle CLI is set up
kaggle competitions download -c aptos2019-blindness-detection -p data/aptos2019 --unzip

# Or download manually from:
# https://www.kaggle.com/c/aptos2019-blindness-detection/data
```

## End of Day Check
- [ ] MATLAB open and working on all machines
- [ ] APTOS dataset downloaded
- [ ] Roles assigned
- [ ] Everyone understands the 10-day plan
