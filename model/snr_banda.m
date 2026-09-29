function SNR_dB = snr_banda(y_bip, N, K, OSR)
% SNR_BANDA  SNR na banda util para entrada SENOIDAL, com janela Hann e
%   exclusao dos bins do tom (K+1 +/- 3). Nao serve para entrada DC: o sinal
%   estaria no bin 0, que fica fora da banda somada aqui. Para DC, use
%   snr_banda_dc.m.
    P = abs(fft(y_bip .* hann(N).')).^2; P = P(1:N/2);
    bin_banda = 2 : floor(N/(2*OSR));
    bin_tom   = (K+1) + (-3:3);
    Psig   = sum(P(bin_tom));
    Pruido = sum(P(bin_banda)) - sum(P(intersect(bin_tom, bin_banda)));
    SNR_dB = 10*log10(Psig / Pruido);
end
