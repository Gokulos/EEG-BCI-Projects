clear; clc; close all;

%% 1. Environment & Path Setup
if ~isempty(mfilename('fullpath'))
    scriptDir = fileparts(mfilename('fullpath'));
else
    scriptDir = pwd;
end
dataFolder = fullfile(scriptDir, 'Datasets');

datasetFile = 'Motor_13Chans.set';
fullDataPath = fullfile(dataFolder, datasetFile);

if ~exist(fullDataPath, 'file')
    error('Dataset file not found at: %s', fullDataPath);
end

if ~exist('env_startup', 'file')
    error('BCILAB is not in the MATLAB path. Please add the BCILAB directory and run bcilab.');
end
bcilab;

%% 2. Load Continuous EEG Dataset
fprintf('Loading dataset: %s\n', fullDataPath);
data = io_loadset(fullDataPath);

%% 3. Define 13-Channel Sensorimotor Subspace
motorChannels = { ...
    'FC3', 'FCZ', 'FC4', ...
    'C5',  'C3',  'C1',  'CZ', 'C2', 'C4', 'C6', ...
    'CP3', 'CPZ', 'CP4' ...
};

%% 4. BCI Approach
approach = { ...
    'CSP', ...
    'SignalProcessing', { ...
        'ChannelSelection', { ...
            'Channels', motorChannels ...
        }, ...
        'Resampling', {'SamplingRate', []}, ...                      % Skip resampling to avoid upfirdn MEX errors
        'EpochExtraction', {'TimeWindow', [0.5 3.5]}, ...            % 0.5s to 3.5s post-cue epoch
        'FIRFilter', {'Frequencies', [6 8 30 32], ...
                      'Type', 'minimum-phase'} ...
    }, ...
    'Prediction', { ...
        'FeatureExtraction', {'PatternPairs', 2}, ...               % 2 pairs = 4 patterns total
        'MachineLearning', {'Learner', ...
            {'lda', 'Regularization', 'auto'}} ...
    } ...
};

%% 5. Classifier Training
fprintf('\nCalibrating model with 5-fold cross-validation...\n');
targetMarkers = {'T1', 'T2'}; % T1 = Left Fist, T2 = Right Fist

[loss, model, stats] = bci_train( ...
    'Data',             data, ...
    'Approach',         approach, ...
    'TargetMarkers',    targetMarkers, ...
    'EvaluationMetric', 'mcr', ...                                  % Misclassification rate
    'EvaluationScheme', {'chron', 5, 5} ...                         % 5-fold chronological cross-validation
);

%% 6. Performance Metrics Reporting
meanAccuracy = (1 - loss) * 100;
fprintf('\n================== CLASSIFICATION PERFORMANCE ==================\n');
fprintf('Mean Accuracy : %.2f%% (Loss/MCR: %.4f)\n', meanAccuracy, loss);

if isfield(stats, 'per_fold') && ~isempty(stats.per_fold)
    fprintf('\nFold-by-Fold Breakdown:\n');
    
    if isnumeric(stats.per_fold)
        for f = 1:length(stats.per_fold)
            foldMcr = stats.per_fold(f);
            foldAcc = (1 - foldMcr) * 100;
            fprintf('  Fold %d: Accuracy: %.2f%% | Error Rate: %.4f\n', f, foldAcc, foldMcr);
        end
    elseif isstruct(stats.per_fold)
        fields = fieldnames(stats.per_fold);
        for f = 1:length(stats.per_fold)
            foldMcr = NaN;
            for candidate = {'mcr', 'loss', 'metric', 'value'}
                if isfield(stats.per_fold(f), candidate{1})
                    foldMcr = stats.per_fold(f).(candidate{1});
                    break;
                end
            end
            if isnan(foldMcr)
                for k = 1:length(fields)
                    val = stats.per_fold(f).(fields{k});
                    if isnumeric(val) && isscalar(val)
                        foldMcr = val;
                        break;
                    end
                end
            end
            
            if ~isnan(foldMcr)
                foldAcc = (1 - foldMcr) * 100;
                fprintf('  Fold %d: Accuracy: %.2f%% | Error Rate: %.4f\n', f, foldAcc, foldMcr);
            else
                fprintf('  Fold %d: [Data unavailable]\n', f);
            end
        end
    end
end

if isfield(stats, 'confusion_matrix')
    cm = stats.confusion_matrix;
    fprintf('\nConfusion Matrix (Rows: True [T1, T2], Cols: Predicted [T1, T2]):\n');
    disp(cm);
    
    if isequal(size(cm), [2, 2])
        tpr = cm(1, 1) / sum(cm(1, :)); % Sensitivity (T1 / Left Fist)
        tnr = cm(2, 2) / sum(cm(2, :)); % Specificity (T2 / Right Fist)
        fpr = cm(2, 1) / sum(cm(2, :));
        fnr = cm(1, 2) / sum(cm(1, :));
        
        fprintf('True Positive Rate (T1 / Left Fist)  : %.3f\n', tpr);
        fprintf('True Negative Rate (T2 / Right Fist) : %.3f\n', tnr);
        fprintf('False Positive Rate                  : %.3f\n', fpr);
        fprintf('False Negative Rate                  : %.3f\n', fnr);
    end
end
fprintf('================================================================\n');

%% 7. Spatial Pattern Extraction & Validation
fprintf('\nExtracting forward-model spatial projection weights (a = (W^-1)^T)...\n');

try
    % Locate patterns in top-level featuremodel or nested prediction function
    if isfield(model, 'featuremodel') && isfield(model.featuremodel, 'patterns')
        patterns = model.featuremodel.patterns;
        modelChans = {model.featuremodel.chanlocs.labels};
    elseif isfield(model, 'tracking') && isfield(model.tracking, 'prediction_function')
        cspModel = model.tracking.prediction_function.model;
        if isfield(cspModel, 'patterns')
            patterns = cspModel.patterns;
        elseif isfield(cspModel, 'featuremodel') && isfield(cspModel.featuremodel, 'patterns')
            patterns = cspModel.featuremodel.patterns;
        elseif isfield(cspModel, 'filters')
            patterns = pinv(cspModel.filters)';
        else
            error('Could not locate CSP filter/pattern matrices in model structure.');
        end
        if isfield(cspModel, 'chanlocs')
            modelChans = {cspModel.chanlocs.labels};
        else
            modelChans = motorChannels;
        end
    else
        error('Unrecognized model structure for pattern extraction.');
    end
    
    % Ensure patterns is oriented as (channels x patterns)
    if size(patterns, 1) ~= length(modelChans)
        patterns = patterns';
    end
    
    n_pats = size(patterns, 2);
    
    % Display numerical patterns table
    fprintf('\n======================== CSP PATTERNS MATRIX ========================\n');
    fprintf('%-10s | %-12s | %-12s | %-12s | %-12s\n', 'Electrode', 'Pattern 1', 'Pattern 2', 'Pattern 3', 'Pattern 4');
    fprintf('%s\n', repmat('-', 1, 62));
    
    for ch = 1:length(modelChans)
        fprintf('%-10s | %+12.4f | %+12.4f | %+12.4f | %+12.4f\n', ...
            modelChans{ch}, patterns(ch, 1), patterns(ch, 2), patterns(ch, 3), patterns(ch, 4));
    end
    fprintf('%s\n', repmat('=', 1, 62));
    
    % Display neurophysiological extrema analysis
    fprintf('\n================== NEUROPHYSIOLOGICAL PEAKS ==================\n');
    for p = 1:n_pats
        [maxVal, maxIdx] = max(patterns(:, p));
        [minVal, minIdx] = min(patterns(:, p));
        
        if p <= n_pats / 2
            taskLabel = 'Class 1 (Left Fist / T1)';
        else
            taskLabel = 'Class 2 (Right Fist / T2)';
        end
        
        fprintf('Pattern %d [%s]:\n', p, taskLabel);
        fprintf('   -> Max Positive Pole: %-5s (%+.4f)\n', modelChans{maxIdx}, maxVal);
        fprintf('   -> Max Negative Pole: %-5s (%+.4f)\n\n', modelChans{minIdx}, minVal);
    end

catch ME
    warning('Pattern extraction notice: %s', ME.message);
end

%% 8. Model Visualization - Not accurate as mentioned in Readme.md
try
    bci_visualize(model);
catch ME
    fprintf('Visualization note: %s\n', ME.message);
end