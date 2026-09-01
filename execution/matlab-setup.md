# MATLAB Setup — Environment Configuration

## License Verification

```matlab
ver  % Lists all installed toolboxes
license('test', 'Image_Toolbox')
license('test', 'Computer_Vision_Toolbox')
license('test', 'Deep_Learning_Toolbox')
license('test', 'Statistics_Toolbox')
license('test', 'Simulink')
```

## GPU Verification

```matlab
gpuDeviceCount  % Should return > 0
gpuDevice        % Shows GPU details
```

## Project Setup

```matlab
addpath('src/quality');
addpath('src/segmentation');
addpath('src/grading');
addpath('src/explainability');
addpath('src/utils');
addpath('data');
dataRoot = 'C:\projects\DrishtiCare\data';
```

## SimEvents Check

```matlab
license('test', 'SimEvents_')
% If not available, use Stateflow approximation
```

## Recommended MATLAB Version

- R2024a or later
- `trainnet` API available in R2023b+
- `gradCAM` works with `dlnetwork` objects (R2023b+)
