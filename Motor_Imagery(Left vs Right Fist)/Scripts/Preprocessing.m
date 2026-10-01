%% Initialize EEGLAB and Load Dataset
[ALLEEG, EEG, CURRENTSET, ALLCOM] = eeglab;

candidatePaths = { ...
    'D:\Study\BTU University Subjects\BCI\Project\Preprocessing\Fixed\FIIS', ...
    'D:\Study\BTU University Subjects\BCI\Application_Project\Project\Datasets', ...
    fullfile(pwd, 'Datasets'), ...
    pwd ...
};

% Also check relative path if running from an m-file
if ~isempty(mfilename('fullpath'))
    candidatePaths = [ {fullfile(fileparts(mfilename('fullpath')), 'Datasets')}, candidatePaths ];
end

% Pick the first directory that actually exists on this system
filePath = '';
for i = 1:length(candidatePaths)
    if exist(candidatePaths{i}, 'dir')
        filePath = candidatePaths{i};
        break;
    end
end

if isempty(filePath)
    error('None of the specified dataset directories exist. Check your folder paths.');
end

% List potential filenames for Dataset 1
candidateNames = { ...
    'Original_dataset_1.set', ...
    '1Original_Dataset.set', ...
    '1 - Original Dataset.set' ...
};

fileName = '';
for i = 1:length(candidateNames)
    if isfile(fullfile(filePath, candidateNames{i}))
        fileName = candidateNames{i};
        break;
    end
end

if isempty(fileName)
    error('Could not find Dataset 1 under any expected name in: %s', filePath);
end

fprintf('Loading dataset: %s from %s\n', fileName, filePath);

% Load using safe_loadset to prevent 1.fdt naming errors
EEG = safe_loadset(fileName, filePath);
[ALLEEG, EEG, CURRENTSET] = pop_newset(ALLEEG, EEG, 0, ...
    'setname', EEG.setname, ...
    'gui', 'off');
eeglab redraw;

%% Compute Average Reference, Update dataset in memory 
EEG = pop_reref(EEG, []);
EEG = eeg_checkset(EEG);
[ALLEEG, EEG, CURRENTSET] = pop_newset(ALLEEG, EEG, CURRENTSET, ...
    'overwrite', 'on', ...
    'gui', 'off');
eeglab redraw;

%% Apply High-Pass Filter at 1 Hz
EEG = pop_eegfiltnew(EEG, 'locutoff', 1, 'plotfreqz', 0);
EEG = eeg_checkset(EEG);
[ALLEEG, EEG, CURRENTSET] = pop_newset(ALLEEG, EEG, CURRENTSET, ...
    'overwrite', 'on', ...
    'gui', 'off');
eeglab redraw;

%% Plot/Scroll Channel Data
pop_eegplot(EEG, 1, 1, 1);

%% Interpolate Channel T7
targetLabel = 'T7';
badChanIdx = find(strcmpi({EEG.chanlocs.labels}, targetLabel));
if isempty(badChanIdx)
    warning('Channel %s was not found in EEG.chanlocs. Skipping interpolation.', targetLabel);
else
    EEG = pop_interp(EEG, badChanIdx, 'spherical');
    EEG = eeg_checkset(EEG);
    [ALLEEG, EEG, CURRENTSET] = pop_newset(ALLEEG, EEG, CURRENTSET, ...
        'overwrite', 'on', ...
        'gui', 'off');
    eeglab redraw;
    fprintf('Channel %s (index %d) successfully interpolated using spherical splines.\n', ...
        targetLabel, badChanIdx);
end

%% Decompose Data by ICA: Extended Infomax 
targetRank = EEG.nbchan - 1; % Account for CAR rank deficiency
EEG = pop_runica(EEG, ...
    'icatype', 'runica', ...
    'extended', 1, ...
    'pca', targetRank);
EEG = eeg_checkset(EEG);
[ALLEEG, EEG, CURRENTSET] = pop_newset(ALLEEG, EEG, CURRENTSET, ...
    'overwrite', 'on', ...
    'gui', 'off');
eeglab redraw;

%% Plot Component Topographies
pop_selectcomps(EEG, 1:size(EEG.icaweights, 1));

%% Components Flag/Inspect via Scalp Maps
numComps = size(EEG.icaweights, 1);
compsToReject = [1, 2, 4, 19:25, 27, 29:31, 35, 36:63];
% Guard against indices exceeding the actual number of ICA components decomposed
compsToReject = compsToReject(compsToReject <= numComps);

EEG.reject.gcompreject = zeros(1, numComps);
EEG.reject.gcompreject(compsToReject) = 1;
pop_selectcomps(EEG, 1:numComps);

%% Remove Flagged Components from Data
EEG = pop_subcomp(EEG, compsToReject, 0);
EEG = eeg_checkset(EEG);
[ALLEEG, EEG, CURRENTSET] = pop_newset(ALLEEG, EEG, CURRENTSET, ...
    'overwrite', 'on', ...
    'gui', 'off');
eeglab redraw;
fprintf('Successfully removed %d components. Remaining: %d\n', ...
    length(compsToReject), size(EEG.icaweights, 1));

%% Plot/Scroll Channel Data
pop_eegplot(EEG, 1, 1, 1);

%% Save Dataset Locally to desired path
savePath = fullfile(filePath, 'Saved_Preprocessed'); 
saveName = 'dataDengnrnfndf.set';  
if ~exist(savePath, 'dir')
    mkdir(savePath);
end
EEG = pop_saveset(EEG, ...
    'filename', saveName, ...
    'filepath', savePath, ...
    'check', 'on', ...      
    'savemode', 'twofiles'); 
EEG = eeg_checkset(EEG);

% Strip extension safely regardless of file extension length
[~, cleanSetName] = fileparts(saveName);
[ALLEEG, EEG, CURRENTSET] = pop_newset(ALLEEG, EEG, CURRENTSET, ...
    'setname', cleanSetName, ...
    'overwrite', 'on', ...
    'gui', 'off');
eeglab redraw;
fprintf('Dataset successfully saved to: %s\n', fullfile(savePath, saveName));

%% Extract Epochs
eventTypes   = {'T1', 'T2'};       
epochLimits  = [-1, 2];           
baselineWin  = [-1000, 0];     
EEG = pop_epoch(EEG, eventTypes, epochLimits, ...
    'newname', [EEG.setname '_epoched'], ...
    'epochinfo', 'yes');  
EEG = eeg_checkset(EEG);
EEG = pop_rmbase(EEG, baselineWin);
EEG = eeg_checkset(EEG);
[ALLEEG, EEG, CURRENTSET] = pop_newset(ALLEEG, EEG, CURRENTSET, ...
    'overwrite', 'off', ...       
    'gui', 'off');
eeglab redraw;

fprintf('Extracted %d epochs across triggers {%s}.\nData size: [%d channels x %d points x %d trials]\n', ...
    EEG.trials, strjoin(eventTypes, ', '), EEG.nbchan, EEG.pnts, EEG.trials);

%% Split into two datasets for Visualization (T1/T2)

% T1
EEG_T1 = pop_selectevent(EEG, ...
    'type', {'T1'}, ...
    'deleteevents', 'off', ...
    'deleteepochs', 'on', ...   
    'invertepochs', 'off');

EEG_T1.setname = [EEG.setname '_T1'];
EEG_T1 = eeg_checkset(EEG_T1);
[ALLEEG, EEG_T1, CURRENTSET] = pop_newset(ALLEEG, EEG_T1, 0, ...
    'setname', EEG_T1.setname, ...
    'gui', 'off');

% T2
EEG_T2 = pop_selectevent(EEG, ...
    'type', {'T2'}, ...
    'deleteevents', 'off', ...
    'deleteepochs', 'on', ...    
    'invertepochs', 'off');

EEG_T2.setname = [EEG.setname '_T2'];
EEG_T2 = eeg_checkset(EEG_T2);
[ALLEEG, EEG_T2, CURRENTSET] = pop_newset(ALLEEG, EEG_T2, 0, ...
    'setname', EEG_T2.setname, ...
    'gui', 'off');

eeglab redraw;

fprintf('Dataset successfully split:\n - T1 trials: %d\n - T2 trials: %d\n', ...
    EEG_T1.trials, EEG_T2.trials);

%% Robust Loader Function (Bypasses 1.fdt naming collisions)
function EEG = safe_loadset(setFilename, folderPath)
    setFullPath = fullfile(folderPath, setFilename);
    [~, baseName, ~] = fileparts(setFilename);
    
    % 1. Read metadata structure without triggering EEGLAB path errors
    loadedData = load(setFullPath, '-mat');
    if isfield(loadedData, 'EEG')
        EEG = loadedData.EEG;
    else
        EEG = loadedData;
    end
    
    EEG.filepath = folderPath;
    EEG.filename = setFilename;
    
    % Return early if data array is already stored inside the .set file
    if isnumeric(EEG.data) && ~isempty(EEG.data)
        EEG = eeg_checkset(EEG);
        return;
    end
    
    % 2. Resolve matching .fdt binary file on disk
    targetFdt = '';
    if isfile(fullfile(folderPath, [baseName '.fdt']))
        targetFdt = fullfile(folderPath, [baseName '.fdt']);
    elseif isfield(EEG, 'datfile') && ~isempty(EEG.datfile) && isfile(fullfile(folderPath, EEG.datfile))
        targetFdt = fullfile(folderPath, EEG.datfile);
    else
        % Look for any .fdt starting with the leading prefix (e.g. 1 or Original)
        prefix = baseName(1:min(3, length(baseName)));
        fdtList = dir(fullfile(folderPath, '*.fdt'));
        for k = 1:length(fdtList)
            if startsWith(fdtList(k).name, prefix, 'IgnoreCase', true)
                targetFdt = fullfile(folderPath, fdtList(k).name);
                break;
            end
        end
        if isempty(targetFdt) && length(fdtList) == 1
            targetFdt = fullfile(folderPath, fdtList(1).name);
        end
    end
    
    if isempty(targetFdt) || ~isfile(targetFdt)
        error('Could not find corresponding .fdt file for %s in %s', setFilename, folderPath);
    end
    
    % 3. Read binary float array directly
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
    
    % Reshape array to standard EEGLAB dimensions
    if trials > 1
        EEG.data = reshape(rawFloats, [EEG.nbchan, EEG.pnts, trials]);
    else
        EEG.data = reshape(rawFloats, [EEG.nbchan, EEG.pnts]);
    end
    
    [~, fdtName, fdtExt] = fileparts(targetFdt);
    EEG.datfile = [fdtName fdtExt];
    
    EEG = eeg_checkset(EEG);
end