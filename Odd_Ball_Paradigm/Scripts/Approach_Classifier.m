clear; clc;
filename = 'Oddball.vhdr';

% Collect candidate directory locations
candidateFolders = {};

% A. Directory where this .m script is saved (if running from an m-file)
if ~isempty(mfilename('fullpath'))
    thisScriptDir = fileparts(mfilename('fullpath'));
    candidateFolders{end+1} = thisScriptDir;
    candidateFolders{end+1} = fullfile(thisScriptDir, 'Data');
end

% B. Current working directory right before BCILAB initializes
candidateFolders{end+1} = pwd;
candidateFolders{end+1} = fullfile(pwd, 'Data');

% C. Dedicated project paths
candidateFolders{end+1} = 'D:\Study\BTU University Subjects\BCI\Application_Project\Oddball Paradigm\Data';
candidateFolders{end+1} = 'D:\Study\BTU University Subjects\BCI\Application_Project\Oddball Paradigm';
candidateFolders{end+1} = 'D:\Study\BTU University Subjects\BCI\Final Project\Data';
candidateFolders{end+1} = 'D:\Study\BTU University Subjects\BCI\Final Project';

% Check candidate locations sequentially
dataFile = '';
for i = 1:numel(candidateFolders)
    trialPath = fullfile(candidateFolders{i}, filename);
    if exist(trialPath, 'file') == 2
        dataFile = trialPath;
        break;
    end
end

% D. Interactive UI Fallback: If still not found, prompt user to select it
if isempty(dataFile)
    warning('Auto-detection could not find "%s". Please select the file manually.', filename);
    [selectedFile, selectedFolder] = uigetfile({'*.vhdr', 'BrainVision Header (*.vhdr)'}, ...
        'Select the Oddball.vhdr dataset');
    if isequal(selectedFile, 0)
        error('No dataset was selected. Execution aborted.');
    else
        dataFile = fullfile(selectedFolder, selectedFile);
    end
end

fprintf('[INFO] Using dataset: %s\n', dataFile);

% =========================================================================
% 2. Start BCILAB & Verify Plugins
% =========================================================================
if isempty(which('bcilab'))
    bcilabInstallDir = 'D:\Study\BTU University Subjects\BCI\Final Project\BCILAB-devel\BCILAB-devel';
    if exist(bcilabInstallDir, 'dir')
        addpath(bcilabInstallDir);
    else
        error('BCILAB installation folder not found at: %s', bcilabInstallDir);
    end
end

% Launch BCILAB
bcilab;

% Ensure BrainVision I/O plugin is available
if isempty(which('pop_loadbv'))
    plugin_askinstall('bva-io', 'pop_loadbv', true);
end

% =========================================================================
% 3. Load & Materialize Dataset
% =========================================================================
try
    full_data = exp_eval(io_loadset(dataFile));
catch
    [fPath, fName, fExt] = fileparts(dataFile);
    full_data = pop_loadbv(fPath, [fName fExt]);
end

full_data = eeg_checkset(full_data);

% =========================================================================
% 4. Partition into Train (first 70%) and Test (last 30%)
% =========================================================================
split_sample = round(full_data.pnts * 0.70);

train_data = pop_select(full_data, 'point', [1, split_sample]);
test_data  = pop_select(full_data, 'point', [split_sample + 1, full_data.pnts]);

% =========================================================================
% 5. Define Windowed Means Approach with LDA Classifier
% =========================================================================
myapproach = {'Windowmeans', ...
    'SignalProcessing', { ...
        'Resampling', {'SamplingRate', 250}, ...
        'EpochExtraction', {'TimeWindow', [-0.2 0.8]}, ...
        'SpectralSelection', {'FrequencySpecification', [0.5 15]} ...
    }, ...
    'Prediction', { ...
        'FeatureExtraction', { ...
            'TimeWindows', [ ...
                0.15 0.20; 0.20 0.25; 0.25 0.30; 0.30 0.35; ...
                0.35 0.40; 0.40 0.45; 0.45 0.50; 0.50 0.55; 0.55 0.60] ...
        }, ...
        'MachineLearning', { ...
            'Learner', {'lda'} ... % Direct Linear Discriminant Analysis
        } ...
    } ...
};

% =========================================================================
% 6. Train Model on Target Classes with 10-Fold Cross-Validation
% =========================================================================
% Standard BrainVision triggers usually contain two spaces ('S  1', 'S  2')
target_markers = {'S  1', 'S  2'};

[train_loss, trained_model, train_stats] = bci_train( ...
    'Approach', myapproach, ...
    'Data', train_data, ...
    'TargetMarkers', target_markers, ...
    'EvaluationMetric', 'auc' ...
);

fprintf('\n==========================================\n');
fprintf('--- Cross-Validation on Training Split ---\n');
fprintf('CV Misclassification / Loss (1 - AUC): %.4f\n', train_loss);
fprintf('CV AUC Score:                          %.4f\n', 1 - train_loss);
fprintf('==========================================\n');

% =========================================================================
% 7. Visualize Model Parameters
% =========================================================================
bci_visualize(trained_model);

% =========================================================================
% 8. Apply Model to Unseen Test Split
% =========================================================================
[predictions, test_loss, test_stats] = bci_predict( ...
    'Model', trained_model, ...
    'Data', test_data ...
);

fprintf('\n==========================================\n');
fprintf('--- Generalization on Held-Out Split ---\n');
fprintf('Held-Out Test Predictive Loss:         %.4f\n', test_loss);
if isfield(test_stats, 'auc')
    fprintf('Held-Out Test AUC Score:               %.4f\n', test_stats.auc);
end
fprintf('==========================================\n');