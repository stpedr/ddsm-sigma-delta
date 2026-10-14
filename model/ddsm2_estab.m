%% ddsm2_estab.m
%  Campanha de estabilidade do modulador de 2a ordem (etapa 3 de
%  docs/ddsm2-cifb.md). Integradores largos (ddsm2_params.vh, PROVISORIO),
%  sem saturacao; estouro da faixa provisoria e ALARME, reportado.
%
%  Medidas, por estimulo: excursao de w1 e de w2 separadas, razao entre elas,
%  maior sequencia de bits iguais, alarme. Estimulos: senoide (varredura de
%  amplitude), DC (dos dois sinais, com pontos finos junto a +/-FS) e rampa
%  de fundo de escala. Para comparar, a mesma excursao na 1a ordem (ddsm1.m).
%
%  CRITERIOS, FIXADOS ANTES DA MEDIDA
%  - Envelope normal: excursao de cada integrador com entrada zero, em regime
%    (amostras 1001 em diante de 2^16), vezes MARGEM = 2.
%  - Recuperacao: estimulo por NE = 2^15 amostras, depois NZ = 2^14 de entrada
%    zero. Recupera se os dois estados entram no envelope em ate R = 4096
%    ciclos apos o fim do estimulo e nao saem mais (recuperacao2.m).
%  - Sobrecarga: bissecao na amplitude de pico da senoide (LSB inteiros, ate
%    1 LSB) com esse criterio. So vale se a recuperacao for monotonica na
%    grade da varredura; isso e conferido antes.
%  - Estado travado: saida constante do fim do estimulo ao fim da janela.
%  - Estabilizacao: se o maximo da segunda metade da janela de 2^16 for maior
%    que o da primeira, a excursao "nao estabilizou" e nao e envelope.
%
%  Saida: figs/ddsm2_estab.mat (figuras: figura_estab.m)

clear; close all;

P   = le_params('ddsm2');
FS  = 2^(P.W_IN - 1);
N   = 2^16;
OSR = 64;
K   = 41;
NE  = 2^15;  NZ = 2^14;  KE = 21;     % janela de recuperacao (KE ciclos em NE)
R   = 4096;
MARGEM = 2;

P1 = le_params();                     % 1a ordem, so para comparacao
FS1 = 2^(P1.W_IN-1); W1 = P1.W_IN + P1.GUARD;
AMIN1 = -2^(W1-1); AMAX1 = 2^(W1-1) - 1;

n   = 0:N-1;
ne  = 0:NE-1;
cl  = @(v) max(min(round(v), FS-1), -FS);
fmt = @(v) sprintf('%9.2f', v / FS);

%% ===============================================================
%  0. ENVELOPE NORMAL (entrada zero)
%  ===============================================================
[~, ~, ~, t0] = ddsm2(zeros(1, N), P);
e0  = [max(abs(t0.w1(1001:end))), max(abs(t0.w2(1001:end)))];
env = MARGEM * e0;
fprintf('--- campanha de estabilidade, 2a ordem (W_I1/W_I2 = %d/%d PROVISORIO) ---\n', P.W_I1, P.W_I2);
fprintf('envelope com entrada zero: |w1| <= %d (%.2f FS), |w2| <= %d (%.2f FS); x %d -> criterio\n', ...
        e0(1), e0(1)/FS, e0(2), e0(2)/FS, MARGEM);

%% Funcao de medida de um estimulo (excursao + estabilizacao + alarme)
%  (laco explicito para ficar compativel com MATLAB e Octave)

%% ===============================================================
%  A. SENOIDE: varredura de amplitude
%  ===============================================================
A_v = [0.05:0.05:0.95, 0.97, 0.98, 0.99, 1.00];
NA  = numel(A_v);
S   = struct('A', A_v, 'w1', zeros(NA, 2), 'w2', zeros(NA, 2), 'snr', zeros(1, NA), ...
             'estab', true(1, NA), 'seq', zeros(1, NA), 'al', zeros(1, NA), ...
             'rec', true(1, NA), 'trec', zeros(1, NA), 'trav', false(1, NA), ...
             'acc1', zeros(1, NA));
for j = 1:NA
    u = cl(A_v(j) * FS * sin(2*pi*K*n/N));
    [y, ex, al, tr] = ddsm2(u, P);
    S.w1(j, :) = ex.w1;  S.w2(j, :) = ex.w2;
    S.snr(j) = snr_banda(2*y - 1, N, K, OSR);
    h = N/2;
    S.estab(j) = max(abs(tr.w1(h+1:end))) <= max(abs(tr.w1(1:h))) && ...
                 max(abs(tr.w2(h+1:end))) <= max(abs(tr.w2(1:h)));
    S.seq(j) = maior_sequencia(y);
    S.al(j)  = al.n1 + al.n2;
    % recuperacao
    ur = [cl(A_v(j) * FS * sin(2*pi*KE*ne/NE)), zeros(1, NZ)];
    [yr, ~, alr, trr] = ddsm2(ur, P);
    rr = recuperacao2(trr, yr, NE, env, R);
    S.rec(j) = rr.ok; S.trec(j) = rr.t; S.trav(j) = rr.travado;
    S.al(j) = S.al(j) + alr.n1 + alr.n2;
    % 1a ordem, mesmo estimulo
    u1 = max(min(round(A_v(j) * FS1 * sin(2*pi*K*n/N)), FS1-1), -FS1);
    [~, S.acc1(j)] = ddsm1(u1, FS1, AMIN1, AMAX1);
end

fprintf('\n[A] senoide (K = %d, N = 2^16). Excursao em FS; razao = max|w2| / max|w1|\n', K);
fprintf('%6s %19s %19s %7s %8s %7s %6s %5s %8s %6s %6s\n', 'A', 'w1 [min max]', 'w2 [min max]', ...
        'razao', 'SNR', 'estab', 'seq', 'alarm', 'recup', 't_rec', '1a: acc');
for j = 1:NA
    m1 = max(abs(S.w1(j,:))); m2 = max(abs(S.w2(j,:)));
    fprintf('%6.2f %s%s %s%s %7.2f %6.1f dB %7s %6d %5d %8s %6s %6.2f\n', A_v(j), ...
            fmt(S.w1(j,1)), fmt(S.w1(j,2)), fmt(S.w2(j,1)), fmt(S.w2(j,2)), m2/m1, S.snr(j), ...
            ifelse_ok(S.estab(j)), S.seq(j), S.al(j), ifelse_ok(S.rec(j)), num2str(S.trec(j)), ...
            S.acc1(j)/FS1);
end
[snr_max, jm] = max(S.snr);
fprintf('SNR maximo: %.1f dB em A = %.2f\n', snr_max, A_v(jm));

%% ===============================================================
%  B. DC: os dois sinais, fino junto a +/-FS
%  ===============================================================
x_m = [0 0.1 0.2 0.3 0.4 0.5 0.6 0.7 0.8 0.85 0.9 0.95 0.97 0.98 0.99 0.995 0.998 0.999 0.9995];
u_d = unique([cl(-x_m*FS), cl(x_m*FS), -FS, FS-1]);
ND  = numel(u_d);
D   = struct('u', u_d, 'w1', zeros(ND, 2), 'w2', zeros(ND, 2), 'estab', true(1, ND), ...
             'seq', zeros(1, ND), 'al', zeros(1, ND), 'rec', true(1, ND), 'trec', zeros(1, ND), ...
             'trav', false(1, ND), 'acc1', zeros(1, ND));
for j = 1:ND
    u = u_d(j) * ones(1, N);
    [y, ex, al, tr] = ddsm2(u, P);
    D.w1(j, :) = ex.w1;  D.w2(j, :) = ex.w2;
    h = N/2;
    D.estab(j) = max(abs(tr.w1(h+1:end))) <= max(abs(tr.w1(1:h))) && ...
                 max(abs(tr.w2(h+1:end))) <= max(abs(tr.w2(1:h)));
    D.seq(j) = maior_sequencia(y);
    D.al(j)  = al.n1 + al.n2;
    [yr, ~, alr, trr] = ddsm2([u_d(j) * ones(1, NE), zeros(1, NZ)], P);
    rr = recuperacao2(trr, yr, NE, env, R);
    D.rec(j) = rr.ok; D.trec(j) = rr.t; D.trav(j) = rr.travado;
    D.al(j) = D.al(j) + alr.n1 + alr.n2;
    u1 = max(min(round(u_d(j)/FS * FS1), FS1-1), -FS1);
    [~, D.acc1(j)] = ddsm1(u1 * ones(1, N), FS1, AMIN1, AMAX1);
end

fprintf('\n[B] DC (N = 2^16). Excursao em FS\n');
fprintf('%8s %9s %19s %19s %7s %7s %7s %5s %8s %6s %7s\n', 'u', 'x', 'w1 [min max]', 'w2 [min max]', ...
        'razao', 'estab', 'seq', 'alarm', 'recup', 't_rec', '1a: acc');
for j = 1:ND
    m1 = max(abs(D.w1(j,:))); m2 = max(abs(D.w2(j,:)));
    fprintf('%8d %9.5f %s%s %s%s %7.2f %7s %7d %5d %8s %6s %7.2f\n', u_d(j), u_d(j)/FS, ...
            fmt(D.w1(j,1)), fmt(D.w1(j,2)), fmt(D.w2(j,1)), fmt(D.w2(j,2)), m2/max(m1,1), ...
            ifelse_ok(D.estab(j)), D.seq(j), D.al(j), ifelse_ok(D.rec(j)), num2str(D.trec(j)), ...
            D.acc1(j)/FS1);
end

%% ===============================================================
%  C. RAMPA DE FUNDO DE ESCALA
%  ===============================================================
ur = round(linspace(-FS, FS-1, N));
[yr, exr, alr] = ddsm2(ur, P);
u1r = round(linspace(-FS1, FS1-1, N));
[~, acc1r] = ddsm1(u1r, FS1, AMIN1, AMAX1);
fprintf('\n[C] rampa -FS -> FS-1 em 2^16 amostras\n');
fprintf('  w1 [%s %s]  w2 [%s %s] FS | razao %.2f | alarme %d | 1a ordem: %.2f FS\n', ...
        fmt(exr.w1(1)), fmt(exr.w1(2)), fmt(exr.w2(1)), fmt(exr.w2(2)), ...
        max(abs(exr.w2))/max(abs(exr.w1)), alr.n1 + alr.n2, acc1r/FS1);

%% ===============================================================
%  D. PONTO DE SOBRECARGA (bissecao na amplitude da senoide)
%  ===============================================================
mono = all(diff(double(S.rec)) <= 0);      % OK...OK, FALHA...FALHA
fprintf('\n[D] sobrecarga: recuperacao monotonica na grade? %s\n', ifelse_ok(mono));
if all(S.rec)
    fprintf('  o laco se recuperou em toda a grade, ate A = %.2f (pico = %d LSB, fundo de escala)\n', ...
            A_v(end), FS-1);
    fprintf('  -> nao ha amplitude de senoide sem recuperacao na faixa de entrada representavel\n');
    a_sobre = NaN;
elseif ~mono
    fprintf('  recuperacao NAO monotonica: bissecao invalida; ver tabela A\n');
    a_sobre = NaN;
else
    jf = find(~S.rec, 1, 'first');
    lo = round(A_v(jf-1) * FS); hi = min(round(A_v(jf) * FS), FS);
    while hi - lo > 1
        mi = floor((lo + hi) / 2);
        [yb, ~, ~, tb] = ddsm2([cl(mi * sin(2*pi*KE*ne/NE)), zeros(1, NZ)], P);
        rb = recuperacao2(tb, yb, NE, env, R);
        if rb.ok, lo = mi; else, hi = mi; end
    end
    a_sobre = hi;
    fprintf('  ultima amplitude que recupera: %d LSB (A = %.5f); primeira que nao: %d LSB (A = %.5f)\n', ...
            lo, lo/FS, hi, hi/FS);
end

%% ===============================================================
%  D2. SOBRECARGA EM DC (bissecao no codigo, cada sinal)
%  ===============================================================
%  O limiar depende de R: a excursao de w2 cresce com 1/(1-|x|), e o tempo
%  para voltar ao envelope cresce junto.
lim_dc = zeros(1, 2);
for s = [-1 1]
    ok_u = u_d(D.rec & sign(u_d) == s); nok_u = u_d(~D.rec & sign(u_d) == s);
    if isempty(nok_u), lim_dc((s+3)/2) = NaN; continue; end
    lo = max(abs(ok_u)); hi = min(abs(nok_u));
    while hi - lo > 1
        mi = floor((lo + hi) / 2);
        [yb, ~, ~, tb] = ddsm2([s * mi * ones(1, NE), zeros(1, NZ)], P);
        rb = recuperacao2(tb, yb, NE, env, R);
        if rb.ok, lo = mi; else, hi = mi; end
    end
    lim_dc((s+3)/2) = s * lo;
    fprintf('\n[D2] DC, sinal %+d: ultimo codigo que recupera em R = %d ciclos: %d (x = %.6f); primeiro que nao: %d\n', ...
            s, R, s*lo, s*lo/FS, s*hi);
end

%% ===============================================================
%  D3. REFINAMENTO DO CRITERIO DE ESTABILIZACAO (posterior a medida)
%  ===============================================================
%  O criterio "maximo da 2a metade > maximo da 1a" marcou pontos sem motivo
%  fisico para crescer. Aqui ele e quantificado: para cada ponto marcado, a
%  excursao e medida numa janela 4 vezes maior (2^18). Cresceu mais de 1% ->
%  crescimento real; senao, era o pico caindo em fase diferente.
N4 = 4 * N; n4 = 0:N4-1;
fprintf('\n[D3] pontos marcados como "nao estabilizou": janela 2^18 x 2^16\n');
fprintf('%10s %10s %12s %12s %10s\n', 'estimulo', 'valor', 'max|w2| 2^16', 'max|w2| 2^18', 'veredito');
S.cresce = false(1, NA); D.cresce = false(1, ND);
for j = find(~S.estab)
    u4 = cl(A_v(j) * FS * sin(2*pi*(4*K)*n4/N4));
    [~, e4] = ddsm2(u4, P);
    m16 = max(abs(S.w2(j,:))); m18 = max(abs(e4.w2));
    m16b = max(abs(S.w1(j,:))); m18b = max(abs(e4.w1));
    S.cresce(j) = m18 > 1.01*m16 || m18b > 1.01*m16b;
    fprintf('%10s %10.2f %12.2f %12.2f %10s\n', 'senoide', A_v(j), m16/FS, m18/FS, ...
            ifelse_txt2(S.cresce(j), 'CRESCE', 'limitado'));
end
% Os que crescem em 2^18: terceiro nivel, 2^20 (16 x). Se o maximo parar de
% crescer, a excursao e limitada mas exige janela longa para ser atingida.
N20 = 16 * N; n20 = 0:N20-1;
S.m20 = NaN(1, NA);
for j = find(S.cresce)
    [~, e20] = ddsm2(cl(A_v(j) * FS * sin(2*pi*(16*K)*n20/N20)), P);
    S.m20(j) = max(abs(e20.w2));
    fprintf('%10s %10.2f   max|w2|: 2^16 %.2f | 2^18 (ver acima) | 2^20 %.2f FS\n', 'senoide', ...
            A_v(j), max(abs(S.w2(j,:)))/FS, S.m20(j)/FS);
end
for j = find(~D.estab)
    [~, e4] = ddsm2(u_d(j) * ones(1, N4), P);
    m16 = max(abs(D.w2(j,:))); m18 = max(abs(e4.w2));
    m16b = max(abs(D.w1(j,:))); m18b = max(abs(e4.w1));
    D.cresce(j) = m18 > 1.01*m16 || m18b > 1.01*m16b;
    fprintf('%10s %10d %12.2f %12.2f %10s\n', 'DC', u_d(j), m16/FS, m18/FS, ...
            ifelse_txt2(D.cresce(j), 'CRESCE', 'limitado'));
end

%% ===============================================================
%  E. RESUMO
%  ===============================================================
todos_w1 = [S.w1; D.w1; exr.w1]; todos_w2 = [S.w2; D.w2; exr.w2];
fprintf('\n[E] resumo\n');
fprintf('  pior excursao, todos os estimulos: w1 [%d %d] (%d bits), w2 [%d %d] (%d bits)\n', ...
        min(todos_w1(:,1)), max(todos_w1(:,2)), bits_com_sinal(todos_w1(:)), ...
        min(todos_w2(:,1)), max(todos_w2(:,2)), bits_com_sinal(todos_w2(:)));
fprintf('  alarmes (faixa provisoria de %d/%d bits): %d\n', P.W_I1, P.W_I2, sum(S.al) + sum(D.al) + alr.n1 + alr.n2);
fprintf('  estados travados: senoide %d, DC %d\n', sum(S.trav), sum(D.trav));
fprintf('  excursoes que nao estabilizaram: senoide %d, DC %d\n', sum(~S.estab), sum(~D.estab));
fprintf('  ... das quais crescem de fato na janela 2^18: senoide %d, DC %d\n', sum(S.cresce), sum(D.cresce));

raiz = fullfile(fileparts(mfilename('fullpath')), '..');
save(fullfile(raiz, 'figs', 'ddsm2_estab.mat'), 'S', 'D', 'exr', 'acc1r', 'e0', 'env', ...
     'MARGEM', 'R', 'NE', 'NZ', 'a_sobre', 'mono', 'lim_dc', 'FS', 'N', 'K', 'OSR', '-v7');
