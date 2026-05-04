% =========================================================
% ~5.7 kbps 16-FSK HAMMER (RX) — N_fft=4096, Hann windowed
% =========================================================
clear; clc;

Fs            = 48000;
N_fft         = 4096;
N_cp          = 32;
num_symbols   = 160;
start_bin     = 80;
bins_per_lane = 16;
bits_per_lane = 4;

max_safe_bin  = floor(N_fft / 2);
num_lanes     = floor((max_safe_bin - start_bin) / bins_per_lane);  % 123
last_bin      = start_bin + num_lanes * bins_per_lane - 1;

s_len        = N_fft + N_cp;
active_time  = num_symbols * s_len / Fs;
pred_kbps    = (num_lanes * bits_per_lane * num_symbols / active_time) / 1000;

fprintf('Lanes: %d | Bins: %d-%d | Predicted: %.1f kbps\n', ...
    num_lanes, start_bin, last_bin, pred_kbps);

% Hann window — computed once, reused every symbol
hann_win = hann(N_fft, 'periodic');

record_secs = ceil(active_time + 0.5) + 3;
fprintf('Recording %ds...\n', record_secs);
rec = audiorecorder(Fs, 16, 1);
recordblocking(rec, record_secs);
rx_f = getaudiodata(rec);

% --- 1. Sync ---
sync_ref = chirp(0:1/Fs:0.2, 1000, 0.2, 20000, 'logarithmic')';
[c, lags] = xcorr(rx_f, sync_ref);
[~, p_idx] = max(abs(c));
p_start = lags(p_idx) + length(sync_ref) + round(Fs * 0.05);
if p_start < 1 || (p_start + num_symbols * s_len) > length(rx_f)
    error('Sync failed. Check mic and volume (~30%%).');
end

% --- 2. 16-FSK Demodulate ---
rx_bits = [];
for s = 1:num_symbols
    idx = p_start + (s-1)*s_len + N_cp;   % integer skip, no rounding
    if (idx + N_fft - 1) > length(rx_f), break; end

    segment = rx_f(idx : idx + N_fft - 1) .* hann_win;
    Y = abs(fft(segment, N_fft));

    rx_ints_col = zeros(num_lanes, 1);
    for b = 1:num_lanes
        block_start  = start_bin + (b-1)*bins_per_lane;
        block_end    = block_start + bins_per_lane - 1;  % always ≤ 2047
        block_energy = Y(block_start : block_end);
        [~, max_idx] = max(block_energy);
        rx_ints_col(b) = max_idx - 1;  % 0–15
    end

    bit_matrix = int2bit(rx_ints_col, bits_per_lane);
    rx_bits    = [rx_bits; bit_matrix(:)];
end

% --- 3. Results ---
rng(42);
total_bits   = num_symbols * num_lanes * bits_per_lane;
exp_bits_all = randi([0 1], total_bits, 1);
exp_bits     = exp_bits_all(1:length(rx_bits));
errors       = sum(rx_bits ~= exp_bits);
BER          = errors / length(rx_bits);

fprintf('\n=== 16-FSK HAMMER RESULTS ===\n');
fprintf('Lanes: %d | Bits: %d\n', num_lanes, length(rx_bits));
fprintf('BER: %.4f | Errors: %d\n', BER, errors);
fprintf('Active rate: %.2f kbps\n', (length(rx_bits) / active_time) / 1000);
if BER < 0.05,  disp('EXCELLENT: Sub-5% BER at 57 kbps.'); end
if BER < 0.10,  disp('GOOD: Sub-10% BER. Try bumping volume to 35%.'); end
if BER >= 0.10, disp('TIP: Increase TX volume or reduce num_lanes by 20.'); end
