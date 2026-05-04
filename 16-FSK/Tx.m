% =========================================================
% ~5.7 kbps 16-FSK HAMMER (TX) — N_fft=4096
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
last_bin      = start_bin + num_lanes * bins_per_lane - 1;           % 2047

s_len        = N_fft + N_cp;
active_time  = num_symbols * s_len / Fs;
pred_kbps    = (num_lanes * bits_per_lane * num_symbols / active_time) / 1000;

fprintf('=== 16-FSK TX CONFIG ===\n');
fprintf('Lanes: %d | Bins: %d-%d | Predicted: %.1f kbps\n', ...
    num_lanes, start_bin, last_bin, pred_kbps);

t_chirp  = 0:1/Fs:0.2;
sync_sig = chirp(t_chirp, 1000, 0.2, 20000, 'logarithmic')';
guard_sil = zeros(round(Fs * 0.05), 1);

rng(42);
total_bits = num_symbols * num_lanes * bits_per_lane;
tx_bits    = randi([0 1], total_bits, 1);

tx_signal = [];
bit_ptr   = 1;
for s = 1:num_symbols
    frame_bits   = tx_bits(bit_ptr : bit_ptr + num_lanes*bits_per_lane - 1);
    bit_ptr      = bit_ptr + num_lanes*bits_per_lane;
    frame_matrix = reshape(frame_bits, bits_per_lane, num_lanes);
    lane_ints    = bit2int(frame_matrix, bits_per_lane);  % 0–15

    X = zeros(N_fft, 1);
    for b = 1:num_lanes
        bin_idx    = start_bin + (b-1)*bins_per_lane + lane_ints(b);
        X(bin_idx) = 1;
    end

    x_time = real(ifft(X, N_fft));
    x_time = x_time / (max(abs(x_time)) + 1e-9);
    cp     = x_time(end - N_cp + 1 : end);
    tx_signal = [tx_signal; cp; x_time];
end

out = [sync_sig; guard_sil; tx_signal];
out = out / (max(abs(out)) + 1e-9) * 0.30;
soundsc(out, Fs);
fprintf('Playing %.2fs | Active rate: %.1f kbps\n', length(out)/Fs, pred_kbps);