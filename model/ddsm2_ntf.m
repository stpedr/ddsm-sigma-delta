%% ddsm2_ntf.m
%  Estrutura, coeficientes e NTF do modulador de 2a ordem (CIFB, Boser-Wooley).
%  Etapa 1 da 2a ordem: confere a NTF e a STF a partir das PROPRIAS equacoes
%  de diferenca do laco, linearizadas, e compara com a 1a ordem.
%
%  Laco de Boser-Wooley (dois integradores com atraso, ganhos 0,5):
%     v1[n+1] = v1[n] + 0,5 (u[n] - y[n])
%     v2[n+1] = v2[n] + 0,5 (v1[n] - y[n])
%     y[n]    = sgn(v2[n]) * FS
%  Forma inteira equivalente (w1 = 2 v1, w2 = 4 v2; sgn(w2) = sgn(v2)):
%     w1[n+1] = w1[n] + B1 u[n] - A1 y[n]          B1 = 1, A1 = 1
%     w2[n+1] = w2[n] + C1 w1[n] - A2 y[n]         C1 = 1, A2 = 2
%  Nenhuma divisao por 2: o laco digital nao perde LSB por deslocamento.
%
%  Linearizacao: y = k w2 + e. Com k = 1 a forma inteira da
%     NTF(z) = (1 - z^-1)^2,  STF(z) = z^-2.
%  Para um quantizador de 1 bit k nao e definido; k = 1 e uma convencao do
%  modelo linear, e a etapa 5 mede o que o laco real faz.
%
%  Coeficientes AQUI so para esta verificacao. Na etapa 2 eles passam para
%  rtl/ddsm2_params.vh, fonte unica, e este script passa a le-los de la.
%
%  Saida: figs/fig10_ntf_ordem1x2.png

clear; close all;

B1 = 1; A1 = 1; C1 = 1; A2 = 2;   % ver cabecalho
OSR = 64;
L = 16;                            % amostras das respostas ao impulso

%% ===============================================================
%  RESPOSTAS AO IMPULSO DO LACO LINEARIZADO
%  ===============================================================
%  2a ordem: y[n] = w2[n] + e[n] (k = 1), estados atualizados apos a saida.
imp = [1 zeros(1, L-1)];
[ntf2, stf2] = deal(zeros(1, L));
for caso = 1:2
    if caso == 1, u = zeros(1, L); e = imp; else, u = imp; e = zeros(1, L); end
    w1 = 0; w2 = 0; y = zeros(1, L);
    for n = 1:L
        y(n) = w2 + e(n);
        w1n = w1 + B1*u(n) - A1*y(n);
        w2n = w2 + C1*w1   - A2*y(n);
        w1 = w1n; w2 = w2n;
    end
    if caso == 1, ntf2 = y; else, stf2 = y; end
end

%  1a ordem (forma de model/ddsm1.m, integrador sem atraso):
%  acc[n] = acc[n-1] + u[n] - y[n-1];  y[n] = acc[n] + e[n]
[ntf1, stf1] = deal(zeros(1, L));
for caso = 1:2
    if caso == 1, u = zeros(1, L); e = imp; else, u = imp; e = zeros(1, L); end
    acc = 0; yant = 0; y = zeros(1, L);
    for n = 1:L
        acc  = acc + u(n) - yant;
        y(n) = acc + e(n);
        yant = y(n);
    end
    if caso == 1, ntf1 = y; else, stf1 = y; end
end

esp_ntf2 = [1 -2 1 zeros(1, L-3)];  esp_stf2 = [0 0 1 zeros(1, L-3)];
esp_ntf1 = [1 -1 zeros(1, L-2)];    esp_stf1 = [1 zeros(1, L-1)];

fprintf('--- respostas ao impulso do laco linearizado (k = 1) ---\n');
fprintf('2a ordem  NTF: %s  esperado (1-z^-1)^2: %s\n', mat2str(ntf2(1:6)), mat2str(esp_ntf2(1:6)));
fprintf('2a ordem  STF: %s  esperado z^-2      : %s\n', mat2str(stf2(1:6)), mat2str(esp_stf2(1:6)));
fprintf('1a ordem  NTF: %s  esperado (1-z^-1)  : %s\n', mat2str(ntf1(1:6)), mat2str(esp_ntf1(1:6)));
fprintf('1a ordem  STF: %s  esperado 1         : %s\n', mat2str(stf1(1:6)), mat2str(esp_stf1(1:6)));
ok = isequal(ntf2, esp_ntf2) && isequal(stf2, esp_stf2) && ...
     isequal(ntf1, esp_ntf1) && isequal(stf1, esp_stf1);
fprintf('confere: %s\n', ifelse_ok(ok));

%% ===============================================================
%  NTF NA FREQUENCIA E PREVISOES DO MODELO DE RUIDO BRANCO
%  ===============================================================
%  Quantizador +/-1 (degrau 2): variancia do erro 1/3. Potencia na banda,
%  relativa a FS^2, com a aproximacao |NTF| ~ (2 pi f)^L para f << 1:
%     1a ordem: pi^2/(9 OSR^3)       2a ordem: pi^4/(15 OSR^5)
f   = logspace(-5, log10(0.5), 2000);
z1  = exp(-1j*2*pi*f);
N1  = abs(1 - z1);
N2  = abs((1 - z1).^2);
fB  = 1/(2*OSR);

Pn1 = pi^2 / (9  * OSR^3);
Pn2 = pi^4 / (15 * OSR^5);
% Conferencia numerica das formulas: integral de (1/3)|NTF|^2 sobre a banda
fi  = linspace(0, fB, 200001);
Pn1n = 2 * trapz(fi, (1/3) * abs(1 - exp(-1j*2*pi*fi)).^2);
Pn2n = 2 * trapz(fi, (1/3) * abs((1 - exp(-1j*2*pi*fi)).^2).^2);

oitavas = [32 64 128 256];
fprintf('\n--- previsoes do modelo de ruido branco (OSR = %d) ---\n', OSR);
fprintf('ruido na banda   1a: %.1f dBFS (integral exata %.1f)   2a: %.1f dBFS (integral exata %.1f)\n', ...
        10*log10(Pn1), 10*log10(Pn1n), 10*log10(Pn2), 10*log10(Pn2n));
fprintf('SNR, seno A=0,5  1a: %.1f dB   2a: %.1f dB   (diferenca %.1f dB)\n', ...
        10*log10(0.125/Pn1), 10*log10(0.125/Pn2), 10*log10(Pn1/Pn2));
fprintf('inclinacao SNR x OSR: 1a %.1f dB/oitava, 2a %.1f dB/oitava\n', ...
        10*log10(2^3), 10*log10(2^5));
fprintf('SNR previsto por OSR (A=0,5):');
fprintf('  %d: %.1f / %.1f', [oitavas; 10*log10(0.125./(pi^2./(9*oitavas.^3))); ...
                                      10*log10(0.125./(pi^4./(15*oitavas.^5)))]);
fprintf('  (1a / 2a)\n');
fprintf('inclinacao do espectro abaixo de fB: 1a %.1f dB/decada, 2a %.1f dB/decada\n', ...
        20*log10(N1(100)/N1(1))/log10(f(100)/f(1)), 20*log10(N2(100)/N2(1))/log10(f(100)/f(1)));
fprintf('ganho fora da banda max |NTF|: 1a %.1f, 2a %.1f\n', max(N1), max(N2));

%% ===============================================================
%  FIGURA
%  ===============================================================
fg = figure('Color', 'w', 'Position', [100 100 620 440]);
semilogx(f, 20*log10(N1), '-', 'LineWidth', 1.4, 'Color', [0.20 0.45 0.75]); hold on;
semilogx(f, 20*log10(N2), '-', 'LineWidth', 1.4, 'Color', [0.85 0.25 0.15]);
plot([fB fB], [-140 20], ':', 'Color', [0.3 0.3 0.3], 'LineWidth', 1.4);
grid on; box on; ylim([-140 20]); xlim([1e-5 0.5]); set(gca, 'FontSize', 11);
xlabel('frequencia normalizada  f/fs'); ylabel('|NTF| [dB]');
title('NTF: 1a ordem (1-z^{-1}) e 2a ordem CIFB (1-z^{-1})^2');
legend({'1a ordem: 20 dB/decada', '2a ordem: 40 dB/decada', ...
        sprintf('borda da banda (OSR = %d)', OSR)}, 'Location', 'southeast', 'FontSize', 10);
raiz = fullfile(fileparts(mfilename('fullpath')), '..');
set(fg, 'PaperUnits', 'inches', 'PaperPosition', [0 0 6.2 4.4]);
print(fg, '-dpng', '-r200', fullfile(raiz, 'figs', 'fig10_ntf_ordem1x2.png'));
