function [snr, pn, n_ovf, err_media] = varre_dc(u_v, N, OSR, FS, ACC_MIN, ACC_MAX)
% VARRE_DC  Roda o modulador (ddsm1.m) com entrada DC constante para cada
%   codigo inteiro em u_v e mede, em cada ponto:
%     snr       : SNR na banda [dB] (snr_banda_dc.m)
%     pn        : potencia de ruido na banda, linear, relativa a FS^2
%     n_ovf     : ciclos com saturacao do acumulador
%     err_media : media da saida bipolar menos o DC de entrada
    K = numel(u_v);
    [snr, pn, n_ovf, err_media] = deal(zeros(1, K));
    for j = 1:K
        x = u_v(j) / FS;
        [y, ~, n_ovf(j)] = ddsm1(repmat(u_v(j), 1, N), FS, ACC_MIN, ACC_MAX);
        yb = 2*y - 1;
        [snr(j), pn(j)] = snr_banda_dc(yb, x, OSR);
        err_media(j) = mean(yb) - x;
    end
end
