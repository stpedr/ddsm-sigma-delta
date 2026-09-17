%% ddsm1_fixo.m
%  Modulador sigma-delta digital de 1a ordem em PONTO FIXO.
%  Este e o golden model definitivo: e contra ele que o RTL deve bater bit a bit.
%
%  Diferencas para a versao em ponto flutuante:
%    - entrada quantizada em W_IN bits, complemento de dois
%    - acumulador inteiro de W_ACC bits, com saturacao e flag de overflow
%    - quantizador = bit de sinal do acumulador (sem comparacao aritmetica)
%    - saida em {0,1} como no RTL, e nao em {-1,+1}
%
%  Secoes:
%    A. modulador + medida de SNR
%    B. varredura de excursao do acumulador  -> dimensiona W_ACC (card 3.7)
%    C. exportacao de vetores para o testbench (card 4.1)

clear; clc; close all;

%% ===============================================================
%  PARAMETROS
%  ===============================================================
W_IN  = 16;      % largura da entrada, em bits, com sinal
GUARD = 3;       % bits de guarda do acumulador (a secao B valida este numero)
W_ACC = W_IN + GUARD;

OSR = 64;
N   = 2^16;
K   = 41;
A   = 0.5;       % amplitude em fracao do fundo de escala

FS      = 2^(W_IN-1);          % fundo de escala em LSBs
ACC_MAX =  2^(W_ACC-1) - 1;    % limites do acumulador saturado
ACC_MIN = -2^(W_ACC-1);

%% ===============================================================
%  A. MODULADOR + SNR
%  ===============================================================
n = 0:N-1;
u_real = A * FS * sin(2*pi*K*n/N);
u = max(min(round(u_real), FS-1), -FS);   % quantiza e satura a entrada

[y, acc_max_abs, n_ovf] = ddsm1(u, FS, ACC_MIN, ACC_MAX);

% saida do RTL e {0,1}; para medir espectro, mapeia de volta para {-1,+1}
y_bip = 2*y - 1;

SNR_dB = snr_banda(y_bip, N, K, OSR);

fprintf('--- A. modulador em ponto fixo ---\n');
fprintf('W_IN = %d | W_ACC = %d | OSR = %d | A = %.2f\n', W_IN, W_ACC, OSR, A);
fprintf('SNR na banda   = %.1f dB\n', SNR_dB);
fprintf('|acc| maximo   = %d LSBs (%.2f x FS)\n', acc_max_abs, acc_max_abs/FS);
fprintf('overflows      = %d\n', n_ovf);
fprintf('densidade de 1s = %.4f (esperado ~0.5 para senoide centrada)\n\n', mean(y));

%% ===============================================================
%  B. VARREDURA DE EXCURSAO DO ACUMULADOR
%  ===============================================================
%  O accmax de UMA simulacao nao dimensiona nada: e o pior caso daquele
%  estimulo especifico. O numero que vale e o maximo global sobre os tres
%  estimulos que estressam o laco de formas diferentes.

fprintf('--- B. varredura de excursao ---\n');
acc_global = 0;

% B1. senoides de varias amplitudes
for a = [0.1 0.3 0.5 0.7 0.9 0.95]
    ui = max(min(round(a*FS*sin(2*pi*K*n/N)), FS-1), -FS);
    [~, am, ov] = ddsm1(ui, FS, ACC_MIN, ACC_MAX);
    acc_global = max(acc_global, am);
    fprintf('  seno A=%.2f  -> |acc|max = %6d (%.2f x FS)  ovf=%d\n', ...
            a, am, am/FS, ov);
end

% B2. entradas DC (o caso que gera ciclo-limite e excursoes lentas)
for d = [0 0.25 0.5 0.75 0.9 0.99]
    ui = repmat(round(d*(FS-1)), 1, N);
    [~, am, ov] = ddsm1(ui, FS, ACC_MIN, ACC_MAX);
    acc_global = max(acc_global, am);
    fprintf('  DC   =%.2f  -> |acc|max = %6d (%.2f x FS)  ovf=%d\n', ...
            d, am, am/FS, ov);
end

% B3. rampa de fundo de escala
ui = round(linspace(-FS, FS-1, N));
[~, am, ov] = ddsm1(ui, FS, ACC_MIN, ACC_MAX);
acc_global = max(acc_global, am);
fprintf('  rampa FS   -> |acc|max = %6d (%.2f x FS)  ovf=%d\n', am, am/FS, ov);

% bits necessarios: sinal + magnitude do pior caso, com uma margem
bits_necessarios = ceil(log2(acc_global)) + 1;
fprintf('\n  pior caso global = %d LSBs (%.2f x FS)\n', acc_global, acc_global/FS);
fprintf('  W_ACC minimo     = %d bits\n', bits_necessarios);
fprintf('  W_ACC adotado    = %d bits -> margem de %d bit(s)\n\n', ...
        W_ACC, W_ACC - bits_necessarios);

%% ===============================================================
%  C. EXPORTACAO DE VETORES PARA O TESTBENCH
%  ===============================================================
%  Formato: uma linha por ciclo, "<entrada_decimal_com_sinal> <bit_de_saida>".
%  O testbench cocotb le a coluna 1, aplica no DUT e compara com a coluna 2.

fid = fopen('vetores_ddsm1.txt','w');
fprintf(fid, '# W_IN=%d W_ACC=%d N=%d OSR=%d A=%.2f K=%d\n', ...
        W_IN, W_ACC, N, OSR, A, K);
fprintf(fid, '%d %d\n', [u; y]);
fclose(fid);
fprintf('--- C. vetores gravados em vetores_ddsm1.txt (%d linhas) ---\n', N);

%% ===============================================================
%  GRAFICO
%  ===============================================================
w = hann(N).';
P = abs(fft(y_bip .* w)).^2; P = P(1:N/2);
f = (0:N/2-1)/N;

figure;
semilogx(f(2:end), 10*log10(P(2:end)/max(P))); grid on; hold on;
xline(1/(2*OSR), '--', 'borda da banda');
xlabel('frequencia normalizada (f/fs)'); ylabel('PSD normalizada [dB]');
title(sprintf('DDSM 1a ordem ponto fixo - W_{IN}=%d W_{ACC}=%d - SNR=%.1f dB', ...
      W_IN, W_ACC, SNR_dB));

%% ===============================================================
%  FUNCOES
%  ===============================================================
function [y, acc_max_abs, n_ovf] = ddsm1(u, FS, ACC_MIN, ACC_MAX)
% Modulador de 1a ordem, aritmetica inteira, identico ao que o RTL faz.
%   u   : vetor de entrada em LSBs (inteiros com sinal)
%   y   : saida em {0,1}, como o pino do chip
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

function SNR_dB = snr_banda(y_bip, N, K, OSR)
% SNR na banda util, com janela Hann e exclusao dos bins do tom.
    P = abs(fft(y_bip .* hann(N).')).^2; P = P(1:N/2);
    bin_banda = 2 : floor(N/(2*OSR));
    bin_tom   = (K+1) + (-3:3);
    Psig   = sum(P(bin_tom));
    Pruido = sum(P(bin_banda)) - sum(P(intersect(bin_tom, bin_banda)));
    SNR_dB = 10*log10(Psig / Pruido);
end
