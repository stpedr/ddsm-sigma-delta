function [y, acc_max_abs, n_ovf] = ddsm1(u, FS, ACC_MIN, ACC_MAX)
% DDSM1  Modulador de 1a ordem, aritmetica inteira, identico ao que o RTL faz.
%   u   : vetor de entrada em LSBs (inteiros com sinal)
%   y   : saida em {0,1}, como o pino do chip
%
%   Unica implementacao do laco no projeto: ddsm1_fixo.m, figuras_validacao.m
%   e as varreduras chamam esta funcao. Nao copie o laco para outro script.
    N = numel(u);
    y = zeros(1,N);
    acc = 0;
    yfb = -FS;              % realimentacao inicial (reset com saida em 0)
    acc_max_abs = 0;
    n_ovf = 0;

    for i = 1:N
        acc_ext = acc + (u(i) - yfb);      % soma na largura estendida

        if acc_ext > ACC_MAX               % SATURACAO, nunca wrap-around:
            acc = ACC_MAX; n_ovf = n_ovf + 1;   % wrap destruiria a NTF de
        elseif acc_ext < ACC_MIN           % forma silenciosa
            acc = ACC_MIN; n_ovf = n_ovf + 1;
        else
            acc = acc_ext;
        end

        y(i) = double(acc >= 0);           % quantizador = bit de sinal invertido
        if y(i) == 1, yfb = FS; else, yfb = -FS; end

        acc_max_abs = max(acc_max_abs, abs(acc));
    end
end
