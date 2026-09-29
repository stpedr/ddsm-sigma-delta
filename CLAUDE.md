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

## Estado atual

Concluído:

- Golden model em ponto flutuante (`model/ddsm1_snr.m`), validado contra a teoria.
- Golden model em ponto fixo (`model/ddsm1_fixo.m`), que é a referência definitiva.
  GUARD corrigido de 3 para 2 (W_ACC = 18), SNR inalterado.
  **Atenção:** em 29/09 o arquivo em disco ainda tinha `GUARD = 3`; conferir que
  a correção foi salva antes de gerar novos vetores.
- Figuras de validação (`model/figuras_validacao.m`): SQNR × OSR, PSD e
  excursão do acumulador, com as curvas teóricas sobrepostas.
- RTL em Verilog (`rtl/ddsm1.v`).
- Testbench de comparação bit a bit (`tb/tb_ddsm1.v`).
- **Comparação bit a bit fechada:** 65.536 amostras, 0 divergências,
  0 overflows, densidade de uns 0,500015. Controle negativo confirmado:
  1 bit invertido em `yref.hex` → 1 divergência detectada em i = 999.
- Síntese exploratória (Yosys): **260 células**, sendo 20 flip-flops
  (`$_SDFFE_PN0P_`: 18 do acumulador + saída + ovf) e 240 de lógica.
- Lint (Verilator `-Wall`): **zero avisos**. Os 2 `WIDTHEXPAND` da soma do
  acumulador foram resolvidos com extensão de sinal explícita (`acc_sx`,
  `din_sx`), em vez de depender das regras de largura de contexto do Verilog.
  Equivalência sequencial com a versão anterior provada no Yosys (82/82
  `$equiv`); controle negativo (din estendido com zeros) deixa sem prova
  exatamente os bits 16–19 de `acc_ext`.

## Resultados medidos no golden model

- SNR na banda, OSR = 64, A = 0,5: **46,6 dB** (teoria prevê ~44,8 dB a -6 dBFS).
- Varredura de OSR: 38,9 / 46,6 / 54,9 / 64,9 dB para 32 / 64 / 128 / 256.
  Inclinação por regressão em log2(OSR): **8,63 dB/oitava** contra 9,0 teóricos
  (desvio de 4,1%) — noise shaping de 1ª ordem confirmado.
- Excursão do acumulador: segue exatamente `|acc|max = FS·(1+A)`, para senoide
  e para DC, com teto absoluto em 2·FS. É a razão estrutural de o 1ª ordem ser
  incondicionalmente estável: a realimentação de fundo de escala sempre domina
  o estado.
- Overflows: zero em todos os estímulos com W_ACC = 18.

## Próximos passos

1. **Tons idle com entrada DC.** Varrer ~200 valores DC entre 0 e 0,95·FS no
   golden model, medir SNR na banda em cada um e plotar SNR × DC (esperados
   vales em frações racionais simples: 1/2, 1/4, 1/3). Exportar vetores para
   3–4 valores DC, incluindo um pior caso, e fechar a comparação bit a bit
   do RTL também nesse regime.
2. **Dither por LFSR** (só depois de 1, para ter o antes e depois).
   Polinômio primitivo, amplitude de 1 LSB, injetado antes do quantizador,
   habilitado por parâmetro `DITHER_EN`. Primeiro no MATLAB, depois no RTL,
   com a mesma semente e a mesma sequência nos dois (equivalência bit a bit).
   Repetir a varredura DC com dither e quantificar o trade-off: quanto os
   vales sobem e quanto o piso médio piora.
3. Vetores de rampa.
4. Migrar o testbench para cocotb.
5. Estender para ordem 2 e 3, e implementar as outras duas arquiteturas.

## Armadilhas já identificadas

- **Amostragem coerente na FFT.** O tom precisa de um número inteiro e primo de
  ciclos na janela. Sem isso o vazamento cobre o piso de ruído e o SNR sai alto
  e falso.
- **SNR com entrada DC não tem tom.** A rotina `snr_banda` da senoide soma a
  potência do sinal nos bins do tom (K±3); com DC o sinal está no bin 0, que
  ela exclui da banda. Adaptar a medida, não reusar a função sem pensar.
- **Somar largo antes de saturar.** Se a soma acontecer já em W_ACC bits, o
  valor dá a volta antes de a saturação vê-lo, e a lógica nunca atua.
- **Realimentação vale ±FS, não ±1 LSB.** Erro clássico na passagem de ponto
  flutuante para ponto fixo.
- **Reset síncrono precisa de bordas de clock** antes de ser solto, senão os
  registradores ficam em `x`.
- **Latência de 1 ciclo** já é absorvida pelo testbench; não aplicar
  deslocamento adicional.
- **`din.hex` e `yref.hex` são gitignored.** Regenerar com `model/exporta_hex.m`
  ou a partir de `sim/vetores_ddsm1.txt` (coluna 1 → `mod(u, 2^16)` em `%04X`;
  coluna 2 → `yref.hex`). Os dois precisam estar em `sim/` antes do `make`.

## Gestão

Quadro Trello "SigmaDelta Digital CI Amazônia", 6 épicos. Este trabalho cobre os
cards 2.2 (golden model error-feedback), 3.1/3.2/3.3 (RTL) e 4.1 (comparação
bit-exata, concluída).
