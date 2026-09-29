function [SNR_dB, Pn] = snr_banda_dc(y_bip, x, OSR)
% SNR_BANDA_DC  SNR na banda para entrada DC (sem tom de entrada).
%   [SNR_dB, Pn] = snr_banda_dc(y_bip, x, OSR)
%   y_bip : saida mapeada para {-1,+1}
%   x     : valor DC da entrada, em fracao do fundo de escala (u/FS)
%   Pn    : potencia de ruido na banda, linear, relativa a FS^2 (DC = 1 -> 0 dB)
%
%   Por que nao reusar snr_banda.m: ela mede o sinal nos bins do tom (K+/-3)
%   e tira o bin 0 da banda. Com DC o sinal E o bin 0, e um tom idle mais
%   lento que a janela aparece justamente como erro de media ali.
%
%   Aqui:
%     sinal = a propria entrada, conhecida: potencia x^2
%     ruido = potencia de e = y_bip - x na banda [0, fs/(2 OSR)), INCLUINDO o
%             bin 0 (erro de media e ruido na banda)
%   Janela Hann normalizada por N*sum(w.^2) e soma bilateral: um DC de valor c
%   soma exatamente c^2 e um seno de amplitude A soma A^2/2, entao a escala e
%   a mesma da senoide. Bins da banda: os mesmos de snr_banda.m, mais o bin 0.
    N  = numel(y_bip);
    w  = hann(N).';
    E  = abs(fft((y_bip - x) .* w)).^2 / (N * sum(w.^2));
    Nb = floor(N/(2*OSR));
    Pn = E(1) + 2*sum(E(2:Nb));
    SNR_dB = 10*log10(x^2 / Pn);
end
