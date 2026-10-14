# DDSM — Modulador Sigma-Delta Digital

Moduladores sigma-delta digitais em Verilog, com golden model em ponto fixo
(MATLAB/Octave) e verificação bit a bit. Primeiro bloco de um projeto de
circuito integrado com tapeout pelo programa UNIC-CASS. Contrato, estado e
armadilhas conhecidas: `CLAUDE.md`.

## Estrutura

```
rtl/     Verilog sintetizável; parâmetros do contrato em ddsm1_params.vh
tb/      testbench de comparação bit a bit (lê sim/vetores_*.txt)
model/   golden model (ponto flutuante e ponto fixo), varreduras e figuras
sim/     vetores de referência gerados pelo golden model (versionados)
figs/    figuras e dados das medidas
docs/    registros técnicos (tons-idle.md, ddsm2-cifb.md)
env/     ambiente do golden model sem MATLAB (Dockerfile, init do Octave)
```

## Dependências

- Icarus Verilog, Verilator e Yosys, para simulação, lint e síntese
- Docker, para rodar o golden model no Octave; ou MATLAB, para rodá-lo direto
- Linux ou WSL2 para os scripts de `env/` e o Makefile

Versões usadas nas medidas registradas: Icarus 12.0, Verilator 5.032,
Yosys 0.52, Octave 8.4.0 com signal 1.4.5 (`env/versoes.txt`).

## Fluxo

### 1. Golden model

Com Octave em Docker, a partir da raiz do repo:

```
make imagem-octave                  # uma vez: constroi ddsm-octave:local
env/octave.sh ddsm1_fixo            # senoide, excursao e sim/vetores_ddsm1.txt
env/octave.sh "ddsm1_fixo; figuras_validacao"   # figuras 1 a 3
env/octave.sh tons_idle_dc          # tons idle, vetores DC (~15 min)
env/octave.sh figura_platos         # figuras 5 e 6 a partir do .mat
env/octave.sh ddsm2_ntf             # 2a ordem: NTF e figura 10
```

Com MATLAB, rode os mesmos scripts a partir de `model/`. Os scripts usam só
funções disponíveis nos dois; `env/octave/` contém o que o Octave precisa a
mais e não deve entrar no path do MATLAB.

Os vetores são gravados direto em `sim/`, no formato definido em
`model/grava_vetores.m`. Não há etapa de conversão.

### 2. Verificação do RTL

```
make           # senoide: 65 536 amostras, comparacao bit a bit
make dc        # todos os sim/vetores_dc_*.txt
make lint      # Verilator -Wall
make synth     # Yosys: contagem de celulas
```

Resultado esperado: 0 divergências e 0 overflows em todos os vetores, e lint
sem avisos. O testbench recusa vetores cujo cabeçalho (`W_IN`, `W_ACC`) não
bata com `rtl/ddsm1_params.vh`.

## Contrato do bloco

Ver `CLAUDE.md`. Os parâmetros estão congelados: alterá-los invalida os vetores
de referência, que precisam ser regerados.
