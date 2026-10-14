function y = ddsm2_flut(x)
% DDSM2_FLUT  Modulador de 2a ordem em PONTO FLUTUANTE, forma de Boser-Wooley.
%   y = ddsm2_flut(x),  x: entrada normalizada (fracao de FS),  y em {0,1}.
%
%   Laco com os ganhos 0,5 da literatura (docs/ddsm2-cifb.md):
%     v1 <- v1 + 0,5 (x  - yb)
%     v2 <- v2 + 0,5 (v1 - yb)      (v1 ANTES da atualizacao)
%     y_r <- (v2 >= 0)              (v2 DEPOIS da atualizacao)
%   com yb = +1 se y_r = 1, -1 se y_r = 0; reset v1 = v2 = 0, y_r = 0.
%
%   Mesma convencao de registro de ddsm2.m, mas com os ganhos 0,5 em vez da
%   forma inteira. Serve de referencia independente: com x = u/FS, as
%   decisoes devem ser identicas as de ddsm2.m (a forma inteira e
%   w1 = 2 FS v1, w2 = 4 FS v2, e sgn nao muda com escala positiva).
    N  = numel(x);
    y  = zeros(1, N);
    v1 = 0; v2 = 0; yr = 0;
    for i = 1:N
        if yr, yb = 1; else, yb = -1; end
        v1n = v1 + 0.5*(x(i) - yb);
        v2  = v2 + 0.5*(v1 - yb);
        v1  = v1n;
        yr  = double(v2 >= 0);
        y(i) = yr;
    end
end
