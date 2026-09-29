// ---------------------------------------------------------------------------
// ddsm1.v — Modulador sigma-delta digital de 1a ordem
//
// Contrato congelado (valores de W_IN e GUARD em ddsm1_params.vh):
//   W_IN bits com sinal, complemento de dois
//   W_ACC = W_IN + GUARD bits
//   realimentacao = +/- FS, com FS = 2^(W_IN-1)
//   saturacao (nunca wrap-around)
//   reset: acc = 0, saida = 0 (equivale a yfb = -FS no modelo)
//
// Latencia: 1 ciclo. A amostra aplicada antes de uma borda de clock aparece
// em dout logo apos essa borda.
// ---------------------------------------------------------------------------

`include "ddsm1_params.vh"

module ddsm1 #(
    parameter integer W_IN  = `DDSM1_W_IN,
    parameter integer GUARD = `DDSM1_GUARD
)(
    input  wire                    clk,
    input  wire                    rst_n,   // reset sincrono, ativo baixo
    input  wire                    en,      // habilita uma amostra por ciclo
    input  wire signed [W_IN-1:0]  din,
    output wire                    dout,    // bitstream PDM
    output wire                    ovf      // pulsa se a saturacao atuou
);

    localparam integer W_ACC = W_IN + GUARD;
    localparam integer W_EXT = W_ACC + 2;   // folga para a soma antes de saturar

    localparam signed [W_EXT-1:0] FS      =  2**(W_IN-1);
    localparam signed [W_EXT-1:0] ACC_MAX =  2**(W_ACC-1) - 1;
    localparam signed [W_EXT-1:0] ACC_MIN = -(2**(W_ACC-1));

    reg signed [W_ACC-1:0] acc;
    reg                    y_r;
    reg                    ovf_r;

    // Realimentacao: um mux entre duas constantes. No modelo, yfb = +/- FS.
    wire signed [W_EXT-1:0] fb = y_r ? FS : -FS;

    // Extensao de sinal explicita para W_EXT, sem depender das regras de
    // largura de contexto do Verilog (que variam sutilmente entre ferramentas).
    wire signed [W_EXT-1:0] acc_sx = {{(W_EXT-W_ACC){acc[W_ACC-1]}}, acc};
    wire signed [W_EXT-1:0] din_sx = {{(W_EXT-W_IN){din[W_IN-1]}},   din};

    // Soma na largura estendida, para so entao decidir sobre saturacao.
    wire signed [W_EXT-1:0] acc_ext = acc_sx + din_sx - fb;

    wire sat_hi = (acc_ext > ACC_MAX);
    wire sat_lo = (acc_ext < ACC_MIN);

    wire signed [W_ACC-1:0] acc_nxt = sat_hi ? ACC_MAX[W_ACC-1:0] :
                                      sat_lo ? ACC_MIN[W_ACC-1:0] :
                                               acc_ext[W_ACC-1:0];

    always @(posedge clk) begin
        if (!rst_n) begin
            acc   <= {W_ACC{1'b0}};
            y_r   <= 1'b0;
            ovf_r <= 1'b0;
        end else if (en) begin
            acc   <= acc_nxt;
            // Quantizador de 1 bit: o complemento do bit de sinal.
            // Nenhuma comparacao aritmetica, apenas um inversor.
            y_r   <= ~acc_nxt[W_ACC-1];
            ovf_r <= sat_hi | sat_lo;
        end
    end

    assign dout = y_r;
    assign ovf  = ovf_r;

endmodule
