% =========================================================
% 51 kbps D8PSK-OFDM TX (3 bits per lane)
% =========================================================
clear; clc;
Fs = 48000; N_fft = 4096; N_cp = 128; num_symbols = 160;

start_bin = 40;   % ~470 Hz
num_lanes = 1500; % Ends at ~18 kHz (avoids the worst of the black hole)
end_bin = start_bin + num_lanes - 1; 
bits_per_lane = 3; % D8PSK packs 3 bits per bin!

% Calculate true data bits (first symbol is a phase reference, no data)
total_data_bits = (num_symbols - 1) * num_lanes * bits_per_lane; 

rng(42);
tx_bits = randi([0 1], total_data_bits, 1);

% Convert bits to integers (0 through 7)
tx_matrix = reshape(tx_bits, bits_per_lane, []);
tx_ints = bit2int(tx_matrix, bits_per_lane); 
tx_reshaped = reshape(tx_ints, num_lanes, num_symbols - 1);

tx_signal = [];
current_phase = ones(num_lanes, 1); % Reference phase

for s = 1:num_symbols
    X = zeros(N_fft, 1);
    
    if s > 1
        % D8PSK: Rotate the phase by exactly (Integer * 45 degrees)
        phase_shift = exp(1j * (pi/4) * tx_reshaped(:, s-1));
        current_phase = current_phase .* phase_shift;
    end
    
    X(start_bin:end_bin) = current_phase;
    X(N_fft/2+2:end) = conj(flipud(X(2:N_fft/2))); % Real audio symmetry
    
    x_t = real(ifft(X, N_fft));
    x_t = x_t / (max(abs(x_t)) + 1e-9); % Prevent clipping
    tx_signal = [tx_signal; x_t(end-N_cp+1:end); x_t];
end

sync = [chirp(0:1/Fs:0.2, 500, 0.2, 15000)'; zeros(Fs*0.05, 1)];
out = [sync; tx_signal * 0.35]; % 35% volume
soundsc(out, Fs);

burst_time = (num_symbols * (N_fft + N_cp)) / Fs;
fprintf('True Predicted Rate: %.2f kbps\n', (total_data_bits/burst_time)/1000);