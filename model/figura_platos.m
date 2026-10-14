%% figura_platos.m
%  Figuras dos platos de tons idle, a partir de figs/tons_idle_dc.mat
%  (rode tons_idle_dc.m antes).
%
%  fig6 (principal) -- meia-largura medida contra a previsao FS/(OSR*P), um
%                      ponto por centro (0, 1/4, 1/3, 1/2, -1, +1), pelos dois
%                      metodos. Em x = +/-1 so existe um lado do plato.
%  fig5 (apoio)     -- os zooms: ruido na banda e frequencia do tom
%                      contra o desvio do centro
%
%  Mesmo padrao visual de figuras_validacao.m: teorico tracejado, medido em
%  marcadores. Usa so plot/print, para rodar tambem no Octave.

clear; close all;

raiz = fullfile(fileparts(mfilename('fullpath')), '..');
dfig = fullfile(raiz, 'figs');
load(fullfile(dfig, 'tons_idle_dc.mat'), 'zoom', 'FS', 'OSR', 'Pn_teo');

LW = 1.4;  MS = 7;  FSZ = 11;          % espessura, marcador, fonte
cor_med = [0.20 0.45 0.75];
cor_teo = [0.85 0.25 0.15];
cor_cin = [0.55 0.55 0.55];
cor_prv = [0.15 0.60 0.30];

fB = 1/(2*OSR);
% "neg/pos" das bordas; em x = +/-1 so existe um lado (o outro e NaN)
bordas_txt = @(a, b) strrep(strrep(sprintf('%.0f/%.0f', a, b), 'NaN/', ''), '/NaN', '');
dB = @(p) 10*log10(max(p, 1e-30));
Z  = numel(zoom);

w_teo  = [zoom.w_teo];
% media dos lados que existem (em x = +/-1 so ha um)
[w_ruid, w_tom] = deal(zeros(1, Z));
for c = 1:Z
    v = [zoom(c).borda_ruido_neg, zoom(c).borda_ruido_pos];  w_ruid(c) = mean(v(~isnan(v)));
    v = [zoom(c).borda_tom_neg,   zoom(c).borda_tom_pos];    w_tom(c)  = mean(v(~isnan(v)));
end

%% ===============================================================
%  FIG. 6 -- LARGURA DOS PLATOS: MEDIDA x PREVISTA
%  ===============================================================
f6 = figure('Color', 'w', 'Position', [100 100 560 460]);
wmax = 600;
plot([0 wmax], [0 wmax], '--', 'LineWidth', LW, 'Color', cor_cin); hold on;
% Sem MarkerFaceColor: com preenchimento branco o gnuplot (Octave) desenha o
% marcador da legenda so com o preenchimento, e ele some contra o fundo.
plot(w_teo, w_ruid, 'o', 'LineWidth', LW, 'MarkerSize', MS + 3, 'Color', cor_med);
plot(w_teo, w_tom, 'x', 'LineWidth', LW, 'MarkerSize', MS + 1, 'Color', cor_teo);
for c = 1:Z
    dy = -28;
    if strcmp(zoom(c).nome, '+1'), dy = -60; end   % -1 e +1 caem no mesmo ponto
    text(w_teo(c) + 14, w_ruid(c) + dy, sprintf('x = %s (P = %d)', zoom(c).nome, zoom(c).P), ...
         'FontSize', FSZ - 2);
end
grid on; box on; axis([0 wmax 0 wmax]); set(gca, 'FontSize', FSZ);
xlabel('meia-largura prevista  FS / (OSR P)  [LSB]');
ylabel('meia-largura medida  [LSB]');
title(sprintf('Largura dos platos de tons idle (OSR = %d, passo 4 LSB)', OSR));
legend({'teorico: FS / (OSR P)', 'medido: queda do ruido na banda', ...
        'medido: tom cruza a borda da banda'}, 'Location', 'northwest', 'FontSize', FSZ - 2);

set(f6, 'PaperUnits', 'inches', 'PaperPosition', [0 0 5.6 4.6]);
print(f6, '-dpng', '-r300', fullfile(dfig, 'fig6_largura_platos.png'));
print(f6, '-dpdf', fullfile(dfig, 'fig6_largura_platos.pdf'));

%% ===============================================================
%  FIG. 5 -- ZOOMS (material de apoio)
%  ===============================================================
%  Linha 1: ruido na banda medido, previsto (pn_plato_prev.m) e modelo branco.
%  Linha 2: frequencia do tom idle (tom_idle.m) normalizada pela borda da
%  banda, e a previsao P|eps|/2. Linhas verticais cinza: borda medida pelo
%  ruido; pontilhadas pretas: borda prevista.
f5 = figure('Color', 'w', 'Position', [100 100 2100 760]);
for c = 1:Z
    zc = zoom(c);
    bm = [-zc.borda_ruido_neg, zc.borda_ruido_pos];
    bm = bm(~isnan(bm));
    xl = [min(zc.d) max(zc.d)];

    subplot(2, Z, c);
    plot(zc.d, dB(zc.pn), '.-', 'Color', cor_med, 'MarkerSize', 6); hold on;
    de = linspace(-zc.w_teo, zc.w_teo, 801); de(de == 0) = [];
    de = de(de >= xl(1) & de <= xl(2));
    plot(de, dB(pn_plato_prev(de/FS, zc.P, OSR)), '-', 'Color', cor_prv, 'LineWidth', 1.0);
    plot(xl, dB(Pn_teo)*[1 1], '--', 'Color', cor_teo, 'LineWidth', 1.0);
    for b = bm, plot([b b], [-180 0], '-', 'Color', cor_cin); end
    for b = [-1 1]*zc.w_teo
        if b >= xl(1) && b <= xl(2), plot([b b], [-180 0], ':', 'Color', 'k'); end
    end
    xlim(xl); ylim([-180 0]); grid on; box on;
    title(sprintf('x = %s (P = %d): %s LSB, prev. %.0f', zc.nome, zc.P, ...
          bordas_txt(zc.borda_ruido_neg, zc.borda_ruido_pos), zc.w_teo), 'FontSize', 9);
    xlabel('desvio do centro [LSB]');
    if c == 1
        ylabel('ruido na banda [dBFS]');
        legend({'medido', 'previsto', 'ruido branco', 'borda medida'}, ...
               'Location', 'south', 'FontSize', 7);
    end

    subplot(2, Z, Z + c);
    plot(zc.d, zc.f / fB, '.', 'Color', cor_med, 'MarkerSize', 6); hold on;
    plot(xl, [1 1], '--', 'Color', cor_teo, 'LineWidth', 1.0);
    plot(zc.d, zc.P * abs(zc.d) / (2*FS) / fB, '-', 'Color', cor_prv, 'LineWidth', 1.0);
    for b = bm, plot([b b], [0 3], '-', 'Color', cor_cin); end
    xlim(xl); ylim([0 3]); grid on; box on;
    xlabel('desvio do centro [LSB]');
    title(sprintf('tom cruza a borda: %s LSB', ...
          bordas_txt(zc.borda_tom_neg, zc.borda_tom_pos)), 'FontSize', 9);
    if c == 1
        ylabel('f do tom / borda da banda');
        legend({'tom medido', 'borda da banda', 'previsto P|eps|/2', 'borda (ruido)'}, ...
               'Location', 'north', 'FontSize', 7);
    end
end
set(f5, 'PaperUnits', 'inches', 'PaperPosition', [0 0 21 7.6]);
print(f5, '-dpng', '-r130', fullfile(dfig, 'fig5_platos_tons_idle.png'));

%% ===============================================================
%  RESUMO
%  ===============================================================
fprintf('%4s %2s %9s %9s %9s\n', 'x', 'P', 'prevista', 'ruido', 'tom');
for c = 1:Z
    fprintf('%4s %2d %9.1f %9.1f %9.1f\n', zoom(c).nome, zoom(c).P, w_teo(c), w_ruid(c), w_tom(c));
end
