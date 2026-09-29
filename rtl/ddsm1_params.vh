// ---------------------------------------------------------------------------
// ddsm1_params.vh — FONTE UNICA dos parametros do contrato congelado.
//
// Lido pelo RTL e pelo testbench via `include, e pelo golden model via
// model/le_params.m. Nao repita estes valores em nenhum outro arquivo:
// um numero duplicado em dois lugares ja causou divergencia entre o modelo
// (GUARD = 3) e o RTL (GUARD = 2).
//
// Alterar qualquer valor aqui invalida os vetores de referencia em sim/.
// ---------------------------------------------------------------------------
`ifndef DDSM1_PARAMS_VH
`define DDSM1_PARAMS_VH

`define DDSM1_W_IN   16   // largura da entrada, com sinal, complemento de dois
`define DDSM1_GUARD  2    // bits de guarda: W_ACC = W_IN + GUARD = 18

`endif
