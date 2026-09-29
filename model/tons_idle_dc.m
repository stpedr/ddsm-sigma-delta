%% tons_idle_dc.m
%  Tons idle do DDSM de 1a ordem com entrada DC.
%
%  a) varre 200 valores DC entre 0 e 0,95 FS e mede o SNR na banda em cada um
%  b) grafico SNR x DC e ruido na banda x DC, com zoom fino em torno de 1/2
%  c) grava vetores de referencia para 4 valores DC em sim/vetores_dc_*.txt,
%     comparados bit a bit com o RTL por "make dc"
%
%  Com DC o laco e deterministico e a saida cai num ciclo-limite. Em x = p/q
%  exato o periodo e curto (da ordem de q) e as raias ficam em multiplos de
%  fs/q, FORA da banda para q pequeno. Em x = p/q + e o padrao curto escorrega
%  uma vez a cada ~1/e amostras, e esse batimento lento cai DENTRO da banda.
%  Por isso os vales de SNR ladeiam as fracoes simples, em vez de cair nelas.
%
%  SNR medido com snr_banda_dc.m (nao com snr_banda.m, que e para senoide).
%  Resultados em figs/tons_idle_dc.mat, para a comparacao com dither.

clear; close all;

%% ===============================================================
%  PARAMETROS
%  ===============================================================
P       = le_params();              % fonte unica: rtl/ddsm1_params.vh
W_IN    = P.W_IN;
W_ACC   = W_IN + P.GUARD;
FS      = 2^(W_IN-1);
ACC_MAX =  2^(W_ACC-1) - 1;
ACC_MIN = -2^(W_ACC-1);

N   = 2^16;
OSR = 64;
M   = 200;                          % pontos da varredura grossa

raiz = fullfile(fileparts(mfilename('fullpath')), '..');
dfig = fullfile(raiz, 'figs');
if ~exist(dfig, 'dir'), mkdir(dfig); end

% Referencia: modelo de ruido branco (quantizador +/-1, variancia 1/3) com
% NTF de 1a ordem -> potencia na banda = pi^2 / (9 OSR^3), relativa a FS^2.
% E o mesmo modelo que preve os 44,8 dB da senoide com A = 0,5.
Pn_teo = pi^2 / (9*OSR^3);

%% ===============================================================
%  a) VARREDURA GROSSA: 200 codigos entre 0 e 0,95 FS
%  ===============================================================
u_g = unique(round(linspace(0, 0.95, M) * FS));
[snr_g, pn_g, ovf_g, em_g] = varre_dc(u_g, N, OSR, FS, ACC_MIN, ACC_MAX);
x_g = u_g / FS;

%% Zoom em torno de 1/2: +/- 512 LSB, passo de 4 LSB (inclui 1/2 exato)
u_z = FS/2 + (-512:4:512);
[snr_z, pn_z] = varre_dc(u_z, N, OSR, FS, ACC_MIN, ACC_MAX);

%% Fracoes simples. 1/3 e 2/3 NAO sao representaveis em W_IN bits: o codigo
%  mais proximo fica a menos de 1 LSB delas. O batimento resultante e mais
%  lento que a janela de N amostras e aparece so como um erro de media pequeno;
%  o pior regime e mais longe da fracao, quando o batimento cai na banda.
fr_nome = {'1/8', '1/4', '1/3', '1/2', '5/8', '2/3', '3/4', '7/8'};
fr_val  = [ 1/8,   1/4,   1/3,   1/2,   5/8,   2/3,   3/4,   7/8 ];
u_fr    = round(fr_val * FS);
[snr_fr, pn_fr] = varre_dc(u_fr, N, OSR, FS, ACC_MIN, ACC_MAX);

%% ===============================================================
%  RESUMO NUMERICO
%  ===============================================================
dB = @(p) 10*log10(max(p, 1e-30));

fprintf('--- tons idle com entrada DC (W_IN=%d, W_ACC=%d, N=%d, OSR=%d) ---\n', ...
        W_IN, W_ACC, N, OSR);
fprintf('varredura grossa: %d codigos, de %d a %d (x = %.4f a %.4f)\n', ...
        numel(u_g), u_g(1), u_g(end), x_g(1), x_g(end));
fprintf('overflows: %d | max |media(y) - x| = %.2e\n', sum(ovf_g), max(abs(em_g)));
fprintf('ruido na banda, modelo branco: %.1f dBFS\n', dB(Pn_teo));
fprintf('ruido na banda medido: mediana %.1f dBFS, min %.1f, max %.1f\n', ...
        dB(median(pn_g)), dB(min(pn_g)), dB(max(pn_g)));
fprintf('pontos com ruido acima do modelo branco: %d de %d\n', ...
        sum(pn_g > Pn_teo), numel(pn_g));

% Os 8 piores pontos por ruido na banda, com a fracao simples mais proxima
[~, ord] = sort(pn_g, 'descend');
fprintf('\n  8 piores pontos (ruido na banda):\n');
fprintf('  %7s %8s %10s %8s   %s\n', 'u', 'x', 'ruido', 'SNR', 'fracao simples mais proxima (q<=8)');
for j = ord(1:8)
    melhor = [Inf 0 1];
    for q = 1:8
        p = round(x_g(j)*q);
        d = abs(x_g(j) - p/q) * FS;
        if d < melhor(1), melhor = [d p q]; end
    end
    fprintf('  %7d %8.4f %7.1f dB %5.1f dB   %d/%d, a %.0f LSB\n', ...
            u_g(j), x_g(j), dB(pn_g(j)), snr_g(j), melhor(2), melhor(3), melhor(1));
end

fprintf('\n  fracoes simples:\n');
fprintf('  %5s %7s %8s %10s %8s\n', 'x', 'u', 'exata?', 'ruido', 'SNR');
for j = 1:numel(fr_val)
    if abs(u_fr(j) - fr_val(j)*FS) < 1e-9, exata = 'sim'; else, exata = 'nao'; end
    fprintf('  %5s %7d %8s %7.1f dB %5.1f dB\n', fr_nome{j}, u_fr(j), exata, ...
            dB(pn_fr(j)), snr_fr(j));
end

[pz_max, iz] = max(pn_z);
fprintf('\n  zoom em 1/2: ruido em 1/2 exato = %.1f dBFS; pior vizinho = %.1f dBFS a %+d LSB\n', ...
        dB(pn_z(u_z == FS/2)), dB(pz_max), u_z(iz) - FS/2);

%% ===============================================================
%  b) GRAFICOS
%  ===============================================================
f = figure('Color', 'w', 'Position', [100 100 820 980]);
cor_med = [0.20 0.45 0.75];
cor_teo = [0.85 0.25 0.15];
cor_fr  = [0.60 0.60 0.60];

% (1) SNR x DC
subplot(3,1,1);
xt = linspace(0.002, 0.95, 400);
ok = x_g > 0;                         % em x = 0 o SNR e -Inf por definicao
plot(x_g(ok), snr_g(ok), '.-', 'Color', cor_med, 'MarkerSize', 8); hold on;
plot(xt, 10*log10(xt.^2 / Pn_teo), '--', 'Color', cor_teo, 'LineWidth', 1.2);
yl = [-20 160];
for v = fr_val, plot([v v], yl, ':', 'Color', cor_fr); end
ylim(yl); xlim([0 0.96]); grid on; box on;
xlabel('entrada DC  x = u / FS'); ylabel('SNR na banda [dB]');
title(sprintf('SNR x DC (OSR = %d, %d pontos; pontilhado: 1/8 1/4 1/3 1/2 5/8 2/3 3/4 7/8)', ...
      OSR, numel(u_g)));
legend({'medido', 'modelo de ruido branco'}, 'Location', 'southeast');

% (2) ruido na banda x DC
subplot(3,1,2);
plot(x_g, dB(pn_g), '.-', 'Color', cor_med, 'MarkerSize', 8); hold on;
plot([0 0.96], dB(Pn_teo)*[1 1], '--', 'Color', cor_teo, 'LineWidth', 1.2);
yl = [-180 0];
for v = fr_val, plot([v v], yl, ':', 'Color', cor_fr); end
ylim(yl); xlim([0 0.96]); grid on; box on;
xlabel('entrada DC  x = u / FS'); ylabel('ruido na banda [dBFS]');
title('Potencia de ruido na banda (independe do nivel do sinal)');
legend({'medido', 'modelo de ruido branco'}, 'Location', 'southeast');

% (3) zoom em torno de 1/2
subplot(3,1,3);
plot(u_z - FS/2, dB(pn_z), '.-', 'Color', cor_med, 'MarkerSize', 8); hold on;
plot([-512 512], dB(Pn_teo)*[1 1], '--', 'Color', cor_teo, 'LineWidth', 1.2);
xlim([-512 512]); ylim([-180 0]); grid on; box on;
xlabel('desvio em relacao a x = 1/2  [LSB]'); ylabel('ruido na banda [dBFS]');
title('Zoom em x = 1/2, passo de 4 LSB');

set(f, 'PaperUnits', 'inches', 'PaperPosition', [0 0 8.2 9.8]);
print(f, '-dpng', '-r150', fullfile(dfig, 'fig4_tons_idle_dc.png'));

save(fullfile(dfig, 'tons_idle_dc.mat'), 'u_g', 'snr_g', 'pn_g', 'u_z', 'snr_z', ...
     'pn_z', 'u_fr', 'snr_fr', 'pn_fr', 'fr_nome', 'Pn_teo', 'N', 'OSR', 'FS', '-v7');

%% ===============================================================
%  c) VETORES DE REFERENCIA PARA O RTL
%  ===============================================================
%  pior caso da varredura, 1/2 exato (ciclo-limite curto), o codigo mais
%  proximo de 1/3 (batimento mais lento que a janela) e -FS (extremo negativo
%  da entrada: maior extensao de sinal de din).
u_vet  = [u_g(ord(1)), FS/2, round(FS/3), -FS];
motivo = {'pior caso da varredura', '1/2 exato', 'mais proximo de 1/3', '-FS'};

fprintf('\n--- c) vetores DC gravados em sim/ ---\n');
for j = 1:numel(u_vet)
    y = ddsm1(repmat(u_vet(j), 1, N), FS, ACC_MIN, ACC_MAX);
    if u_vet(j) < 0, tag = sprintf('m%05d', -u_vet(j)); else, tag = sprintf('%05d', u_vet(j)); end
    arq = fullfile(raiz, 'sim', ['vetores_dc_' tag '.txt']);
    grava_vetores(arq, repmat(u_vet(j), 1, N), y, W_IN, W_ACC, ...
                  sprintf('DC=%d x=%.6f', u_vet(j), u_vet(j)/FS));
    fprintf('  vetores_dc_%s.txt  (%s, densidade de 1s = %.6f)\n', tag, motivo{j}, mean(y));
end
