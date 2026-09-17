# CLAUDE.md — contexto do projeto

## O que é

Modulador sigma-delta **digital** de 1ª ordem (DDSM), primeiro bloco de um projeto
de circuito integrado com tapeout pelo programa UNIC-CASS (IEEE CASS), usando
fluxo aberto RTL-to-GDSII.

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
- RTL em Verilog (`rtl/ddsm1.v`).
- Testbench de comparação bit a bit (`tb/tb_ddsm1.v`).

Pendente imediato: rodar o testbench e fechar a comparação bit a bit.

## Resultados medidos no golden model

- SNR na banda, OSR = 64, A = 0,5: **46,6 dB** (teoria prevê ~44,8 dB a -6 dBFS).
- Varredura de OSR: 38,4 / 46,2 / 54,6 / 64,6 dB para 32 / 64 / 128 / 256.
  Média de 8,7 dB por oitava contra 9 dB teóricos — noise shaping confirmado.
- Excursão do acumulador: segue exatamente `|acc|max = FS·(1+A)`, com teto
  absoluto em 2·FS. É a razão estrutural de o 1ª ordem ser incondicionalmente
  estável: a realimentação de fundo de escala sempre domina o estado.
- Overflows: zero em todos os estímulos com W_ACC = 18.

## Próximos passos

1. Rodar `make` e confirmar zero divergências.
2. Lint com Verilator; síntese exploratória com Yosys (esperado: poucas centenas
   de células).
3. Gerar vetores também para entradas DC e rampa, não só senoide.
4. Medir tons idle com entrada DC (justifica o dither por LFSR).
5. Migrar o testbench para cocotb.
6. Estender para ordem 2 e 3, e implementar as outras duas arquiteturas.

## Armadilhas já identificadas

- **Amostragem coerente na FFT.** O tom precisa de um número inteiro e primo de
  ciclos na janela. Sem isso o vazamento cobre o piso de ruído e o SNR sai alto
  e falso.
- **Somar largo antes de saturar.** Se a soma acontecer já em W_ACC bits, o
  valor dá a volta antes de a saturação vê-lo, e a lógica nunca atua.
- **Realimentação vale ±FS, não ±1 LSB.** Erro clássico na passagem de ponto
  flutuante para ponto fixo.
- **Reset síncrono precisa de bordas de clock** antes de ser solto, senão os
  registradores ficam em `x`.
- **Latência de 1 ciclo** já é absorvida pelo testbench; não aplicar
  deslocamento adicional.

## Gestão

Quadro Trello "SigmaDelta Digital CI Amazônia", 6 épicos. Este trabalho cobre os
cards 2.2 (golden model error-feedback), 3.1/3.2/3.3 (RTL) e 4.1 (comparação
bit-exata).
