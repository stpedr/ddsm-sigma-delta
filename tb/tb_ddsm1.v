// ---------------------------------------------------------------------------
// tb_ddsm1.v — Comparacao bit a bit entre o RTL e o golden model do MATLAB
//
// Le diretamente o arquivo de vetores gravado pelo golden model
// (model/grava_vetores.m), sem conversao intermediaria para .hex:
//
//   # W_IN=16 W_ACC=18 N=65536 ...     <- cabecalho, conferido abaixo
//   <entrada decimal com sinal> <saida esperada 0/1>
//   ...
//
// O arquivo e escolhido com +VEC=<arquivo>; sem o argumento, usa
// vetores_ddsm1.txt (senoide). O numero de amostras vem do proprio arquivo.
// O testbench RECUSA vetores cujo cabecalho nao bata com rtl/ddsm1_params.vh.
//
// Rodar:  make          (senoide)
//         make dc       (todos os vetores DC em sim/vetores_dc_*.txt)
// ---------------------------------------------------------------------------

`timescale 1ns/1ps

`include "ddsm1_params.vh"

module tb_ddsm1;

    localparam integer W_IN  = `DDSM1_W_IN;
    localparam integer GUARD = `DDSM1_GUARD;
    localparam integer W_ACC = W_IN + GUARD;

    reg                    clk = 1'b0;
    reg                    rst_n = 1'b0;
    reg                    en = 1'b1;
    reg signed [W_IN-1:0]  din = {W_IN{1'b0}};
    wire                   dout, ovf;

    reg [8*256-1:0]  arq;
    reg [8*1024-1:0] linha;
    integer fd, r, h_win, h_wacc;
    integer u, yref;

    integer n        = 0;
    integer erros    = 0;
    integer n_ovf    = 0;
    integer n_uns    = 0;
    integer primeiro = -1;

    ddsm1 #(.W_IN(W_IN), .GUARD(GUARD)) dut (
        .clk(clk), .rst_n(rst_n), .en(en),
        .din(din), .dout(dout), .ovf(ovf)
    );

    always #5 clk = ~clk;

    initial begin
        if (!$value$plusargs("VEC=%s", arq)) arq = "vetores_ddsm1.txt";

        fd = $fopen(arq, "r");
        if (fd == 0) begin
            $display("ERRO: nao consegui abrir %0s", arq);
            $display(">>> FALHOU <<<");
            $finish;
        end

        // Cabecalho: os vetores precisam ter sido gerados com o mesmo contrato
        // que o RTL esta usando. Pega o caso "modelo com GUARD diferente".
        r = $fgets(linha, fd);
        r = $sscanf(linha, "# W_IN=%d W_ACC=%d", h_win, h_wacc);
        if (r != 2 || h_win != W_IN || h_wacc != W_ACC) begin
            $display("ERRO: %0s foi gerado com W_IN=%0d W_ACC=%0d, mas o RTL usa W_IN=%0d W_ACC=%0d",
                     arq, h_win, h_wacc, W_IN, W_ACC);
            $display(">>> FALHOU <<<");
            $finish;
        end

        // Reset sincrono: precisa de bordas de clock com rst_n baixo.
        repeat (3) @(posedge clk);
        @(negedge clk) rst_n = 1'b1;

        while ($fscanf(fd, "%d %d\n", u, yref) == 2) begin
            din = u;
            @(posedge clk);
            #1;   // deixa os registradores assentarem antes de amostrar

            if (dout !== yref[0]) begin
                erros = erros + 1;
                if (primeiro < 0) primeiro = n;
                if (erros <= 10)
                    $display("ERRO  i=%0d  din=%0d  esperado=%0d  obtido=%b",
                             n, u, yref, dout);
            end

            if (ovf)  n_ovf = n_ovf + 1;
            if (dout) n_uns = n_uns + 1;
            n = n + 1;
        end
        $fclose(fd);

        $display("");
        $display("--- resultado: %0s ---", arq);
        $display("amostras comparadas : %0d", n);
        $display("divergencias        : %0d", erros);
        if (erros > 0)
            $display("primeira divergencia: i = %0d", primeiro);
        $display("ciclos com overflow : %0d", n_ovf);
        $display("densidade de 1s     : %f", (n > 0) ? n_uns * 1.0 / n : 0.0);
        $display("");
        if (n > 0 && erros == 0 && n_ovf == 0)
            $display(">>> RTL BATE COM O GOLDEN MODEL <<<");
        else
            $display(">>> FALHOU <<<");

        $finish;
    end

    // Descomente para inspecionar formas de onda no GTKWave.
    // initial begin
    //     $dumpfile("tb_ddsm1.vcd");
    //     $dumpvars(0, tb_ddsm1);
    // end

endmodule
