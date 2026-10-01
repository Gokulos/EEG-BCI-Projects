%% Initialize EEGLAB, Load Datasets
[ALLEEG, EEG, CURRENTSET, ALLCOM] = eeglab('nogui');

% Use mfilename when in an m-file script, or fall back to pwd if run from command window
if ~isempty(mfilename('fullpath'))
    scriptDir = fileparts(mfilename('fullpath'));
else
    scriptDir = pwd;
end
dataFolder = fullfile(scriptDir, 'Datasets');

% Dataset A
setA = safe_loadset('1Original_Dataset.set', dataFolder);
[ALLEEG, setA, CURRENTSET] = pop_newset(ALLEEG, setA, 0, 'setname', 'Condition_A', 'gui', 'off');

% Dataset B
setB = safe_loadset('6Filtered,T7Interpolated,Avg_Rereferenced,ICA_Weights,Pruned_with_ICA.set', dataFolder);
[ALLEEG, setB, CURRENTSET] = pop_newset(ALLEEG, setB, 0, 'setname', 'Condition_B', 'gui', 'off');

% Dataset C
setC = safe_loadset('7T1_Left_Epochs_Only.set', dataFolder);
[ALLEEG, setC, CURRENTSET] = pop_newset(ALLEEG, setC, 0, 'setname', 'Condition_C', 'gui', 'off');

% Dataset D
setD = safe_loadset('8T2_Right_Epochs_Only.set', dataFolder);
[ALLEEG, setD, CURRENTSET] = pop_newset(ALLEEG, setD, 0, 'setname', 'Condition_D', 'gui', 'off');

% Refresh
eeglab redraw;

%% Dynamically Find Channel Indices
chanC3_A = find(strcmpi({setC.chanlocs.labels}, 'C3'));
chanC4_A = find(strcmpi({setC.chanlocs.labels}, 'C4'));
chanC3_B = find(strcmpi({setD.chanlocs.labels}, 'C3'));
chanC4_B = find(strcmpi({setD.chanlocs.labels}, 'C4'));

if isempty(chanC3_A) || isempty(chanC4_A) || isempty(chanC3_B) || isempty(chanC4_B)
    error('Could not find channel C3 or C4 in one or more datasets. Check your montage labels.');
end

%% Visualize Continuous Epochs - Figure 2,7
pop_eegplot(setA, 1, 1, 1); % Before ICA Pruning
pop_eegplot(setB, 1, 1, 1); % After ICA Pruning

%% ERSP Plots - Figure 8,11

% Dataset C: Channel C3
figure('Color', 'w');
pop_newtimef(setC, 1, chanC3_A, [-1000 2000], [3 0.8], ...
    'topovec', chanC3_A, ...
    'elocs', setC.chanlocs, ...
    'chaninfo', setC.chaninfo, ...
    'caption', 'C3', ...
    'baseline', [0], ...
    'freqs', [2 35], ...
    'padratio', 4, ...
    'plotitc', 'off', ...
    'plotphase', 'off');

% Dataset C: Channel C4
figure('Color', 'w');
pop_newtimef(setC, 1, chanC4_A, [-1000 2000], [3 0.8], ...
    'topovec', chanC4_A, ...
    'elocs', setC.chanlocs, ...
    'chaninfo', setC.chaninfo, ...
    'caption', 'C4', ...
    'baseline', [0], ...
    'freqs', [2 35], ...
    'padratio', 4, ...
    'plotitc', 'off', ...
    'plotphase', 'off');

% Dataset D: Channel C3
figure('Color', 'w');
pop_newtimef(setD, 1, chanC3_B, [-1000 2000], [3 0.8], ...
    'topovec', chanC3_B, ...
    'elocs', setD.chanlocs, ...
    'chaninfo', setD.chaninfo, ...
    'caption', 'C3', ...
    'baseline', [0], ...
    'freqs', [2 35], ...
    'padratio', 4, ...
    'plotitc', 'off', ...
    'plotphase', 'off');

% Dataset D: Channel C4
figure('Color', 'w');
pop_newtimef(setD, 1, chanC4_B, [-1000 2000], [3 0.8], ...
    'topovec', chanC4_B, ...
    'elocs', setD.chanlocs, ...
    'chaninfo', setD.chaninfo, ...
    'caption', 'C4', ...
    'baseline', [0], ...
    'freqs', [2 35], ...
    'padratio', 4, ...
    'plotitc', 'off', ...
    'plotphase', 'off');

%% Power Spectrums

freqRange = [2 35];

% Dataset C - C3
figure('Name', 'Left Fist Channel C3', 'Color', 'w');
pop_spectopo(setC, 1, [setC.xmin setC.xmax]*1000, 'EEG', ...
    'freqrange', freqRange, ...
    'electrodes', 'off', ...
    'plotchans', chanC3_A, ...
    'title', 'Left Fist Channel C3');

% Dataset C - C4
figure('Name', 'Left Fist Channel C4', 'Color', 'w');
pop_spectopo(setC, 1, [setC.xmin setC.xmax]*1000, 'EEG', ...
    'freqrange', freqRange, ...
    'electrodes', 'off', ...
    'plotchans', chanC4_A, ...
    'title', 'Left Fist Channel C4');

% Dataset D - C3
figure('Name', 'Right Fist Channel C3', 'Color', 'w');
pop_spectopo(setD, 1, [setD.xmin setD.xmax]*1000, 'EEG', ...
    'freqrange', freqRange, ...
    'electrodes', 'off', ...
    'plotchans', chanC3_B, ...
    'title', 'Right Fist Channel C3');

% Dataset D - C4
figure('Name', 'Right Fist Channel C4', 'Color', 'w');
pop_spectopo(setD, 1, [setD.xmin setD.xmax]*1000, 'EEG', ...
    'freqrange', freqRange, ...
    'electrodes', 'off', ...
    'plotchans', chanC4_B, ...
    'title', 'Right Fist Channel C4');

%% Head Topographic maps

figure('Name', 'Channel Spectra and Maps: Left Fist', 'Color', 'w');
pop_spectopo(setC, 1, [setC.xmin setC.xmax]*1000, 'EEG', ...
    'freq', [11 12 13], ...
    'freqrange', [2 35], ...
    'electrodes', 'on', ...
    'title', ' T1');

figure('Name', 'Channel Spectra and Maps: Right Fist', 'Color', 'w');
pop_spectopo(setD, 1, [setD.xmin setD.xmax]*1000, 'EEG', ...
    'freq', [11 12 13 14], ...
    'freqrange', [2 35], ...
    'electrodes', 'on', ...
    'title', ' T2 ');

%% Robust Loader Function (Direct Binary Float Reader)
function EEG = safe_loadset(setFilename, folderPath)
    setFullPath = fullfile(folderPath, setFilename);
    [~, baseName, ~] = fileparts(setFilename);
    
    % 1. Load MATLAB structure directly from .set file
    loadedData = load(setFullPath, '-mat');
    if isfield(loadedData, 'EEG')
        EEG = loadedData.EEG;
    else
        EEG = loadedData;
    end
    
    EEG.filepath = folderPath;
    EEG.filename = setFilename;
    
    % 2. If data is already numeric in memory, validate and return
    if isnumeric(EEG.data) && ~isempty(EEG.data)
        EEG = eeg_checkset(EEG);
        return;
    end
    
    % 3. Find the actual corresponding .fdt file on disk
    targetFdt = '';
    
    % Candidate 1: Exact match with set basename (e.g. 1Original_Dataset.fdt)
    if isfile(fullfile(folderPath, [baseName '.fdt']))
        targetFdt = fullfile(folderPath, [baseName '.fdt']);
    % Candidate 2: Internal datfile if it actually exists
    elseif isfield(EEG, 'datfile') && ~isempty(EEG.datfile) && isfile(fullfile(folderPath, EEG.datfile))
        targetFdt = fullfile(folderPath, EEG.datfile);
    else
        % Candidate 3: Search for any .fdt starting with the leading prefix (e.g., '1')
        prefix = baseName(1:min(2, length(baseName)));
        fdtList = dir(fullfile(folderPath, '*.fdt'));
        for k = 1:length(fdtList)
            if startsWith(fdtList(k).name, prefix, 'IgnoreCase', true)
                targetFdt = fullfile(folderPath, fdtList(k).name);
                break;
            end
        end
        % Candidate 4: Any single .fdt file if only one is in the folder
        if isempty(targetFdt) && length(fdtList) == 1
            targetFdt = fullfile(folderPath, fdtList(1).name);
        end
    end
    
    if isempty(targetFdt) || ~isfile(targetFdt)
        error('Could not find any corresponding .fdt file for %s in %s', setFilename, folderPath);
    end
    
    % 4. Directly read binary IEEE single-precision float array from the .fdt file
    fid = fopen(targetFdt, 'rb', 'ieee-le');
    if fid == -1
        error('Cannot open binary file: %s', targetFdt);
    end
    
    trials = EEG.trials;
    if isempty(trials) || trials == 0
        trials = 1;
    end
    
    totalPoints = EEG.nbchan * EEG.pnts * trials;
    rawFloats = fread(fid, totalPoints, 'float32');
    fclose(fid);
    
    % 5. Reshape into standard EEGLAB dimensions [channels, timepoints, epochs]
    if trials > 1
        EEG.data = reshape(rawFloats, [EEG.nbchan, EEG.pnts, trials]);
    else
        EEG.data = reshape(rawFloats, [EEG.nbchan, EEG.pnts]);
    end
    
    % 6. Clean internal tracking pointers to match current loaded state
    [~, fdtName, fdtExt] = fileparts(targetFdt);
    EEG.datfile = [fdtName fdtExt];
    
    % 7. Standard EEGLAB structure consistency checks
    EEG = eeg_checkset(EEG);
end