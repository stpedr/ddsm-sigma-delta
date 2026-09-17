%% exporta_hex.m
%  Gera din.hex e yref.hex a partir do golden model, no formato que o
%  $readmemh do Verilog le diretamente.
%
%  Rode DEPOIS de ddsm1_fixo.m, com u, y e W_IN ainda no workspace.
%  Copie os dois arquivos para o diretorio sim/ antes de rodar o make.

if ~exist('u','var') || ~exist('y','var')
    error('Rode ddsm1_fixo.m primeiro: u e y precisam estar no workspace.');
end

% Entrada: complemento de dois em W_IN bits, uma palavra hexadecimal por linha
fid = fopen('din.hex','w');
fprintf(fid, '%04X\n', mod(u, 2^W_IN));
fclose(fid);

% Saida esperada: 0 ou 1 por linha
fid = fopen('yref.hex','w');
fprintf(fid, '%d\n', y);
fclose(fid);

fprintf('din.hex e yref.hex gravados (%d linhas cada).\n', numel(u));
