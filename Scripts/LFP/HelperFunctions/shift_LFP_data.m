function [shiftedLFP] = shift_LFP_data(lfpdata, lfpFS, shifts, shiftsFS,  xcoords, ycoords, smoothBetweenBlocks,sigmaMask)
%% Adapted from kilosort2.5 shift_batch_on_disk.m
%% by Richard Hardstone 

numChans = size(lfpdata,1);
numSamps = size(lfpdata,2);

sampsPerBlock = lfpFS / shiftsFS;  %% Make sure that realignment signal has integer multiple fs of lfp fs
numBlocks = ceil(numSamps / sampsPerBlock);
shiftedLFP = lfpdata';

xp = cat(2, xcoords, ycoords);

% 2D kernel of the original channel positions 
Kxx = kernel2D(xp, xp, sigmaMask);

smoothBetweenBlocksPlusMinus = (smoothBetweenBlocks*2) + 1;
dprev = zeros(smoothBetweenBlocksPlusMinus,numChans);

for i_block = 1:numBlocks
    fprintf('Realigning %.1f percent complete\n',100*i_block/numBlocks);
    thisShift = shifts(i_block);
    tmsStart = max((1 + (i_block-1)*sampsPerBlock) - smoothBetweenBlocks,1);
    tmsEnd =   min((i_block*sampsPerBlock)         + smoothBetweenBlocks, length(lfpdata));
    tms = tmsStart:tmsEnd;
    % 2D kernel of the new channel positions
    dat = lfpdata(:,tms)';
    
    yp = xp;
    yp(:, 2) = yp(:, 2) - thisShift; % * sig;
    Kyx = kernel2D(yp, xp, sigmaMask);

    % kernel prediction matrix
    M = Kyx /(Kxx + .01 * eye(size(Kxx,1)));
    dati = dat * M';    

    if i_block > 1 && i_block < numBlocks
        w_edge = linspace(0, 1, smoothBetweenBlocksPlusMinus)';
        dati(1:smoothBetweenBlocksPlusMinus, :) = w_edge .* dati(1:smoothBetweenBlocksPlusMinus, :) + (1 - w_edge) .* dprev;
        dprev = dati(smoothBetweenBlocks + sampsPerBlock+[-smoothBetweenBlocks:smoothBetweenBlocks], :);
    else
        if i_block == numBlocks
            w_edge = linspace(0, 1, smoothBetweenBlocksPlusMinus)';
            dati(1:smoothBetweenBlocksPlusMinus, :) = w_edge .* dati(1:smoothBetweenBlocksPlusMinus, :) + (1 - w_edge) .* dprev;
        else
            dprev = dati(sampsPerBlock+[-smoothBetweenBlocks:smoothBetweenBlocks], :);
        end
    end
    
    shiftedLFP(tms,:) = dati;
    
end
shiftedLFP = shiftedLFP';