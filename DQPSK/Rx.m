% =========================================================
% ~45 kbps SIMPLE DQPSK RX 
% =========================================================
clear; clc;
Fs = 48000; N_fft = 2048; N_cp = 64; num_symbols = 250;
start_bin = 20; end_bin = 1000; num_lanes = end_bin - start_bin + 1;
s_len = N_fft + N_cp;
bits_per_lane = 2;

disp('Recording 15s... (Laptops close, volume ~40%)');
rec = audiorecorder(Fs, 16, 1); recordblocking(rec, 15);
rx_f = getaudiodata(rec);

% --- Sync ---
sync_ref = chirp(0:1/Fs:0.2, 500, 0.2, 20000)';
[c, lags] = xcorr(rx_f, sync_ref);
[~, p_idx] = max(abs(c));
p_start = lags(p_idx) + length(sync_ref) + round(Fs * 0.05);

rx_bits = [];
prev_bins = [];

% --- Decode ---
for s = 1:num_symbols
    idx = p_start + (s-1)*s_len + N_cp;
    if (idx + N_fft - 1) > length(rx_f), break; end
    
    Y = fft(rx_f(idx : idx + N_fft - 1), N_fft);
    curr_bins = Y(start_bin:end_bin);
    
    if s > 1
        % Multiply current symbol by the complex conjugate of the previous
        phase_diff = curr_bins .* conj(prev_bins);
        
        % SIMPLE MATH: 
        % Check real axis for Bit 1, check imaginary axis for Bit 2
        bit1 = real(phase_diff) < 0; 
        bit2 = imag(phase_diff) < 0;
        
        % Interleave the bits back into a single column
        decisions = zeros(num_lanes * 2, 1);
        decisions(1:2:end) = bit1;
        decisions(2:2:end) = bit2;
        
        rx_bits = [rx_bits; decisions];
    end
    
    prev_bins = curr_bins;
end

% --- Verification ---
rng(42);
total_data_bits = (num_symbols - 1) * num_lanes * bits_per_lane;
exp_bits = randi([0 1], total_data_bits, 1);
exp_bits = exp_bits(1:length(rx_bits));
errors = sum(rx_bits ~= exp_bits);
active_burst_duration = (num_symbols * s_len) / Fs;

fprintf('\n=== 45 kbps DQPSK RESULTS ===\n');
fprintf('BER: %.4f | Errors: %d\n', errors/length(rx_bits), errors);
fprintf('True Transmission Rate: %.2f kbps\n', (length(rx_bits)/active_burst_duration)/1000);