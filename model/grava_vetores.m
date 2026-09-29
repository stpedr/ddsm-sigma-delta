function grava_vetores(arq, u, y, W_IN, W_ACC, extra)
% GRAVA_VETORES  Grava vetores de referencia no formato que tb/tb_ddsm1.v le.
%   grava_vetores(arq, u, y, W_IN, W_ACC, extra)
%
%   Linha 1: '# W_IN=<W_IN> W_ACC=<W_ACC> N=<N> <extra>'
%   Demais : '<u decimal com sinal> <y 0/1>', uma por ciclo.
%
%   O testbench RECUSA o arquivo se W_IN/W_ACC do cabecalho diferirem de
%   rtl/ddsm1_params.vh. Unico lugar do projeto que define este formato.
    fid = fopen(arq, 'w');
    if fid < 0, error('grava_vetores: nao consegui abrir %s', arq); end
    fprintf(fid, '# W_IN=%d W_ACC=%d N=%d %s\n', W_IN, W_ACC, numel(u), extra);
    fprintf(fid, '%d %d\n', [u(:).'; y(:).']);
    fclose(fid);
end
