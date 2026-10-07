%% 1. Load Dataset & Environment Setup
clear; clc;

% Load dataset directly from current working directory
dataFile = fullfile(pwd, 'oddball_cleaned.set');
fprintf('[INFO] Using dataset: %s\n', dataFile);

% Launch BCILAB
bcilab;

%% 2. Import & Verify Dataset
% Use exp_eval to materialize the BCILAB expression into a dataset struct
full_data = exp_eval(io_loadset(dataFile));
full_data = eeg_checkset(full_data);

%% 3. Partition Data into Train (70%) & Test (30%) Splits
split_sample = round(full_data.pnts * 0.70);

% Slice dataset using EEGLAB's pop_select
train_data = pop_select(full_data, 'point', [1, split_sample]);
test_data  = pop_select(full_data, 'point', [split_sample + 1, full_data.pnts]);

train_data = eeg_checkset(train_data);
test_data  = eeg_checkset(test_data);

%% 4. Define Windowed Means Approach with LDA Classifier
myapproach = {'Windowmeans', ...
    'SignalProcessing', { ...
        'EpochExtraction', {'TimeWindow', [-0.2 0.8]} ...
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

%% 5. Train Model with 10-Fold Cross-Validation
target_markers = {'S  1', 'S  2'};

[train_loss, trained_model, train_stats] = bci_train( ...
    'Approach', myapproach, ...
    'Data', train_data, ...
    'TargetMarkers', target_markers, ...
    'EvaluationMetric', 'auc', ...
    'EvaluationScheme', 10 ... % Direct integer syntax for 10-fold CV in BCILAB
);

fprintf('\n==========================================\n');
fprintf('--- 10-Fold Cross-Validation on Training Split ---\n');
fprintf('CV Predictive Loss:                     %.4f\n', train_loss);

% Calculate AUC cleanly depending on whether loss is signed or (1 - AUC)
if train_loss < 0
    cv_auc = -train_loss;
else
    cv_auc = 1 - train_loss;
end
fprintf('CV AUC Score:                          %.4f\n', cv_auc);
fprintf('==========================================\n');
%% 6. Visualize Model Parameters
bci_visualize(trained_model);

%% 7. Test Generalization on Held-Out Split
[predictions, test_loss, test_stats] = bci_predict( ...
    'Model', trained_model, ...
    'Data', test_data ...
);

fprintf('\n==========================================\n');
fprintf('--- Generalization on Held-Out Split ---\n');
fprintf('Held-Out Test Predictive Loss:         %.4f\n', test_loss);

% Safely check performance output
if isstruct(test_stats) && isfield(test_stats, 'auc')
    fprintf('Held-Out Test AUC Score:               %.4f\n', test_stats.auc);
elseif isstruct(predictions) && isfield(predictions, 'metrics') && isfield(predictions.metrics, 'auc')
    fprintf('Held-Out Test AUC Score:               %.4f\n', predictions.metrics.auc);
else
    fprintf('Held-Out Test Accuracy / Score:        %.4f\n', 1 - test_loss);
end
fprintf('==========================================\n');
