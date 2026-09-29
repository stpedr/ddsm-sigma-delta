%% figuras_validacao.m
%  Gera as tres figuras de validacao do DDSM de 1a ordem, com as curvas
%  teoricas sobrepostas as medidas.
%
%  Fig. 1 — SQNR x OSR, contra a reta de 9 dB/oitava
%  Fig. 2 — densidade espectral, contra a reta de 20 dB/decada
%  Fig. 3 — excursao do acumulador, contra a reta FS*(1+A)
%
%  Salva PNG (300 dpi) e PDF vetorial em figs/.
%  Rode DEPOIS de ddsm1_fixo.m (precisa de u, y, W_IN, FS, N, K no workspace).

if ~exist('y','var') || ~exist('FS','var')
    error('Rode ddsm1_fixo.m primeiro.');
end
if ~exist('figs','dir'), mkdir('figs'); end

LW = 1.4;  MS = 7;  FSZ = 11;   % espessura, marcador, fonte

%% ===============================================================
%  FIG. 1 — SQNR x OSR
%  ===============================================================
%  O OSR nao e parametro do modulador: e a banda em que se integra o
%  ruido. Por isso as quatro medidas saem do MESMO bitstream.

y_bip = 2*y - 1;
P_all = abs(fft(y_bip .* hann(N).')).^2;  P_all = P_all(1:N/2);
bin_tom = (K+1) + (-3:3);

osr_v  = [32 64 128 256];
snr_v  = zeros(size(osr_v));
for j = 1:numel(osr_v)
    bb = 2 : floor(N/(2*osr_v(j)));
    Ps = sum(P_all(bin_tom));
    Pn = sum(P_all(bb)) - sum(P_all(intersect(bin_tom, bb)));
    snr_v(j) = 10*log10(Ps/Pn);
end

% Reta teorica: 9 dB por oitava (30 dB/decada), ancorada no primeiro ponto.
% Para 1a ordem: SQNR crescente com 30*log10(OSR).
teo = snr_v(1) + 30*log10(osr_v/osr_v(1));

% Inclinacao medida por regressao em log2(OSR)
p = polyfit(log2(osr_v), snr_v, 1);

f1 = figure('Color','w','Position',[100 100 560 420]);
semilogx(osr_v, teo, '--', 'LineWidth', LW, 'Color', [0.55 0.55 0.55]); hold on;
semilogx(osr_v, snr_v, 'o-', 'LineWidth', LW, 'MarkerSize', MS, ...
         'MarkerFaceColor', 'w');
grid on; box on;
set(gca,'XTick',osr_v,'XTickLabel',{'32','64','128','256'},'FontSize',FSZ);
xlabel('OSR'); ylabel('SQNR na banda [dB]');
title('Ganho de SQNR com a sobreamostragem');
legend({'teorico: 9 dB/oitava', ...
        sprintf('medido: %.1f dB/oitava', p(1))}, ...
       'Location','northwest','FontSize',FSZ-1);
xlim([24 340]);

exportgraphics(f1,'figs/fig1_sqnr_osr.png','Resolution',300);
exportgraphics(f1,'figs/fig1_sqnr_osr.pdf','ContentType','vector');

%% ===============================================================
%  FIG. 2 — DENSIDADE ESPECTRAL
%  ===============================================================
%  A reta de 20 dB/decada e a assinatura da NTF de 1a ordem.
%  O achatamento perto de Nyquist e esperado: |NTF| = 2*sen(pi*f) varia
%  apenas 3 dB entre f = 0,25 e f = 0,5.

f_n  = (0:N/2-1)/N;
PdB  = 10*log10(P_all / max(P_all));

% Reta de referencia ancorada em f = 1e-3, dentro da regiao onde vale
idx_anc = round(1e-3*N);
anc     = mean(PdB(max(idx_anc-50,2):idx_anc+50));
f_ref   = logspace(-3.2, -0.8, 50);
ref     = anc + 20*log10(f_ref/1e-3);

f2 = figure('Color','w','Position',[100 100 620 420]);
semilogx(f_n(2:end), PdB(2:end), 'LineWidth', 0.5, ...
         'Color', [0.20 0.45 0.75]); hold on;
semilogx(f_ref, ref, '--', 'LineWidth', LW+0.3, 'Color', [0.85 0.25 0.15]);
xline(1/(2*OSR), ':', 'Color', [0.3 0.3 0.3], 'LineWidth', LW);
grid on; box on; set(gca,'FontSize',FSZ);
xlabel('frequencia normalizada  f/f_s'); ylabel('PSD normalizada [dB]');
title(sprintf('Noise shaping de 1a ordem (W_{IN}=%d, W_{ACC}=%d)', ...
      W_IN, W_ACC));
legend({'PSD da saida','referencia: 20 dB/decada', ...
        sprintf('borda da banda (OSR=%d)',OSR)}, ...
       'Location','northwest','FontSize',FSZ-1);
ylim([-140 5]);

exportgraphics(f2,'figs/fig2_psd.png','Resolution',300);
exportgraphics(f2,'figs/fig2_psd.pdf','ContentType','vector');

%% ===============================================================
%  FIG. 3 — EXCURSAO DO ACUMULADOR
%  ===============================================================
%  Resultado mais interessante: a excursao segue FS*(1+A) exatamente,
%  para senoide E para DC. Nao e ajuste empirico — decorre de a
%  realimentacao de fundo de escala sempre dominar o estado, que e a
%  razao estrutural de o 1a ordem ser incondicionalmente estavel.

A_v  = [0.1 0.3 0.5 0.7 0.9 0.95];
D_v  = [0 0.25 0.5 0.75 0.9 0.99];
acc_sin = zeros(size(A_v));
acc_dc  = zeros(size(D_v));
nn = 0:N-1;

for j = 1:numel(A_v)
    ui = max(min(round(A_v(j)*FS*sin(2*pi*K*nn/N)), FS-1), -FS);
    [~, acc_sin(j), ~] = ddsm1(ui, FS, ACC_MIN, ACC_MAX);
end
for j = 1:numel(D_v)
    ui = repmat(round(D_v(j)*(FS-1)), 1, N);
    [~, acc_dc(j), ~] = ddsm1(ui, FS, ACC_MIN, ACC_MAX);
end

a_teo = linspace(0, 1, 100);

f3 = figure('Color','w','Position',[100 100 560 420]);
plot(a_teo, 1 + a_teo, '--', 'LineWidth', LW, 'Color', [0.55 0.55 0.55]);
hold on;
plot(A_v, acc_sin/FS, 'o', 'LineWidth', LW, 'MarkerSize', MS, ...
     'MarkerFaceColor','w');
plot(D_v, acc_dc/FS,  's', 'LineWidth', LW, 'MarkerSize', MS, ...
     'MarkerFaceColor','w');
yline(2, ':', 'LineWidth', LW, 'Color', [0.85 0.25 0.15]);
grid on; box on; set(gca,'FontSize',FSZ);
xlabel('amplitude da entrada  (fracao do fundo de escala)');
ylabel('|acc|_{max} / FS');
title('Excursao do acumulador e limite estrutural');
legend({'teorico: 1 + A','entrada senoidal','entrada DC', ...
        'teto absoluto: 2 x FS'}, 'Location','northwest','FontSize',FSZ-1);
xlim([0 1.02]); ylim([0.9 2.2]);

exportgraphics(f3,'figs/fig3_acc.png','Resolution',300);
exportgraphics(f3,'figs/fig3_acc.pdf','ContentType','vector');

%% ===============================================================
%  RESUMO NUMERICO
%  ===============================================================
fprintf('\n--- resumo para o relatorio ---\n');
fprintf('inclinacao medida : %.2f dB/oitava (teorico 9,0)\n', p(1));
fprintf('desvio            : %.1f %%\n', abs(p(1)-9)/9*100);
for j = 1:numel(osr_v)
    fprintf('OSR %4d -> SQNR %.1f dB\n', osr_v(j), snr_v(j));
end
fprintf('excursao: max desvio de FS*(1+A) = %.4f LSB\n', ...
        max(abs(acc_sin - FS*(1+A_v))));
fprintf('\nfiguras salvas em figs/ (PNG 300 dpi e PDF vetorial)\n');

%% ---------------------------------------------------------------
%  Funcao local (copia da de ddsm1_fixo.m, para o script ser autonomo)
%  ---------------------------------------------------------------
function [y, acc_max_abs, n_ovf] = ddsm1(u, FS, ACC_MIN, ACC_MAX)
    N = numel(u); y = zeros(1,N);
    acc = 0; yfb = -FS; acc_max_abs = 0; n_ovf = 0;
    for i = 1:N
        acc_ext = acc + (u(i) - yfb);
        if     acc_ext > ACC_MAX, acc = ACC_MAX; n_ovf = n_ovf + 1;
        elseif acc_ext < ACC_MIN, acc = ACC_MIN; n_ovf = n_ovf + 1;
        else,  acc = acc_ext;
        end
        y(i) = double(acc >= 0);
        if y(i) == 1, yfb = FS; else, yfb = -FS; end
        acc_max_abs = max(acc_max_abs, abs(acc));
    end
end
