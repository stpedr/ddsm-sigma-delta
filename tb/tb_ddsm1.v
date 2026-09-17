// ---------------------------------------------------------------------------
// tb_ddsm1.v — Comparacao bit a bit entre o RTL e o golden model do MATLAB
//
// Entradas esperadas no mesmo diretorio:
//   din.hex   — uma palavra hexadecimal de 16 bits por linha (entrada)
//   yref.hex  — 0 ou 1 por linha (saida esperada)
//
// Rodar:  iverilog -o sim tb_ddsm1.v ddsm1.v  &&  ./sim
// ---------------------------------------------------------------------------

`timescale 1ns/1ps

module tb_ddsm1;

    localparam integer N     = 65536;
    localparam integer W_IN  = 16;
    localparam integer GUARD = 2;

    reg                    clk = 1'b0;
    reg                    rst_n = 1'b0;
    reg                    en = 1'b1;
    reg signed [W_IN-1:0]  din = {W_IN{1'b0}};
    wire                   dout, ovf;

    reg [W_IN-1:0] vet_in  [0:N-1];
    reg [7:0]      vet_ref [0:N-1];

    integer i;
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
        $readmemh("din.hex",  vet_in);
        $readmemh("yref.hex", vet_ref);

        // Reset sincrono: precisa de bordas de clock com rst_n baixo.
        repeat (3) @(posedge clk);
        @(negedge clk) rst_n = 1'b1;

        for (i = 0; i < N; i = i + 1) begin
            din = vet_in[i];
            @(posedge clk);
            #1;   // deixa os registradores assentarem antes de amostrar

            if (dout !== vet_ref[i][0]) begin
                erros = erros + 1;
                if (primeiro < 0) primeiro = i;
                if (erros <= 10)
                    $display("ERRO  i=%0d  din=%0d  esperado=%b  obtido=%b",
                             i, $signed(vet_in[i]), vet_ref[i][0], dout);
            end

            if (ovf)  n_ovf = n_ovf + 1;
            if (dout) n_uns = n_uns + 1;
        end

        $display("");
        $display("--- resultado ---");
        $display("amostras comparadas : %0d", N);
        $display("divergencias        : %0d", erros);
        if (erros > 0)
            $display("primeira divergencia: i = %0d", primeiro);
        $display("ciclos com overflow : %0d", n_ovf);
        $display("densidade de 1s     : %f", n_uns * 1.0 / N);
        $display("");
        if (erros == 0 && n_ovf == 0)
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
