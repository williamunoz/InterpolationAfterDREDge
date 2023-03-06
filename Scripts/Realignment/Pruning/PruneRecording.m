function PruneRecording(recordingParams)

if ~exist(recordingParams.outputDirectory,'dir')
    mkdir(recordingParams.outputDirectory);
end

stable_time = recordingParams.stable_time;
stable_channels = recordingParams.channels+1;

if recordingParams.hasTriggerChannel
    num_of_raw_channels = 385;
else
    num_of_raw_channels = 384;
end

% Load memmap:
temp = memmapfile(recordingParams.raw_fname,'Format', 'int16');
data_memmap = memmapfile(recordingParams.raw_fname,'Format', {'int16', [num_of_raw_channels, length(temp.Data)/num_of_raw_channels], 'data'});

% Compute global timing
data_timestamp = [1:size(data_memmap.Data.data,2)]./recordingParams.sampfreq; %% 

samples_data = find(data_timestamp>=stable_time(1) & data_timestamp<=stable_time(2));

outDat = fullfile(recordingParams.outputDirectory,recordingParams.outfname);
fid_target = fopen(outDat,'w');
fwrite(fid_target, data_memmap.Data.data(stable_channels,samples_data), 'int16');
fclose(fid_target)
