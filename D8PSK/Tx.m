% =========================================================
% ~21 kbps DBPSK-OFDM TX (Phase-Differential)
% =========================================================
clear; clc;
Fs = 48000; N_fft = 4096; N_cp = 32; num_symbols = 160;
start_bin = 40; % ~470 Hz
end_bin = 2000; % ~23.4 kHz
num_lanes = end_bin - start_bin + 1; % 1961 lanes

% We lose 1 symbol because the first symbol is just a "reference" phase
total_data_bits = (num_symbols - 1) * num_lanes; 
rng(42);
tx_bits = randi([0 1], total_data_bits, 1);
tx_reshaped = reshape(tx_bits, num_lanes, num_symbols - 1);

tx_signal = [];
current_phase = ones(num_lanes, 1); % Initial reference phase (all 1s)

for s = 1:num_symbols
    X = zeros(N_fft, 1);
    
    if s > 1
        % Grab data bits for this symbol
        bits = tx_reshaped(:, s-1);
        
        % DBPSK Logic: 
        % If bit is 0 -> multiply by 1 (no change)
        % If bit is 1 -> multiply by -1 (180 degree flip)
        phase_multiplier = 1 - 2*bits; 
        current_phase = current_phase .* phase_multiplier;
    end
    
    X(start_bin:end_bin) = current_phase;
    X(N_fft/2+2:end) = conj(flipud(X(2:N_fft/2))); % Hermitian symmetry
    
    x_t = real(ifft(X, N_fft));
    x_t = x_t / (max(abs(x_t)) + 1e-9); % Prevent clipping
    tx_signal = [tx_signal; x_t(end-N_cp+1:end); x_t];
end

sync = [chirp(0:1/Fs:0.2, 500, 0.2, 20000)'; zeros(Fs*0.05, 1)];
out = [sync; tx_signal * 0.3]; % 30% volume is perfect here
soundsc(out, Fs);

burst_time = (num_symbols * (N_fft + N_cp)) / Fs;
fprintf('True Predicted Rate: %.2f kbps\n', (total_data_bits/burst_time)/1000);