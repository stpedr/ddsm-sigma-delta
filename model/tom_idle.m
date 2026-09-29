function f = tom_idle(y_bip, x)
% TOM_IDLE  Frequencia do tom idle de baixa frequencia com entrada DC.
%   f = tom_idle(y_bip, x) devolve, em fracao de fs, a raia MAIS BAIXA do
%   espectro de e = y_bip - x cuja potencia fica a ate 3 dB da maior raia
%   em 0 < f < fs/16. NaN se nao houver raia acima de 1e-12 (FS^2).
%
%   Por que nao o argmax puro: perto de x = p/q as raias do batimento estao
%   em m*P*eps/2 (m = 1, 2, 3...) e tem amplitudes quase iguais (~eps/2
%   cada), entao o argmax salta entre harmonicas. A fundamental e a que
%   define onde o plato termina. O limite fs/16 exclui as raias do proprio
%   ciclo-limite (em multiplos de 1/P, com P <= 8 nos centros estudados).
    N  = numel(y_bip);
    w  = hann(N).';
    E  = abs(fft((y_bip - x) .* w)).^2 / (N * sum(w.^2));
    k  = 2 : floor(N/16);                     % bins 1 .. N/16-1 (sem o bin 0)
    Ek = E(k);
    pico = [false, Ek(2:end-1) > Ek(1:end-2) & Ek(2:end-1) >= Ek(3:end), false];
    Emax = max(Ek(pico));
    if isempty(Emax) || Emax < 1e-12
        f = NaN;
        return;
    end
    i = find(pico & Ek >= Emax/2, 1, 'first');   % ate 3 dB abaixo do maximo
    f = (k(i) - 1) / N;
end
