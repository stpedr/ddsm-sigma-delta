%% ddsm2_fixo.m
%  Modulador de 2a ordem (CIFB, Boser-Wooley): modelo em ponto flutuante e em
%  ponto fixo. Etapa 2 de docs/ddsm2-cifb.md.
%
%  A. ponto flutuante (ddsm2_flut.m), senoide nao quantizada: SNR contra o
%     modelo de ruido branco, e o piso da propria medida
%  B. ponto fixo (ddsm2.m) contra ponto flutuante com a MESMA entrada
%     quantizada: as decisoes tem de ser identicas bit a bit (confere a
%     equivalencia entre a forma inteira e os ganhos 0,5)
%  C. SNR do ponto fixo
%  D. latencia medida pela fase do tom, 1a e 2a ordem
%  E. excursao de cada integrador neste estimulo e estado do alarme
%  F. controle negativo do alarme: larguras pequenas de proposito; o alarme
%     tem de disparar SEM alterar a saida (alarme, nao correcao)
%
%  A campanha de estabilidade (excursao em toda a faixa, sobrecarga, estado
%  travado) e a etapa 3. Aqui so o estimulo de referencia.

clear; close all;

P   = le_params('ddsm2');           % fonte unica: rtl/ddsm2_params.vh
FS  = 2^(P.W_IN - 1);
N   = 2^16;
OSR = 64;
K   = 41;
A   = 0.5;
n   = 0:N-1;

Pn_teo = pi^4 / (15 * OSR^5);       % modelo de ruido branco, 2a ordem
fprintf('--- DDSM 2a ordem (CIFB, Boser-Wooley) ---\n');
fprintf('W_IN = %d | B1 A1 C1 A2 = %d %d %d %d | W_I1 W_I2 = %d %d (PROVISORIO)\n', ...
        P.W_IN, P.B1, P.A1, P.C1, P.A2, P.W_I1, P.W_I2);

%% A. ponto flutuante, entrada nao quantizada
x  = A * sin(2*pi*K*n/N);
yf = ddsm2_flut(x);
snr_flut = snr_banda(2*yf - 1, N, K, OSR);
snr_piso = snr_banda(x / A, N, K, OSR);   % a propria senoide: limite da medida
fprintf('\n[A] ponto flutuante, A = %.2f, OSR = %d\n', A, OSR);
fprintf('  SNR medido        = %.1f dB\n', snr_flut);
fprintf('  modelo branco     = %.1f dB\n', 10*log10(A^2/2 / Pn_teo));
fprintf('  piso da medida    = %.1f dB (SNR da senoide ideal: vazamento da janela)\n', snr_piso);

%% B. ponto fixo x ponto flutuante, mesma entrada quantizada
u  = max(min(round(A*FS*sin(2*pi*K*n/N)), FS-1), -FS);
[y, ex, al] = ddsm2(u, P);
yq = ddsm2_flut(u / FS);
nd = sum(y ~= yq);
fprintf('\n[B] ponto fixo (forma inteira) x ponto flutuante (ganhos 0,5), entrada quantizada\n');
fprintf('  divergencias: %d de %d  -> %s\n', nd, N, ifelse_ok(nd == 0));

%% C. SNR do ponto fixo
snr_fixo = snr_banda(2*y - 1, N, K, OSR);
fprintf('\n[C] ponto fixo: SNR = %.1f dB | densidade de 1s = %.6f\n', snr_fixo, mean(y));

%% D. latencia pela fase do tom: atraso em amostras do indice do modelo
%  (1a ordem: y(i) responde a u(i); o RTL acrescenta 1 ciclo de registro)
P1  = le_params();
FS1 = 2^(P1.W_IN - 1); W_ACC1 = P1.W_IN + P1.GUARD;
u1  = max(min(round(A*FS1*sin(2*pi*K*n/N)), FS1-1), -FS1);
y1  = ddsm1(u1, FS1, -2^(W_ACC1-1), 2^(W_ACC1-1)-1);
% atraso = -fase(Y/U) no bin do tom, convertida em amostras
F1y = fft(2*y1 - 1); F1u = fft(u1);
F2y = fft(2*y  - 1); F2u = fft(u);
d1 = -angle(F1y(K+1) / F1u(K+1)) * N / (2*pi*K);
d2 = -angle(F2y(K+1) / F2u(K+1)) * N / (2*pi*K);
fprintf('\n[D] atraso entrada -> saida, pela fase do tom (amostras do modelo)\n');
fprintf('  1a ordem: %.3f   2a ordem: %.3f\n', d1, d2);
fprintf('  latencia em ciclos de clock (+1 do registro de saida): 1a %d, 2a %d\n', ...
        round(d1) + 1, round(d2) + 1);

%% E. excursao de cada integrador e alarme
fprintf('\n[E] excursao neste estimulo (senoide A = %.2f)\n', A);
fprintf('  w1: [%d, %d]  = [%.2f, %.2f] x FS   -> %d bits com sinal\n', ex.w1, ex.w1/FS, ...
        bits_com_sinal(ex.w1));
fprintf('  w2: [%d, %d]  = [%.2f, %.2f] x FS   -> %d bits com sinal\n', ex.w2, ex.w2/FS, ...
        bits_com_sinal(ex.w2));
if al.primeiro == 0
    fprintf('  alarme: nenhum (larguras provisorias %d/%d bits)\n', P.W_I1, P.W_I2);
else
    fprintf('  *** ALARME: w1 fora da faixa em %d ciclos, w2 em %d; primeiro em i = %d ***\n', ...
            al.n1, al.n2, al.primeiro);
end

%% F. controle negativo do alarme
Pt = P; Pt.W_I1 = P.W_IN; Pt.W_I2 = P.W_IN;     % +/-FS: estreito de proposito
[yt, ~, alt] = ddsm2(u, Pt);
fprintf('\n[F] controle do alarme com larguras de %d bits (de proposito estreitas)\n', P.W_IN);
fprintf('  alarme: w1 %d ciclos, w2 %d ciclos, primeiro em i = %d -> disparou: %s\n', ...
        alt.n1, alt.n2, alt.primeiro, ifelse_ok(alt.primeiro > 0));
fprintf('  saida identica a da execucao larga: %s (o alarme nao altera a dinamica)\n', ...
        ifelse_ok(isequal(yt, y)));
