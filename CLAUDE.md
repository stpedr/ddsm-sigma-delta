# CLAUDE.md — contexto do projeto

## O que é

Modulador sigma-delta **digital** de 1ª ordem (DDSM), primeiro bloco de um projeto
de circuito integrado com tapeout pelo programa UNIC-CASS (IEEE CASS), usando
fluxo aberto RTL-to-GDSII. Prazo de submissão: **10 de novembro de 2026**.

Não é um ΔΣ de ADC: não há filtro de laço analógico. Entrada digital de N bits,
saída PDM de 1 bit, totalmente síncrono e sintetizável.

Pesquisa acadêmica inicial em microeletrônica, sem aplicação-alvo fixa. A
contribuição pretendida não é o modulador em si (livro-texto), e sim a
caracterização comparativa de três arquiteturas — error-feedback, CIFB e
MASH 1-1-1 — medida em silício num PDK aberto.

## Contrato congelado (não alterar sem refazer os vetores)

| parâmetro | valor |
|---|---|
| `W_IN` | 16 bits, com sinal, complemento de dois |
| `GUARD` | 2 |
| `W_ACC` | 18 bits |
| realimentação | ±FS, com FS = 2^15 = 32768 |
| overflow | saturação, nunca wrap-around |
| reset | síncrono, ativo baixo; `acc = 0`, saída = 0 |
| latência | 1 ciclo |
| saída | 1 bit, {0,1} |

`W_IN` e `GUARD` existem num único arquivo, `rtl/ddsm1_params.vh`. O RTL e o
testbench fazem `` `include`` dele; o MATLAB lê com `model/le_params.m`.

## Estado atual

### Estrutura

- `rtl/ddsm1.v`: RTL, com extensão de sinal explícita na soma do acumulador
  (`acc_sx`, `din_sx`).
- `tb/tb_ddsm1.v`: comparação bit a bit. Lê direto `sim/vetores_*.txt`
  (`+VEC=`), tira N do arquivo e **recusa** vetores cujo cabeçalho
  `W_IN`/`W_ACC` difira do `.vh`.
- `model/ddsm1.m`: **única** implementação do laço do golden model (ponto fixo).
  `ddsm1_fixo.m` (senoide, excursão, vetores), `figuras_validacao.m`,
  `tons_idle_dc.m` e `varre_dc.m` a chamam.
- `model/grava_vetores.m`: único lugar que define o formato dos vetores.
- `model/snr_banda.m` (senoide) e `model/snr_banda_dc.m` (DC) medem o SNR na
  banda; `model/tom_idle.m` mede a frequência do tom idle;
  `model/pn_plato_prev.m` prevê a altura dos platôs.
- `docs/tons-idle.md`: registro técnico da caracterização dos tons idle.

### Verificação (RTL × golden model)

| verificação | resultado |
|---|---|
| `make` (senoide, 65 536 amostras) | 0 divergências, 0 overflows, densidade 0,500015 |
| `make dc` (5 vetores DC: 32259, −252, 16384, 10923, −32768) | 5/5, 0 divergências, 0 overflows |
| controles negativos | bit invertido detectado no índice exato; cabeçalho `W_ACC=19` recusado; arquivo ausente acusado |
| `make lint` (Verilator 5.032 `-Wall`) | 0 avisos |
| `make synth` (Yosys 0.52) | 260 células: 20 flip-flops `$_SDFFE_PN0P_` (18 acc + saída + ovf), 240 de lógica |
| equivalência sequencial (Yosys `equiv_simple -seq 5` + `equiv_induct`) | provada a cada mudança de RTL; o controle negativo falha nos bits esperados |

## Resultados medidos no golden model

### Senoide (`ddsm1_fixo.m`, `figuras_validacao.m`)

- SNR na banda, OSR = 64, A = 0,5: **46,6 dB** (modelo de ruído branco: 44,8 dB).
- OSR 32 / 64 / 128 / 256: 38,9 / 46,6 / 54,9 / 64,9 dB. Inclinação por
  regressão em log2(OSR): **8,63 dB/oitava** contra 9,0 teóricos (desvio 4,1%).
- Excursão do acumulador: `|acc|max = FS·(1+A)` para senoide e DC, com teto em
  2·FS (rampa: 65 535 LSB). Mínimo necessário: 17 bits; com W_ACC = 18 sobra 1
  bit de margem. Overflows: zero em todos os estímulos.

### Tons idle com entrada DC (`tons_idle_dc.m`; detalhes em `docs/tons-idle.md`)

N = 2^16, OSR = 64. Modelo de ruído branco: π²/(9·OSR³) = **−53,8 dBFS** na banda.

- **Frações exatas são silenciosas na banda.** Em 1/8, 1/4, 1/2, 5/8, 3/4 e 7/8
  exatos o ruído vai de −221,8 a −246,5 dBFS (zero numérico).
- **Os tons ficam num platô em volta da fração**, com meia-largura
  **FS/(OSR·P)**, onde P é o período do ciclo-limite (denominador de
  ρ = (1+x)/2). A raia mais baixa fica em P·|ε|/2 e cai na banda dentro do platô.

| centro | P | prevista [LSB] | medida, ruído (−/+) | medida, tom (−/+) | pico medido | pico previsto |
|---|---|---|---|---|---|---|
| 0 | 2 | 256,0 | 258 / 258 | 258 / 258 | −39,3 dBFS | −39,3 dBFS |
| 1/4 | 8 | 64,0 | 66 / 66 | 66 / 66 | −51,7 dBFS | −51,7 dBFS |
| 1/3 | 3 | 170,7 | 170 / 170 | 170 / 170 | −42,8 dBFS | −42,8 dBFS |
| 1/2 | 4 | 128,0 | 130 / 130 | 130 / 130 | −45,4 dBFS | −45,4 dBFS |
| −1 | 1 | 512,0 | — / 514 | — / 514 | −33,2 dBFS | −33,2 dBFS |
| +1 | 1 | 512,0 | 511 / — | 511 / — | −33,2 dBFS | −33,2 dBFS |

  Passo de 4 LSB (resolução da borda ±2 LSB). Janela de ±400 LSB nos centros
  internos e de 0 a 1024 LSB para dentro da faixa em ±1, onde só há um lado.
  Nos extremos não há saturação (0 ciclos).
- **Pior caso em toda a faixa:** u = 32 259 (509 LSB abaixo de +1; o simétrico
  −32 260 dá o mesmo), com **−33,2 dBFS**, 20,6 dB acima do modelo branco.
  "Toda a faixa" é inferência da regra: P = 1 é o menor período, e a altura de
  borda cresce quando P diminui.
- Sem os extremos: u = ±252, na borda do platô de x = 0, com −39,3 dBFS
  (14,5 dB acima do modelo branco).
- Panorama (200 códigos uniformes, passo ~156 LSB): mediana −70,3 dBFS. Essa
  grade **não resolve** os platôs; serve só como visão geral.

Figuras: `figs/fig6_largura_platos.png` (principal: largura medida × prevista),
`figs/fig5_platos_tons_idle.png` (zooms), `figs/fig4_tons_idle_panorama.png`.

## Próximos passos

1. **Dither por LFSR: varrer a amplitude.**
   - LFSR com polinômio primitivo, `DITHER_EN` e `DITHER_AMP` parametrizáveis,
     injetado antes do quantizador.
   - Amplitude em passos logarítmicos, de 1 LSB até uma fração significativa de
     FS. 1 LSB quase nunca muda a decisão, porque o degrau do quantizador é
     2·FS.
   - Para cada amplitude, medir a profundidade dos platôs (com os zooms) e a
     degradação do SNR com senoide a −6 dBFS. Entregar a curva de compromisso
     com os dois eixos.
   - **Requisito de aceitação:** o LFSR gera a mesma sequência, com a mesma
     semente, no MATLAB/Octave e no Verilog, e a comparação bit a bit continua
     valendo com o dither ligado.
   - Se nenhuma amplitude resolver os platôs a custo aceitável em 1ª ordem com
     1 bit, documentar isso como resultado.
2. Vetores de rampa.
3. Migrar o testbench para cocotb.
4. Estender para ordem 2 e 3, e implementar as outras duas arquiteturas.

## Armadilhas já identificadas

- **Amostragem coerente na FFT.** O tom precisa de um número inteiro e primo de
  ciclos na janela. Sem isso o vazamento cobre o piso de ruído e o SNR sai alto
  e falso.
- **SNR com entrada DC não tem tom.** `snr_banda.m` soma o sinal nos bins do
  tom (K±3) e exclui o bin 0. Com DC use `snr_banda_dc.m`: sinal = x²; ruído =
  potência de y − x na banda **incluindo o bin 0**; Hann normalizada por N·Σw²;
  soma bilateral (DC c → c², seno A → A²/2).
- **Não esperar tons *nas* frações simples.** Eles ficam num platô de
  ±FS/(OSR·P) em volta: 64 a 512 LSB para P = 8 a 1.
- **Grade de varredura mais grossa que o platô produz aliasing.** Use zooms com
  passo bem menor que FS/(OSR·P) em torno das frações.
- **Detector de borda: primeira queda (> 10 dB, andando para fora), não a
  maior.** Fora dos platôs há pontos isolados muito silenciosos (outras frações
  exatas) cuja queda é maior que a da borda.
- **"Tom dominante" não é o argmax.** As harmônicas m·P·|ε|/2 têm amplitudes
  quase iguais; `tom_idle.m` usa a raia mais baixa até 3 dB abaixo da máxima.
- **Somar largo antes de saturar.** Se a soma acontecer já em W_ACC bits, o
  valor dá a volta antes de a saturação vê-lo, e a lógica nunca atua.
- **Realimentação vale ±FS, não ±1 LSB.** Erro clássico na passagem de ponto
  flutuante para ponto fixo.
- **Reset síncrono precisa de bordas de clock** antes de ser solto, senão os
  registradores ficam em `x`.
- **Latência de 1 ciclo** já é absorvida pelo testbench; não aplicar
  deslocamento adicional.
- **Número duplicado em dois lugares.** Já causou o `din.hex` ausente e o
  GUARD = 3 no modelo contra 2 no RTL. Parâmetros só em `rtl/ddsm1_params.vh`;
  formato dos vetores só em `grava_vetores.m`; laço só em `ddsm1.m`. Não
  reintroduzir cópias.

## Rodar o golden model sem MATLAB

Não há MATLAB na máquina de desenvolvimento. Os `.m` rodam sem alteração no
Octave 8.4 da imagem Docker local `ddsm-octave:local` (Ubuntu 24.04 + `octave`,
`octave-signal`, `gnuplot-nox`, `fonts-freefont-otf`, `ghostscript`). Antes dos
scripts: `pkg load signal` (para `hann`), `graphics_toolkit('gnuplot')` com
figuras invisíveis e um substituto de `xline` fora do repo. Os scripts do
projeto continuam MATLAB puro; em figuras novas use só `plot`/`print` (o Octave
não tem `xline` nem `exportgraphics`) e títulos de uma linha (títulos em cell
array quebram no gnuplot). `tons_idle_dc.m` leva ~15 min no Octave; as figuras
5 e 6 saem do `.mat` por `figura_platos.m`, sem refazer a simulação.

## Gestão

Quadro Trello "SigmaDelta Digital CI Amazônia", 6 épicos. Este trabalho cobre os
cards 2.2 (golden model error-feedback), 3.1/3.2/3.3 (RTL) e 4.1 (comparação
bit-exata, concluída).
