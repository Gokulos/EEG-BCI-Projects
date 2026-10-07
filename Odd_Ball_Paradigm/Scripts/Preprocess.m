%% Initialize EEGLAB, Load Datasets
[ALLEEG, EEG, CURRENTSET, ALLCOM] = eeglab('nogui');

% Auto-Install / Check bva-io Plugin
if isempty(which('pop_loadbv'))
    fprintf('Plugin "bva-io" not detected. Attempting automatic installation...\n');
    try
        plugin_askinstall('bva-io', 'pop_loadbv', true);
    catch ME
        error(['Could not auto-install "bva-io". Please install it via EEGLAB GUI: ' ...
               'Manage EEGLAB extensions -> search "bva-io" -> install.']);
    end
end

% Determine data directory
if ~isempty(mfilename('fullpath'))
    scriptDir = fileparts(mfilename('fullpath'));
else
    scriptDir = pwd;
end
dataFolder = fullfile(scriptDir, 'Data');

% Load Data
dataFile = 'oddball.vhdr';
if exist(fullfile(dataFolder, dataFile), 'file')
    loadPath = dataFolder;
else
    loadPath = pwd;
end

EEG = pop_loadbv(loadPath, dataFile);

% EXCLUDE EOG CHANNELS
eog_chans = {'EOGv1', 'EOGv2', 'EOGh1', 'EOGh2'};
EEG = pop_select(EEG, 'nochannel', eog_chans);

[ALLEEG, EEG, CURRENTSET] = pop_newset(ALLEEG, EEG, 0, 'setname', 'raw_data', 'gui', 'off');

% Edit Channel Locations (Standard 10 - 10 System)
EEG = pop_chanedit(EEG, 'lookup', 'standard-10-5-cap385.elp');
EEG = eeg_checkset(EEG);
[ALLEEG, EEG] = eeg_store(ALLEEG, EEG, CURRENTSET);

% Resample to 250 Hz
EEG = pop_resample(EEG, 250);
[ALLEEG, EEG] = eeg_store(ALLEEG, EEG, CURRENTSET);

% Bandpass Filter (1 - 40 Hz)
EEG = pop_eegfiltnew(EEG, 1, 40);
[ALLEEG, EEG] = eeg_store(ALLEEG, EEG, CURRENTSET);

% Re-reference to Common Average
EEG = pop_reref(EEG, []);
[ALLEEG, EEG, CURRENTSET] = pop_newset(ALLEEG, EEG, CURRENTSET, 'setname', 'preproc_clean', 'gui', 'off');
CLEAN_SET = CURRENTSET;

% Identify Exact Event Triggers
all_types = cellfun(@num2str, {EEG.event.type}, 'UniformOutput', false);

std_trigger = unique(all_types(contains(all_types, '1')));
tgt_trigger = unique(all_types(contains(all_types, '2')));

% Epoch Extraction & Baseline Correction (-200 to 0 ms baseline)
EEG_clean = ALLEEG(CLEAN_SET);

EEG_S1 = pop_epoch(EEG_clean, std_trigger, [-0.2 0.8], 'newname', 'Standards', 'epochinfo', 'yes');
EEG_S1 = pop_rmbase(EEG_S1, [-200 0]);
[ALLEEG, EEG_S1, SET_S1] = pop_newset(ALLEEG, EEG_S1, 0, 'gui', 'off');

EEG_S2 = pop_epoch(EEG_clean, tgt_trigger, [-0.2 0.8], 'newname', 'Oddballs', 'epochinfo', 'yes');
EEG_S2 = pop_rmbase(EEG_S2, [-200 0]);
[ALLEEG, EEG_S2, SET_S2] = pop_newset(ALLEEG, EEG_S2, 0, 'gui', 'off');

% Plot ERP & Difference Wave at Cz
cz_chan = find(strcmpi({EEG_clean.chanlocs.labels}, 'Cz'));
time_vec = EEG_S1.times;

% Average across trials along dimension 3 (channels x timepoints x trials)
erp_s1 = mean(EEG_S1.data(cz_chan, :, :), 3);
erp_s2 = mean(EEG_S2.data(cz_chan, :, :), 3);
erp_diff = erp_s2 - erp_s1;

figure('Color', 'w', 'Name', 'ERP at Cz');
plot(time_vec, erp_s1, 'b-', 'LineWidth', 1.5); hold on;
plot(time_vec, erp_s2, 'r-', 'LineWidth', 1.8);
plot(time_vec, erp_diff, 'k--', 'LineWidth', 1.5);
yline(0, 'k:', 'Alpha', 0.5);
xline(0, 'k:', 'Alpha', 0.5);
grid on;
xlabel('Time (ms)');
ylabel('Amplitude (\muV)');
title(sprintf('ERP Comparison at Channel %s (n_{std}=%d, n_{tgt}=%d)', ...
    EEG_clean.chanlocs(cz_chan).labels, EEG_S1.trials, EEG_S2.trials));
legend({'Standard', 'Target', 'Difference (Target - Standard)'}, 'Location', 'northwest');


%% Save the cleaned data
% Save cleaned dataset to the current working directory for classifier
EEG = pop_saveset(EEG_clean, 'filename', 'oddball_cleaned.set', 'filepath', pwd);
