// ---------------------------------------------------------------------------
// ddsm2_params.vh — FONTE UNICA dos parametros do modulador de 2a ordem
// (CIFB, forma inteira de Boser-Wooley; ver docs/ddsm2-cifb.md).
//
// Contrato SEPARADO do da 1a ordem (ddsm1_params.vh), que nao muda.
// Lido pelo RTL/testbench via `include e pelo golden model via
// model/le_params.m('ddsm2'). Nao repita estes valores em outro arquivo.
//
// Laco (y_r = registro de saida, fb = +FS se y_r = 1, -FS se y_r = 0):
//   w1 <- w1 + B1*u  - A1*fb
//   w2 <- w2 + C1*w1 - A2*fb          (w1 ANTES da atualizacao)
//   y_r <- (w2 >= 0)                  (w2 DEPOIS da atualizacao)
// Reset: w1 = w2 = 0, y_r = 0 (realimenta -FS no primeiro ciclo).
// ---------------------------------------------------------------------------
`ifndef DDSM2_PARAMS_VH
`define DDSM2_PARAMS_VH

`define DDSM2_W_IN   16   // entrada com sinal, complemento de dois; FS = 2^(W_IN-1)

// Coeficientes CIFB (inteiros; equivalentes aos ganhos 0,5 de Boser-Wooley)
`define DDSM2_B1     1
`define DDSM2_A1     1
`define DDSM2_C1     1
`define DDSM2_A2     2

// ===========================================================================
// LARGURAS PROVISORIAS -- NAO CONGELADAS.
// Escolhidas largas de proposito para observar a excursao NATURAL do laco,
// sem saturacao. O modelo nao satura: se um integrador sair desta faixa, e
// ALARME (o laco divergiu), reportado como resultado da etapa 3, e NAO motivo
// para aumentar a largura. Fechar com a campanha de estabilidade (etapa 3).
// ===========================================================================
`define DDSM2_W_I1   32   // PROVISORIO: largura do integrador 1, com sinal
`define DDSM2_W_I2   32   // PROVISORIO: largura do integrador 2, com sinal

`endif
