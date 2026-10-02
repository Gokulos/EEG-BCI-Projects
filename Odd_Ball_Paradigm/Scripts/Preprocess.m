%% Initialize EEGLAB, Load Datasets
[ALLEEG, EEG, CURRENTSET, ALLCOM] = eeglab('nogui');


% --- Auto-Install / Check bva-io Plugin ---
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

% 1. Load BrainVision Data
% Check if file is in dataFolder; fallback to current directory if not found
dataFile = 'oddball.vhdr';
if exist(fullfile(dataFolder, dataFile), 'file')
    loadPath = dataFolder;
else
    loadPath = pwd;
end

EEG = pop_loadbv(loadPath, dataFile);
[ALLEEG, EEG, CURRENTSET] = pop_newset(ALLEEG, EEG, 0, 'setname', 'raw_data', 'gui', 'off');

% 2. Edit Channel Locations
% Locate the standard template file from the dipfit plugin directory
dipfitPath = fileparts(which('pop_dipfit_settings.m'));
templateFile = fullfile(dipfitPath, 'standard_BEM', 'elec', 'standard_1005.elc');
if ~exist(templateFile, 'file')
    templateFile = 'standard-10-5-cap385.elp'; % Fallback to local default lookup
end
EEG = pop_chanedit(EEG, 'lookup', templateFile);
EEG = eeg_checkset(EEG);
[ALLEEG, EEG] = eeg_store(ALLEEG, EEG, CURRENTSET);

% 3. Resample to 250 Hz
EEG = pop_resample(EEG, 250);
[ALLEEG, EEG] = eeg_store(ALLEEG, EEG, CURRENTSET);

% 4. Bandpass Filter (1 - 40 Hz)
EEG = pop_eegfiltnew(EEG, 'locutoff', 1, 'hicutoff', 40);
[ALLEEG, EEG] = eeg_store(ALLEEG, EEG, CURRENTSET);

% 5. Re-reference to Common Average
EEG = pop_reref(EEG, []);
[ALLEEG, EEG, CURRENTSET] = pop_newset(ALLEEG, EEG, CURRENTSET, 'setname', 'preproc_clean', 'gui', 'off');
CLEAN_SET = CURRENTSET;

% 6. Identify Exact Event Triggers
% BrainVision markers can be 'S  1' (two spaces), 'S 1' (one space), or numeric
all_types = cellfun(@num2str, {EEG.event.type}, 'UniformOutput', false);

std_trigger = unique(all_types(contains(all_types, '1')));
tgt_trigger = unique(all_types(contains(all_types, '2')));

% Fallback to standard BrainVision spacing if exact match not found automatically
if isempty(std_trigger), std_trigger = {'S  1'}; end
if isempty(tgt_trigger), tgt_trigger = {'S  2'}; end

% 7. Epoch Extraction & Baseline Correction (-200 to 0 ms baseline recommended)
EEG_clean = ALLEEG(CLEAN_SET);

EEG_S1 = pop_epoch(EEG_clean, std_trigger, [-0.5 1], 'newname', 'Standards', 'epochinfo', 'yes');
EEG_S1 = pop_rmbase(EEG_S1, [-200 0]);
[ALLEEG, EEG_S1, SET_S1] = pop_newset(ALLEEG, EEG_S1, 0, 'gui', 'off');

EEG_S2 = pop_epoch(EEG_clean, tgt_trigger, [-0.5 1], 'newname', 'Oddballs', 'epochinfo', 'yes');
EEG_S2 = pop_rmbase(EEG_S2, [-200 0]);
[ALLEEG, EEG_S2, SET_S2] = pop_newset(ALLEEG, EEG_S2, 0, 'gui', 'off');

% 8. Plot ERP & Difference Wave at Cz
cz_chan = find(strcmpi({EEG_clean.chanlocs.labels}, 'Cz'));
if isempty(cz_chan)
    cz_chan = 1;
    warning('Channel Cz not found. Defaulting to channel %s.', EEG_clean.chanlocs(1).labels);
end

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