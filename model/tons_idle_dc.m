%% tons_idle_dc.m
%  Tons idle do DDSM de 1a ordem com entrada DC.
%
%  a) panorama: 200 codigos uniformes entre 0 e 0,95 FS (passo ~156 LSB).
%     ATENCAO: o passo e maior que a meia-largura dos platos de tons
%     (64 a 256 LSB), entao o panorama SUBAMOSTRA o fenomeno. Serve so de
%     visao geral; os numeros que valem vem dos zooms.
%  b) zooms de +/-400 LSB, passo de 4 LSB, em torno de 0, 1/4, 1/3 e 1/2:
%     largura do plato medida por dois caminhos independentes
%       - degrau do ruido na banda (snr_banda_dc.m)
%       - ponto em que o tom idle (tom_idle.m) cruza a borda da banda
%     e comparada com a previsao teorica.
%  c) vetores de referencia para 4 valores DC em sim/vetores_dc_*.txt,
%     comparados bit a bit com o RTL por "make dc"
%
%  Teoria. Com DC a saida {0,1} e uma sequencia de rotacao de densidade
%  rho = (1+x)/2, com raias em k*rho (mod 1) e amplitude |sin(pi k rho)|/(pi k).
%  Perto de uma fracao, rho = a/P + eps/2, onde P e o periodo do ciclo-limite.
%  A raia mais baixa e a de k = P, em P*eps/2: no ponto exato ela esta em DC
%  (silencio na banda) e para |eps| < FS/(OSR*P) ela cai na banda (plato).
%  FS/(4*OSR) = 128 LSB e o caso particular de x = 1/2 (P = 4).
%
%  Resultados em figs/tons_idle_dc.mat, para a comparacao com dither.

clear; close all;

%% ===============================================================
%  PARAMETROS
%  ===============================================================
P_      = le_params();              % fonte unica: rtl/ddsm1_params.vh
W_IN    = P_.W_IN;
W_ACC   = W_IN + P_.GUARD;
FS      = 2^(W_IN-1);
ACC_MAX =  2^(W_ACC-1) - 1;
ACC_MIN = -2^(W_ACC-1);

N   = 2^16;
OSR = 64;
fB  = 1/(2*OSR);                    % borda da banda, em fracao de fs

raiz = fullfile(fileparts(mfilename('fullpath')), '..');
dfig = fullfile(raiz, 'figs');
if ~exist(dfig, 'dir'), mkdir(dfig); end

% Modelo de ruido branco (quantizador +/-1, variancia 1/3, NTF de 1a ordem):
% potencia na banda relativa a FS^2. Preve os 44,8 dB da senoide com A = 0,5.
Pn_teo = pi^2 / (9*OSR^3);
dB = @(p) 10*log10(max(p, 1e-30));

%% ===============================================================
%  a) PANORAMA: grade uniforme de 200 codigos (nao resolve os platos)
%  ===============================================================
M   = 200;
u_g = unique(round(linspace(0, 0.95, M) * FS));
[snr_g, pn_g, ovf_g, em_g] = varre_dc(u_g, N, OSR, FS, ACC_MIN, ACC_MAX);
x_g = u_g / FS;

%% ===============================================================
%  b) ZOOMS EM TORNO DAS FRACOES: +/-400 LSB, passo de 4 LSB
%  ===============================================================
c_nome = {'0', '1/4', '1/3', '1/2'};
c_val  = [ 0,   1/4,   1/3,   1/2 ];
Z      = numel(c_val);
d_z    = -400:4:400;                % deslocamento em LSB (em relacao ao codigo
                                    % mais proximo do centro)
zoom = struct();
for c = 1:Z
    u0 = round(c_val(c) * FS);
    u  = u0 + d_z;
    [snr, pn, ovf, ~, ft] = varre_dc(u, N, OSR, FS, ACC_MIN, ACC_MAX);
    [~, P] = rat((1 + c_val(c)) / 2);         % periodo do ciclo-limite
    zoom(c).nome  = c_nome{c};
    zoom(c).u     = u;
    zoom(c).d     = u - c_val(c)*FS;          % desvio do centro EXATO, em LSB
    zoom(c).snr   = snr;
    zoom(c).pn    = pn;
    zoom(c).ovf   = sum(ovf);
    zoom(c).f     = ft;
    zoom(c).P     = P;
    zoom(c).w_teo = FS / (OSR * P);           % meia-largura prevista, LSB
end

%% Largura medida, por dois caminhos, em cada lado do centro
%  (1) ruido: PRIMEIRA queda de mais de 10 dB entre vizinhos, andando para
%      fora. Nao usar a maior queda da janela: fora do plato ha pontos
%      isolados muito silenciosos (outras fracoes exatas) cuja queda e maior
%      que a da borda. Dentro do plato o ruido so sobe, andando para fora.
%  (2) tom  : primeiro ponto, andando para fora, com f_tom > fB
%  Em ambos a borda e o ponto medio entre os dois pontos vizinhos: +/-2 LSB.
for c = 1:Z
    for lado = [-1 1]
        idx = find(sign(zoom(c).d) == lado);
        [~, o] = sort(abs(zoom(c).d(idx)));
        idx = idx(o);                          % do centro para fora
        dd  = abs(zoom(c).d(idx));
        pd  = dB(zoom(c).pn(idx));
        i = find(pd(1:end-1) - pd(2:end) > 10, 1, 'first');
        if isempty(i), borda_ruido = NaN; else, borda_ruido = (dd(i) + dd(i+1)) / 2; end
        fo = zoom(c).f(idx);
        i  = find(fo > fB, 1, 'first');
        if isempty(i) || i == 1, borda_tom = NaN; else, borda_tom = (dd(i-1) + dd(i)) / 2; end
        if lado < 0
            zoom(c).borda_ruido_neg = borda_ruido; zoom(c).borda_tom_neg = borda_tom;
        else
            zoom(c).borda_ruido_pos = borda_ruido; zoom(c).borda_tom_pos = borda_tom;
        end
    end
end

%% Previsao da altura do plato: soma das raias m*P*eps/2 que caem na banda,
%  cada uma com potencia 8 sin^2(pi m P eps/2) / (pi m P)^2 (relativa a FS^2).
pn_prev = @(e, P) pn_plato_prev(e, P, OSR);   % ver pn_plato_prev.m

%% Fracoes simples no ponto exato (ou no codigo mais proximo)
fr_nome = {'1/8', '1/4', '1/3', '1/2', '5/8', '2/3', '3/4', '7/8'};
fr_val  = [ 1/8,   1/4,   1/3,   1/2,   5/8,   2/3,   3/4,   7/8 ];
u_fr    = round(fr_val * FS);
[snr_fr, pn_fr] = varre_dc(u_fr, N, OSR, FS, ACC_MIN, ACC_MAX);

%% ===============================================================
%  RESUMO NUMERICO
%  ===============================================================
fprintf('--- tons idle com entrada DC (W_IN=%d, W_ACC=%d, N=%d, OSR=%d) ---\n', ...
        W_IN, W_ACC, N, OSR);
fprintf('modelo de ruido branco: %.1f dBFS na banda\n', dB(Pn_teo));
fprintf('\n[panorama] %d codigos, passo ~%.0f LSB -- NAO resolve os platos\n', ...
        numel(u_g), mean(diff(u_g)));
fprintf('  overflows %d | max |media(y)-x| = %.2e | ruido: mediana %.1f, max %.1f dBFS\n', ...
        sum(ovf_g), max(abs(em_g)), dB(median(pn_g)), dB(max(pn_g)));

fprintf('\n[zooms] +/-400 LSB, passo 4 LSB. Meia-largura do plato em LSB:\n');
fprintf('  %4s %2s %9s %17s %17s %8s %13s %13s\n', 'x', 'P', 'prevista', ...
        'ruido (-, +)', 'tom (-, +)', 'FS/4OSR', 'pico medido', 'pico previsto');
for c = 1:Z
    zc = zoom(c);
    dentro = abs(zc.d) < zc.w_teo;
    fprintf('  %4s %2d %9.1f %8.0f %8.0f %8.0f %8.0f %8.0f %8.1f dBFS %8.1f dBFS   ovf=%d\n', ...
            zc.nome, zc.P, zc.w_teo, zc.borda_ruido_neg, zc.borda_ruido_pos, ...
            zc.borda_tom_neg, zc.borda_tom_pos, FS/(4*OSR), ...
            dB(max(zc.pn(dentro))), dB(max(pn_prev(zc.d(dentro)/FS, zc.P))), zc.ovf);
end

% Pior caso real: maximo sobre todos os zooms
pn_all = [zoom.pn]; u_all = [zoom.u]; d_all = [zoom.d];
c_all  = cell2mat(arrayfun(@(c) c*ones(size(zoom(c).u)), 1:Z, 'UniformOutput', false));
[pn_w, iw] = max(pn_all);
u_pior = u_all(iw);
fprintf('\n  pior caso nos zooms: u = %d (x = %.5f), %+.1f LSB de %s, ruido %.1f dBFS (%.1f dB acima do modelo branco)\n', ...
        u_pior, u_pior/FS, d_all(iw), zoom(c_all(iw)).nome, dB(pn_w), dB(pn_w) - dB(Pn_teo));

fprintf('\n  fracoes no ponto exato (ou codigo mais proximo):\n');
for j = 1:numel(fr_val)
    if abs(u_fr(j) - fr_val(j)*FS) < 1e-9, ex = 'exata'; else, ex = 'aprox'; end
    fprintf('  %5s %7d %6s  ruido %7.1f dBFS\n', fr_nome{j}, u_fr(j), ex, dB(pn_fr(j)));
end

%% ===============================================================
%  FIGURAS
%  ===============================================================
cor_med = [0.20 0.45 0.75];
cor_teo = [0.85 0.25 0.15];

%% fig4 -- panorama
f4 = figure('Color', 'w', 'Position', [100 100 820 700]);
subplot(2,1,1);
ok = x_g > 0;                       % em x = 0 o SNR e -Inf por definicao
xt = linspace(0.002, 0.95, 400);
plot(x_g(ok), snr_g(ok), '.-', 'Color', cor_med, 'MarkerSize', 8); hold on;
plot(xt, 10*log10(xt.^2 / Pn_teo), '--', 'Color', cor_teo, 'LineWidth', 1.2);
ylim([-20 160]); xlim([0 0.96]); grid on; box on;
xlabel('entrada DC  x = u / FS'); ylabel('SNR na banda [dB]');
title('PANORAMA -- grade uniforme de ~156 LSB: NAO resolve os platos (64-256 LSB); ver fig5 e fig6');
legend({'medido (grade uniforme)', 'modelo de ruido branco'}, 'Location', 'southeast');
subplot(2,1,2);
plot(x_g, dB(pn_g), '.-', 'Color', cor_med, 'MarkerSize', 8); hold on;
plot([0 0.96], dB(Pn_teo)*[1 1], '--', 'Color', cor_teo, 'LineWidth', 1.2);
ylim([-180 0]); xlim([0 0.96]); grid on; box on;
xlabel('entrada DC  x = u / FS'); ylabel('ruido na banda [dBFS]');
title('Ruido na banda: os picos sao amostras ao acaso de platos estreitos, nao a forma real');
legend({'medido (grade uniforme)', 'modelo de ruido branco'}, 'Location', 'southeast');
set(f4, 'PaperUnits', 'inches', 'PaperPosition', [0 0 8.2 7.0]);
print(f4, '-dpng', '-r150', fullfile(dfig, 'fig4_tons_idle_panorama.png'));

%% fig5 (zooms) e fig6 (sintese): figura_platos.m, a partir do .mat abaixo

save(fullfile(dfig, 'tons_idle_dc.mat'), 'u_g', 'snr_g', 'pn_g', 'zoom', 'u_fr', ...
     'pn_fr', 'fr_nome', 'Pn_teo', 'N', 'OSR', 'FS', 'u_pior', '-v7');

%% ===============================================================
%  c) VETORES DE REFERENCIA PARA O RTL
%  ===============================================================
%  pior caso real (dos zooms), 1/2 exato (ciclo-limite curto), o codigo mais
%  proximo de 1/3 (batimento mais lento que a janela) e -FS (extremo negativo
%  da entrada: maior extensao de sinal de din).
u_vet  = [u_pior, FS/2, round(FS/3), -FS];
motivo = {'pior caso dos zooms', '1/2 exato', 'mais proximo de 1/3', '-FS'};

fprintf('\n--- c) vetores DC gravados em sim/ ---\n');
for j = 1:numel(u_vet)
    y = ddsm1(repmat(u_vet(j), 1, N), FS, ACC_MIN, ACC_MAX);
    if u_vet(j) < 0, tag = sprintf('m%05d', -u_vet(j)); else, tag = sprintf('%05d', u_vet(j)); end
    arq = fullfile(raiz, 'sim', ['vetores_dc_' tag '.txt']);
    grava_vetores(arq, repmat(u_vet(j), 1, N), y, W_IN, W_ACC, ...
                  sprintf('DC=%d x=%.6f', u_vet(j), u_vet(j)/FS));
    fprintf('  vetores_dc_%s.txt  (%s, densidade de 1s = %.6f)\n', tag, motivo{j}, mean(y));
end
