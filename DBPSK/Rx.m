% =========================================================
% 51 kbps D8PSK-OFDM RX 
% =========================================================
clear; clc;
Fs = 48000; N_fft = 4096; N_cp = 128; num_symbols = 160;
start_bin = 40; num_lanes = 1500; end_bin = start_bin + num_lanes - 1;
bits_per_lane = 3;
s_len = N_fft + N_cp;

disp('Recording 15s... (Laptops inches apart, absolute silence)');
rec = audiorecorder(Fs, 16, 1); recordblocking(rec, 15);
rx_f = getaudiodata(rec);

% --- Sync ---
sync_ref = chirp(0:1/Fs:0.2, 500, 0.2, 15000)';
[c, lags] = xcorr(rx_f, sync_ref);
[~, p_idx] = max(abs(c));
p_start = lags(p_idx) + length(sync_ref) + round(Fs * 0.05);

rx_ints_all = [];
prev_bins = [];

% --- Decode ---
for s = 1:num_symbols
    idx = p_start + (s-1)*s_len + N_cp;
    if (idx + N_fft - 1) > length(rx_f), break; end
    
    Y = fft(rx_f(idx : idx + N_fft - 1), N_fft);
    curr_bins = Y(start_bin:end_bin);
    
    if s > 1
        % Multiply current by conjugate of previous to find the phase difference
        phase_diff = curr_bins .* conj(prev_bins);
        angles = angle(phase_diff); % Extract the raw angle (-pi to pi)
        
        % Map the raw angle to the nearest 45-degree (pi/4) slice
        shifted_angles = mod(angles + pi/8, 2*pi); 
        decisions = floor(shifted_angles / (pi/4));
        decisions(decisions == 8) = 0; % Safety catch
        
        rx_ints_all = [rx_ints_all; decisions(:)];
    end
    
    prev_bins = curr_bins;
end

% --- Verification ---
rx_bits = int2bit(rx_ints_all', bits_per_lane);
rx_bits = rx_bits(:); % Flatten to column

rng(42);
total_data_bits = (num_symbols - 1) * num_lanes * bits_per_lane;
exp_bits = randi([0 1], total_data_bits, 1);
exp_bits = exp_bits(1:length(rx_bits));

errors = sum(rx_bits ~= exp_bits);
active_burst_duration = (num_symbols * s_len) / Fs;

fprintf('\n=== 51 kbps D8PSK RESULTS ===\n');
fprintf('BER: %.4f | Errors: %d\n', errors/length(rx_bits), errors);
fprintf('True Transmission Rate: %.2f kbps\n', (length(rx_bits)/active_burst_duration)/1000);