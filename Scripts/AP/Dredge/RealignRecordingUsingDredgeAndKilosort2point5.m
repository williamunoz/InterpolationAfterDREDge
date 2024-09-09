function RealignRecordingUsingDredgeAndKilosort2point5(basepath,config_version,dredgeParams)
cd(basepath)

%% Config File
disp(['Running Kilosort with user specific settings ' config_version]);
config_string = str2func(['Kilosort25Configuration_' config_version]);
ops = config_string(dredgeParams);

%% GPU
gpuDeviceNum = 1;
disp(['Initializing GPU: ' num2str(gpuDeviceNum)])
gpuDevice(gpuDeviceNum); % initialize GPU (will erase any existing GPU arrays)

%% Preprocess Data
rez = preprocessDataSub(ops);

%% Realign RAW file using dredge 
applyDredge(rez); % last input is for shifting data

%% Delete temporary PreprocessedData.dat
delete('PreprocessedData.dat')
