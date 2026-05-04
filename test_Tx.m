% =========================================================
% STANDARD OFDM TX (Intentional Baseline for Report)
% =========================================================
clear; clc;
Fs = 48000; N_fft = 2048; N_cp = 128; num_symbols = 100;
start_bin = 20; end_bin = 800; num_lanes = end_bin - start_bin + 1;
bits_per_sym = 2; % QPSK

total_data_bits = (num_symbols - 1) * num_lanes * bits_per_sym;
rng(42);
tx_bits = randi([0 1], total_data_bits, 1);

% Map bits to QPSK
tx_ints = bit2int(reshape(tx_bits, bits_per_sym, []), bits_per_sym); 
qpsk_data = exp(1j * (pi/4 + (tx_ints * pi/2))); 
tx_reshaped = reshape(qpsk_data, num_lanes, num_symbols - 1);

% Known Training Symbol (for standard channel estimation)
training_sym = exp(1j * (pi/4 + (randi([0 3], num_lanes, 1) * pi/2)));

tx_signal = [];
for s = 1:num_symbols
    X = zeros(N_fft, 1);
    if s == 1
        X(start_bin:end_bin) = training_sym; % Send Training
    else
        X(start_bin:end_bin) = tx_reshaped(:, s-1); % Send Data
    end
    X(N_fft/2+2:end) = conj(flipud(X(2:N_fft/2))); 
    
    x_t = real(ifft(X, N_fft));
    x_t = x_t / (max(abs(x_t)) + 1e-9); 
    tx_signal = [tx_signal; x_t(end-N_cp+1:end); x_t];
end

sync = [chirp(0:1/Fs:0.2, 500, 0.2, 18000)'; zeros(Fs*0.05, 1)];
out = [sync; tx_signal * 0.4]; 
disp('Playing Standard OFDM...');
soundsc(out, Fs);