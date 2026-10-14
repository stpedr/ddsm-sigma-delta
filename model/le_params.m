function P = le_params(bloco)
% LE_PARAMS  Le os parametros de contrato de rtl/<bloco>_params.vh.
%   P = le_params()         1a ordem: rtl/ddsm1_params.vh (P.W_IN, P.GUARD, ...)
%   P = le_params('ddsm2')  2a ordem: rtl/ddsm2_params.vh (P.W_IN, P.B1, ...)
%
%   Cada .vh e a FONTE UNICA dos seus numeros: o RTL e o testbench o incluem
%   via `include, e o golden model o le por aqui. Nao repita os valores em
%   nenhum script. So os `define <BLOCO>_<NOME> <inteiro> sao lidos.

    if nargin < 1, bloco = 'ddsm1'; end
    arq = fullfile(fileparts(mfilename('fullpath')), '..', 'rtl', [bloco '_params.vh']);
    txt = fileread(arq);
    tok = regexp(txt, ['`define\s+' upper(bloco) '_(\w+)\s+(\d+)'], 'tokens');

    P = struct();
    for k = 1:numel(tok)
        P.(tok{k}{1}) = str2double(tok{k}{2});
    end

    switch bloco
        case 'ddsm1', obrig = {'W_IN', 'GUARD'};
        case 'ddsm2', obrig = {'W_IN', 'B1', 'A1', 'C1', 'A2', 'W_I1', 'W_I2'};
        otherwise,    obrig = {'W_IN'};
    end
    falta = obrig(~isfield(P, obrig));
    if ~isempty(falta)
        error('le_params: %s ausente em %s', strjoin(falta, ', '), arq);
    end
end
