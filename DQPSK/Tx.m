% =========================================================
% ~45 kbps SIMPLE DQPSK TX (2 bits per bin)
% =========================================================
clear; clc;
Fs = 48000; N_fft = 2048; N_cp = 32; num_symbols = 250;
start_bin = 20; end_bin = 1000; num_lanes = end_bin - start_bin + 1;
bits_per_lane = 2; 

total_data_bits = (num_symbols - 1) * num_lanes * bits_per_lane; 
rng(42);
tx_bits = randi([0 1], total_data_bits, 1);

% Separate bits into "Real" bits and "Imaginary" bits
tx_reshaped = reshape(tx_bits, 2, num_lanes, num_symbols - 1);

tx_signal = [];
current_phase = ones(num_lanes, 1); 

for s = 1:num_symbols
    X = zeros(N_fft, 1);
    
    if s > 1
        % Grab the two bits for this symbol
        bit1 = squeeze(tx_reshaped(1, :, s-1)).';
        bit2 = squeeze(tx_reshaped(2, :, s-1)).';
        
        % Convert 0/1 bits into +1/-1 phase shifts
        real_part = 1 - 2*bit1; 
        imag_part = 1 - 2*bit2; 
        
        % Shift the phase for both bits simultaneously
        phase_shift = (real_part + 1j*imag_part) / sqrt(2);
        current_phase = current_phase .* phase_shift;
    end
    
    X(start_bin:end_bin) = current_phase;
    X(N_fft/2+2:end) = conj(flipud(X(2:N_fft/2))); 
    
    x_t = real(ifft(X, N_fft));
    x_t = x_t / (max(abs(x_t)) + 1e-9); 
    tx_signal = [tx_signal; x_t(end-N_cp+1:end); x_t];
end

sync = [chirp(0:1/Fs:0.2, 500, 0.2, 20000)'; zeros(Fs*0.05, 1)];
out = [sync; tx_signal * 0.4]; 
soundsc(out, Fs);

burst_time = (num_symbols * (N_fft + N_cp)) / Fs;
fprintf('True Transmission Rate: %.2f kbps\n', (total_data_bits/burst_time)/1000);