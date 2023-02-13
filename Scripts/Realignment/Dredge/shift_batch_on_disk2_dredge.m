function [dprev, dat_cpu, dat, shifts] = ...
    shift_batch_on_disk2_dredge(rez, ibatch, shifts, ysamp, sig, dprev)

%% Adapted from Kilosort2.5 function shift_batch_on_disk2.m
%% by Richard Hardstone (2022_11_30)

% register one batch of a whitened binary file

ops = rez.ops;
Nbatch      = rez.temp.Nbatch;
NT  	      = ops.NT;

batchstart = 0:NT:NT*Nbatch; % batches start at these timepoints
offset = 2 * ops.Nchan*batchstart(ibatch); % binary file offset in bytes

% upsample the shift for each channel using interpolation
if length(ysamp)>1
    shifts = interp1(ysamp, shifts, rez.yc, 'makima', 'extrap');
end
% load the batch
fclose all;
ntb = ops.ntbuff;

newFile = rez.ops.dredge.outDat;


fid = fopen(newFile, 'r+');
fseek(fid, offset, 'bof');

if ibatch == Nbatch
    dat = zeros( NT+ntb,ops.Nchan,'int16');
    counter = 1;
    while ~feof(fid)
        tmpdat = fread(fid, [ops.Nchan 1], '*int16')';
        if ~feof(fid)
            dat(counter,:) = tmpdat;
            counter = counter + 1;
        end
    end
else
    dat = fread(fid, [ops.Nchan NT+ntb], '*int16')';
end

% 2D coordinates for interpolation 
xp = cat(2, rez.xc, rez.yc);

% 2D kernel of the original channel positions 
Kxx = kernel2D(xp, xp, sig);
% 2D kernel of the new channel positions
yp = xp;
yp(:, 2) = yp(:, 2) - shifts; % * sig;
Kyx = kernel2D(yp, xp, sig);

% kernel prediction matrix
M = Kyx /(Kxx + .01 * eye(size(Kxx,1)));

% the multiplication has to be done on the GPU
dati = gpuArray(single(dat)) * gpuArray(M)';

w_edge = linspace(0, 1, ntb)';
dati(1:ntb, :) = w_edge .* dati(1:ntb, :) + (1 - w_edge) .* dprev;

if size(dati,1)==NT+ntb
    dprev = dati(NT+[1:ntb], :);
else
    dprev(:) = 0;
    tmp = dati(NT+1:end, :);
    dprev(1:size(tmp,1),:) = tmp;
end
dati = dati(1:NT, :);

dat_cpu = gather(int16(dati));


% we want to write the aligned data back to the same file
fseek(fid, offset, 'bof');
fwrite(fid, dat_cpu', 'int16'); % write this batch to binary file

fclose(fid);

