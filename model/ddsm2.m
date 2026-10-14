function [y, ex, al] = ddsm2(u, P)
% DDSM2  Modulador de 2a ordem (CIFB, Boser-Wooley), aritmetica inteira.
%   [y, ex, al] = ddsm2(u, P)
%   u  : entrada em LSBs (inteiros com sinal)
%   P  : le_params('ddsm2') -- coeficientes e larguras PROVISORIAS
%   y  : saida em {0,1}, o registro de saida a cada ciclo
%   ex : excursao de cada integrador: ex.w1 = [min max], ex.w2 = [min max]
%   al : ALARME de estouro das larguras provisorias:
%        al.n1, al.n2 = ciclos com w1/w2 fora de [-2^(W-1), 2^(W-1)-1]
%        al.primeiro  = primeira amostra em alarme (0 = nenhum)
%
%   SEM SATURACAO: os integradores evoluem livremente (double e exato ate
%   2^53). O alarme so conta; nao corrige. Um alarme significa que o laco
%   saiu da faixa provisoria -- resultado a reportar, nao a contornar.
%
%   Unica implementacao do laco de 2a ordem em ponto fixo. Mesma convencao
%   de registro da 1a ordem (ddsm1.m / rtl/ddsm1.v):
%     fb  = +FS se y_r = 1, -FS se y_r = 0
%     w1 <- w1 + B1 u  - A1 fb
%     w2 <- w2 + C1 w1 - A2 fb      (w1 ANTES da atualizacao)
%     y_r <- (w2 >= 0)              (w2 DEPOIS da atualizacao)
%   Reset: w1 = w2 = 0, y_r = 0.

    FS   = 2^(P.W_IN - 1);
    lim1 = 2^(P.W_I1 - 1);
    lim2 = 2^(P.W_I2 - 1);

    N  = numel(u);
    y  = zeros(1, N);
    w1 = 0; w2 = 0; yr = 0;
    ex.w1 = [0 0]; ex.w2 = [0 0];
    al.n1 = 0; al.n2 = 0; al.primeiro = 0;

    for i = 1:N
        if yr, fb = FS; else, fb = -FS; end
        w1n = w1 + P.B1*u(i) - P.A1*fb;
        w2  = w2 + P.C1*w1   - P.A2*fb;
        w1  = w1n;
        yr  = double(w2 >= 0);
        y(i) = yr;

        ex.w1 = [min(ex.w1(1), w1), max(ex.w1(2), w1)];
        ex.w2 = [min(ex.w2(1), w2), max(ex.w2(2), w2)];
        f1 = (w1 < -lim1) || (w1 > lim1 - 1);
        f2 = (w2 < -lim2) || (w2 > lim2 - 1);
        if f1 || f2
            al.n1 = al.n1 + f1; al.n2 = al.n2 + f2;
            if al.primeiro == 0, al.primeiro = i; end
        end
    end
end
