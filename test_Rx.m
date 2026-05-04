% =========================================================
% REPORT PART 2: STANDARD OFDM RX & ERROR PLOTS
% =========================================================
clear; clc;
Fs = 48000; N_fft = 2048; N_cp = 128; num_symbols = 100;
start_bin = 20; end_bin = 800; num_lanes = end_bin - start_bin + 1;
s_len = N_fft + N_cp;
bits_per_sym = 2;

disp('Recording Standard OFDM...');
rec = audiorecorder(Fs, 16, 1); recordblocking(rec, 10);
rx_f = getaudiodata(rec);

sync_ref = chirp(0:1/Fs:0.2, 500, 0.2, 18000)';
[c, lags] = xcorr(rx_f, sync_ref);
[~, p_idx] = max(abs(c));
p_start = lags(p_idx) + length(sync_ref) + round(Fs * 0.05);

rx_bits = [];
raw_constellation = [];
H_est = zeros(num_lanes, 1);

% Recreate the known training symbol
rng(42);
training_sym = exp(1j * (pi/4 + (randi([0 3], num_lanes, 1) * pi/2)));

for s = 1:num_symbols
    idx = p_start + (s-1)*s_len + N_cp;
    if (idx + N_fft - 1) > length(rx_f), break; end
    
    Y = fft(rx_f(idx : idx + N_fft - 1), N_fft);
    curr_bins = Y(start_bin:end_bin);
    
    if s == 1
        % STANDARD OFDM: Estimate channel ONLY on the first symbol
        H_est = curr_bins ./ training_sym;
    else
        % Equalize using the static channel estimate
        rx_data_eq = curr_bins ./ (H_est + 1e-6);
        raw_constellation = [raw_constellation; rx_data_eq];
        
        % QPSK Demod
        angles = angle(rx_data_eq); 
        shifted_angles = mod(angles + pi/4, 2*pi); 
        decisions = floor(shifted_angles / (pi/2));
        decisions(decisions == 4) = 0; 
        
        rx_bits = [rx_bits; reshape(int2bit(decisions(:)', 2), [], 1)];
    end
end

% Verify Errors
total_data_bits = (num_symbols - 1) * num_lanes * bits_per_sym;
exp_bits = randi([0 1], total_data_bits, 1);
exp_bits = exp_bits(1:length(rx_bits));
errors = sum(rx_bits ~= exp_bits);

fprintf('\n=== STANDARD OFDM RESULTS ===\n');
fprintf('BER: %.4f (Expected Failure)\n', errors/length(rx_bits));

% =========================================================
% REPORT FIGURES: WHY IT FAILED
% =========================================================

% --- FIGURE 2: The Constellation Smear (Clock Drift) ---
figure('Name', 'Standard OFDM Constellation', 'Color', 'w', 'Position', [100 100 500 500]);
scatter(real(raw_constellation), imag(raw_constellation), 5, 'b', 'filled', 'MarkerFaceAlpha', 0.1);
hold on; 
plot([-3 3], [0 0], 'k--'); plot([0 0], [-3 3], 'k--');
title('Standard OFDM Constellation (Failure)');
xlabel('In-Phase (Real)'); ylabel('Quadrature (Imaginary)');
axis square; grid on;
xlim([-3 3]); ylim([-3 3]);

% --- FIGURE 3: Error vs Frequency (The Black Hole) ---
rx_reshaped_bits = reshape(rx_bits, bits_per_sym, num_lanes, []);
exp_reshaped_bits = reshape(exp_bits, bits_per_sym, num_lanes, []);
errors_per_lane = squeeze(sum(sum(rx_reshaped_bits ~= exp_reshaped_bits, 1), 3));
frequencies = (start_bin : end_bin) * (Fs / N_fft);

figure('Name', 'Errors vs Frequency', 'Color', 'w', 'Position', [650 100 600 400]);
bar(frequencies, errors_per_lane, 'FaceColor', [0.8500 0.3250 0.0980]);
title('Bit Errors Distributed Across Acoustic Spectrum');
xlabel('Acoustic Frequency (Hz)');
ylabel('Total Bit Errors');
grid on;