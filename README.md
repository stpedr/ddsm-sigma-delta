# DDSM — Modulador Sigma-Delta Digital

Modulador sigma-delta digital de 1ª ordem em Verilog, com golden model em
MATLAB. Primeiro bloco de um projeto de circuito integrado com tapeout pelo
programa UNIC-CASS.

## Estrutura

```
model/   golden models em MATLAB e exportador de vetores
rtl/     Verilog sintetizável
tb/      testbench de comparação bit a bit
sim/     saídas de simulação (vetores e binários vão aqui)
```

## Fluxo de uso

1. No MATLAB, rode `model/ddsm1_fixo.m` e em seguida `model/exporta_hex.m`.
2. Copie `din.hex` e `yref.hex` para `sim/`.
3. Rode `make`.

Resultado esperado: zero divergências, zero overflows, densidade de uns em
0,5000.

## Dependências

- Icarus Verilog (simulação)
- Verilator (lint, opcional)
- Yosys (síntese exploratória, opcional)
- GTKWave (formas de onda, opcional)
- MATLAB ou MATLAB Online (golden model)

## Contrato do bloco

Ver `CLAUDE.md`. Os parâmetros estão congelados: alterá-los invalida os vetores
de referência, que precisam ser regerados.
