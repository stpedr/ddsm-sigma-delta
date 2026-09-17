%% ddsm1_snr.m
%  Modulador sigma-delta digital de 1a ordem (DDSM) + medida de SNR na banda.
%  Golden model de referencia para o RTL. Saida em +/-1 (equivalente a 1 bit).
%
%  Uso: rode como esta. Depois varie OSR e A e observe a inclinacao de 9 dB/oitava.

clear; clc; close all;

%% ---------------------------------------------------------------
%  1. PARAMETROS
%  ---------------------------------------------------------------
N   = 2^16;   % numero de amostras. Potencia de 2 -> FFT rapida.
OSR = 64;     % oversampling ratio. Banda util = fs/(2*OSR).
A   = 0.5;    % amplitude do tom, em fracao do fundo de escala (|u| < 1).
K   = 41;     % ciclos completos do tom dentro da janela de N amostras.
              % DEVE ser inteiro (amostragem coerente) e de preferencia
              % primo, para o tom nao cair em harmonicos do proprio grid.

%% ---------------------------------------------------------------
%  2. ESTIMULO
%  ---------------------------------------------------------------
n = 0:N-1;
u = A * sin(2*pi*K*n/N);   % K ciclos exatos em N amostras -> sem vazamento

%% ---------------------------------------------------------------
%  3. MODULADOR DE 1a ORDEM
%  ---------------------------------------------------------------
%  acc  : estado do integrador (o acumulador do RTL)
%  yprev: saida do ciclo anterior, realimentada
%
%  A cada passo o integrador acumula o erro (entrada - saida anterior).
%  Como o ganho do integrador e infinito em DC, o valor medio da saida
%  e forcado a seguir o valor medio da entrada: erro estacionario nulo.

y     = zeros(1,N);
acc   = 0;
yprev = 0;
accmax = 0;   % monitor de excursao do acumulador (util para dimensionar bits)

for i = 1:N
    acc = acc + (u(i) - yprev);      % integra o erro

    if acc >= 0                       % quantizador de 1 bit = teste de sinal
        y(i) = 1;
    else
        y(i) = -1;
    end

    yprev  = y(i);                    % realimentacao exata (um fio, no RTL)
    accmax = max(accmax, abs(acc));
end

%% ---------------------------------------------------------------
%  4. ESPECTRO
%  ---------------------------------------------------------------
w = hann(N).';                 % janela Hann: reduz vazamento residual
Y = fft(y .* w);
P = abs(Y(1:N/2)).^2;          % densidade de potencia, metade positiva

%% ---------------------------------------------------------------
%  5. SNR NA BANDA
%  ---------------------------------------------------------------
%  Banda util vai do bin 2 (pula o DC) ate N/(2*OSR).
%  Os bins do tom sao excluidos do ruido. A janela Hann espalha a energia
%  do tom por ~3 bins de cada lado, por isso a margem de +/-3.

bin_banda = 2 : floor(N/(2*OSR));
bin_tom   = (K+1) + (-3:3);          % +1 porque MATLAB indexa a partir de 1

Psig = sum(P(bin_tom));
Pruido = sum(P(bin_banda)) - sum(P(intersect(bin_tom, bin_banda)));

SNR_dB = 10*log10(Psig / Pruido);

fprintf('OSR = %d | A = %.2f | SNR na banda = %.1f dB\n', OSR, A, SNR_dB);
fprintf('Excursao maxima do acumulador = %.3f\n', accmax);
fprintf('Media da saida = %.4f (esperado ~0 para entrada senoidal)\n', mean(y));

%% ---------------------------------------------------------------
%  6. GRAFICO
%  ---------------------------------------------------------------
%  O que voce quer ver: piso de ruido SUBINDO com a frequencia, a 20 dB/decada.
%  Piso plano = realimentacao quebrada (o bloco virou um truncador simples).

f = (0:N/2-1)/N;                       % frequencia normalizada (fs = 1)
PdB = 10*log10(P / max(P));

figure;
semilogx(f(2:end), PdB(2:end)); grid on; hold on;
xline(1/(2*OSR), '--', 'borda da banda');
xlabel('frequencia normalizada (f/fs)');
ylabel('PSD normalizada [dB]');
title(sprintf('DDSM 1a ordem - OSR=%d - SNR=%.1f dB', OSR, SNR_dB));

%% ---------------------------------------------------------------
%  7. VARREDURA DE OSR  (descomente para rodar)
%  ---------------------------------------------------------------
%  Este e o teste que realmente valida o noise shaping.
%  Criterio: +9 dB a cada dobro do OSR, em 1a ordem.
%
% for osr_i = [32 64 128 256]
%     bin_b = 2 : floor(N/(2*osr_i));
%     Ps = sum(P(bin_tom));
%     Pn = sum(P(bin_b)) - sum(P(intersect(bin_tom, bin_b)));
%     fprintf('OSR %4d -> SNR %.1f dB\n', osr_i, 10*log10(Ps/Pn));
% end
