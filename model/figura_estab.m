%% figura_estab.m
%  Figura da campanha de estabilidade da 2a ordem, a partir de
%  figs/ddsm2_estab.mat (rode ddsm2_estab.m antes).
%
%  fig11_estab_2a_ordem.png, quatro paineis:
%   (a) DC: excursao de w1 e w2 contra 1 - |x| (log-log), com a regra da
%       1a ordem FS(1+|x|) e o ajuste empirico FS(2/(1-|x|) - 1)
%   (b) senoide: excursao de w1 e w2 contra A, com a regra da 1a ordem
%   (c) razao max|w2| / max|w1| contra a amplitude (senoide e DC)
%   (d) SNR da senoide contra A
%  Teorico/regra tracejado, medido em marcadores (padrao de figuras_validacao.m).

clear; close all;

raiz = fullfile(fileparts(mfilename('fullpath')), '..');
dfig = fullfile(raiz, 'figs');
load(fullfile(dfig, 'ddsm2_estab.mat'));

LW = 1.4; MS = 6; FSZ = 10;
c1 = [0.20 0.45 0.75]; c2 = [0.85 0.25 0.15]; cc = [0.55 0.55 0.55]; cv = [0.15 0.60 0.30];

m1d = max(abs(D.w1), [], 2).' / FS;   m2d = max(abs(D.w2), [], 2).' / FS;
m1s = max(abs(S.w1), [], 2).' / FS;   m2s = max(abs(S.w2), [], 2).' / FS;
% Onde a janela de 2^16 nao atingiu o maximo, usa o da janela de 2^20
% (ddsm2_estab.m, D3): e o envelope, nao o maximo de uma janela curta.
if isfield(S, 'm20'), longa = ~isnan(S.m20); m2s(longa) = S.m20(longa) / FS; end
xd  = D.u / FS;  dd = 1 - abs(xd);
ok  = dd > 0;                          % u = -FS (x = -1) diverge: fora do log
neg = xd < 0 & ok;  pos = xd > 0 & ok;

f = figure('Color', 'w', 'Position', [100 100 1200 860]);

% (a) DC
subplot(2, 2, 1);
loglog(dd(neg), m2d(neg), 'o', 'LineWidth', LW, 'MarkerSize', MS, 'Color', c2); hold on;
loglog(dd(pos), m2d(pos), 's', 'LineWidth', LW, 'MarkerSize', MS, 'Color', c2);
loglog(dd(neg), m1d(neg), 'o', 'LineWidth', LW, 'MarkerSize', MS, 'Color', c1);
loglog(dd(pos), m1d(pos), 's', 'LineWidth', LW, 'MarkerSize', MS, 'Color', c1);
de = logspace(-5, 0, 200);
loglog(de, 2./de - 1, '--', 'LineWidth', LW, 'Color', c2);
loglog(de, 1 + (1 - de), '--', 'LineWidth', LW, 'Color', cc);
grid on; box on; set(gca, 'FontSize', FSZ); xlim([1e-5 1.2]); ylim([0.5 1e5]);
xlabel('1 - |x|   (distancia ao fundo de escala)'); ylabel('max |w| / FS');
title('DC: excursao dos integradores (x = -1 diverge, fora do grafico)');
legend({'w2, x < 0', 'w2, x > 0', 'w1, x < 0', 'w1, x > 0', ...
        'ajuste: 2/(1-|x|) - 1', 'regra da 1a ordem: 1 + |x|'}, ...
       'Location', 'northeast', 'FontSize', FSZ - 2);

% (b) senoide
subplot(2, 2, 2);
semilogy(S.A, m2s, 'o-', 'LineWidth', LW, 'MarkerSize', MS, 'Color', c2); hold on;
semilogy(S.A, m1s, 'o-', 'LineWidth', LW, 'MarkerSize', MS, 'Color', c1);
semilogy(S.A, S.acc1 / FS, 'x', 'LineWidth', LW, 'MarkerSize', MS + 1, 'Color', cc);
semilogy([0 1], [1 2], '--', 'LineWidth', LW, 'Color', cc);
grid on; box on; set(gca, 'FontSize', FSZ); xlim([0 1.02]); ylim([0.5 300]);
xlabel('amplitude da senoide  A'); ylabel('max |w| / FS');
title('Senoide: excursao dos integradores contra a regra da 1a ordem');
legend({'2a ordem: w2', '2a ordem: w1', '1a ordem: acc (medido)', ...
        'regra da 1a ordem: 1 + A'}, 'Location', 'northwest', 'FontSize', FSZ - 2);

% (c) razao
subplot(2, 2, 3);
plot(S.A, m2s ./ m1s, 'o-', 'LineWidth', LW, 'MarkerSize', MS, 'Color', c1); hold on;
plot(abs(xd(neg)), m2d(neg) ./ m1d(neg), 'o', 'LineWidth', LW, 'MarkerSize', MS, 'Color', cv);
plot(abs(xd(pos)), m2d(pos) ./ m1d(pos), 's', 'LineWidth', LW, 'MarkerSize', MS, 'Color', cv);
set(gca, 'YScale', 'log');
grid on; box on; set(gca, 'FontSize', FSZ); xlim([0 1.02]);
xlabel('amplitude  (A da senoide, |x| do DC)'); ylabel('max|w2| / max|w1|');
title('Razao entre as excursoes dos dois integradores');
legend({'senoide', 'DC, x < 0', 'DC, x > 0'}, 'Location', 'northwest', 'FontSize', FSZ - 2);

% (d) SNR
subplot(2, 2, 4);
plot(S.A, S.snr, 'o-', 'LineWidth', LW, 'MarkerSize', MS, 'Color', c1); hold on;
[smax, jm] = max(S.snr);
plot([0 1.02], (smax - 3) * [1 1], '--', 'LineWidth', LW, 'Color', cc);
grid on; box on; set(gca, 'FontSize', FSZ); xlim([0 1.02]);
xlabel('amplitude da senoide  A'); ylabel('SNR na banda [dB]');
title(sprintf('SNR da 2a ordem (OSR = %d): maximo %.1f dB em A = %.2f', OSR, smax, S.A(jm)));
legend({'medido', 'maximo - 3 dB'}, 'Location', 'south', 'FontSize', FSZ - 2);

set(f, 'PaperUnits', 'inches', 'PaperPosition', [0 0 12 8.6]);
print(f, '-dpng', '-r150', fullfile(dfig, 'fig11_estab_2a_ordem.png'));

% Residuo do ajuste empirico, lado negativo, |x| >= 0,5
sel = neg & abs(xd) >= 0.5;
res = m2d(sel) - (2 ./ dd(sel) - 1);
fprintf('ajuste FS(2/(1-|x|)-1), DC negativo com |x| >= 0,5: residuo max %.3f FS (%d pontos)\n', ...
        max(abs(res)), sum(sel));
sel = pos & abs(xd) >= 0.5;
res = m2d(sel) - (2 ./ dd(sel) - 1);
fprintf('mesmo ajuste, DC positivo com |x| >= 0,5: residuo de %.2f a %.2f FS (medido abaixo da formula)\n', ...
        min(res), max(res));
