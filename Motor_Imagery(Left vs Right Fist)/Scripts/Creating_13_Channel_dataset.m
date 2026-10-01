clear; clc; close all;

%% 1. Path Setup
if ~isempty(mfilename('fullpath'))
    scriptDir = fileparts(mfilename('fullpath'));
else
    scriptDir = pwd;
end
dataFolder = fullfile(scriptDir, 'Datasets');

baseName = '6Filtered,T7Interpolated,Avg_Rereferenced,ICA_Weights,Pruned_with_ICA';
setFileName = [baseName, '.set'];
fdtFileName = [baseName, '.fdt'];

setFullPath = fullfile(dataFolder, setFileName);
fdtFullPath = fullfile(dataFolder, fdtFileName);

if ~exist(setFullPath, 'file') || ~exist(fdtFullPath, 'file')
    error('Ensure both %s and %s exist in: %s', setFileName, fdtFileName, dataFolder);
end

outputFileName = 'Motor_13Chans.set';
outputFullPath = fullfile(dataFolder, outputFileName);

%% 2. Load Header and Overwrite Outdated Internal Pointer
fprintf('Loading header from: %s\n', setFileName);
matData = load('-mat', setFullPath);
if isfield(matData, 'EEG')
    EEG = matData.EEG;
else
    EEG = matData;
end

% Point the struct directly to your actual renamed .fdt file
EEG.data     = fdtFileName;
EEG.filepath = dataFolder;

% Load the binary data array using the updated path
fprintf('Reading binary data array from: %s\n', fdtFileName);
EEG.data = eeg_getdatact(EEG);
EEG = eeg_checkset(EEG);

%% 3. Select 13 Motor Channels
motorChannels = { ...
    'FC3', 'FCZ', 'FC4', ...
    'C5',  'C3',  'C1',  'CZ', 'C2', 'C4', 'C6', ...
    'CP3', 'CPZ', 'CP4' ...
};

fprintf('Selecting 13 sensorimotor channels...\n');
EEG_motor = pop_select(EEG, 'channel', motorChannels);

%% 4. Save as Unified Single File
fprintf('Saving unified dataset to:\n  %s\n', outputFullPath);
pop_saveset(EEG_motor, 'filename', outputFileName, 'filepath', dataFolder, 'savemode', 'onefile');

fprintf('\nDone! "%s" has been generated as a single-file container.\n', outputFileName);