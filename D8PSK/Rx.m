% =========================================================
% ~21 kbps DBPSK-OFDM RX 
% =========================================================
clear; clc;
Fs = 48000; N_fft = 4096; N_cp = 256; num_symbols = 160;
start_bin = 40; end_bin = 2000; num_lanes = end_bin - start_bin + 1;
s_len = N_fft + N_cp;

disp('Recording 15s... (Laptops close, volume ~30%)');
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
        % DIFFERENTIAL MATH:
        % Multiply current symbol by the complex conjugate of the previous.
        % If the phase flipped 180 degrees, the real part will be negative.
        phase_diff = curr_bins .* conj(prev_bins);
        
        decisions = real(phase_diff) < 0; % Negative = '1', Positive = '0'
        rx_bits = [rx_bits; decisions(:)];
    end
    
    prev_bins = curr_bins; % Save current as reference for the next symbol
end

% --- Verification ---
rng(42);
total_data_bits = (num_symbols - 1) * num_lanes;
exp_bits = randi([0 1], total_data_bits, 1);a
exp_bits = exp_bits(1:length(rx_bits));

errors = sum(rx_bits ~= exp_bits);
active_burst_duration = (num_symbols * s_len) / Fs;

fprintf('\n=== 21 kbps DBPSK RESULTS ===\n');
fprintf('BER: %.4f | Errors: %d\n', errors/length(rx_bits), errors);
fprintf('True Transmission Rate: %.2f kbps\n', (length(rx_bits)/active_burst_duration)/1000);