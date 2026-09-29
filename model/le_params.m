function P = le_params()
% LE_PARAMS  Le os parametros do contrato de rtl/ddsm1_params.vh.
%   P = le_params() devolve uma struct com P.W_IN e P.GUARD.
%
%   ddsm1_params.vh e a FONTE UNICA desses numeros: o RTL e o testbench o
%   incluem via `include, e o golden model o le por aqui. Nao repita os
%   valores em nenhum script.

    arq = fullfile(fileparts(mfilename('fullpath')), '..', 'rtl', 'ddsm1_params.vh');
    txt = fileread(arq);
    tok = regexp(txt, '`define\s+DDSM1_(\w+)\s+(\d+)', 'tokens');

    P = struct();
    for k = 1:numel(tok)
        P.(tok{k}{1}) = str2double(tok{k}{2});
    end

    if ~isfield(P, 'W_IN') || ~isfield(P, 'GUARD')
        error('le_params: W_IN ou GUARD ausente em %s', arq);
    end
end
