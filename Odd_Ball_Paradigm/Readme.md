# P300 Detection in Oddball paradigm

This repository contains reproducible pipelines for electroencephalography (EEG) event-related potential (ERP) analysis and Brain-Computer Interface (BCI) classification using EEGLAB and BCILAB in MATLAB.

## Project Structure

```text
├── data/
│   ├── oddball.vhdr          # BrainVision raw header file
│   ├── oddball.eeg           # Raw EEG data
│   ├── oddball.vmrk          # Marker/event file
├── scripts/
│   ├── run_eeglab_erp.m      # EEGLAB preprocessing, epoching & ERP difference plots
│   └── run_bcilab_bci.m      # BCILAB approach definition, training & cross-dataset evaluation
├── README.md
└── results/
    └── erp_cz_plot.png       # Generated ERP visualization
```

## Oddball Paradigm:
   - Evaluates cognitive attentional allocation and the P300 component.
   - Frequent standard stimuli (`'S  1'`) vs. infrequent oddball stimuli (`'S  2'`).

## Prerequisites

- MATLAB (R2018b or later recommended)
- [EEGLAB Toolbox](https://sccn.ucsd.edu/eeglab/) (with `bva-io` plugin for `.vhdr` support)
- [BCILAB Toolbox](https://github.com/sccn/bcilab)

## Quick Start

### 1. EEGLAB Preprocessing & ERPs
Run `scripts/run_eeglab_erp.m` in MATLAB:
- Imports raw BrainVision `.vhdr` files.
- Resamples to 250 Hz (satisfying the Nyquist limit for cognitive ERPs).
- Filters between 1–40 Hz and applies common average re-referencing.
- Segments epochs `[-500 ms, 1000 ms]` baseline-corrected from `[-500 ms, 0 ms]`.
- Generates condition-separated ERPs and difference waveforms at `Cz`.

### 2. BCILAB Machine Learning Pipeline
Run `scripts/run_bcilab_bci.m` in MATLAB:
- Constructs an ERP paradigm approach using windowed mean features (150–600 ms post-stimulus in 50 ms slices).
- Fits a shrinkage Linear Discriminant Analysis (LDA) classifier.
- Computes 10-fold cross-validated AUC and balanced loss.
- Extracts neurophysiologically valid spatial filter patterns.
- Tests cross-session/cross-subject decoding on transfer data.

## Theoretical Takeaways

- **Nyquist-Shannon Theorem:** Cognitive ERP power drops above 30 Hz. Resampling to 250 Hz leaves a 125 Hz Nyquist margin, preserving sub-millisecond latencies while speeding up pipeline processing.
- **Metric Selection:** Given the typical 80/20 class imbalance, naive classification yields 80% accuracy at chance. ROC-AUC and Cohen's Kappa must be used instead of unweighted classification accuracy.
- **Pattern Verification:** Inspect spatial patterns (forward models) rather than filter weights to ensure the decoder relies on parietal P300 activations instead of ocular or muscular artifacts.
