# Oddball EEG Dataset

Raw EEG data recorded during an oddball paradigm experiment in standard BrainVision format.

## Download
- **Google Drive:** [Download Raw Data](https://drive.google.com/drive/folders/1hpeILjG7RKZDvhKHT_iDE20ope9TlWhE?usp=sharing)

## Files
Keep all three files in this folder with the same base name:
- `Oddball.vhdr` — Header file (channel info, sampling rate, settings)
- `Oddball.vmrk` — Marker file (stimulus and event triggers)
- `Oddball.eeg` — Raw continuous voltage data (~72.5 MB)

## Quick Load (Python)
```python
import mne

# Point directly to the header file
raw = mne.io.read_raw_brainvision("Oddball.vhdr", preload=True)
events, event_dict = mne.events_from_annotations(raw)
