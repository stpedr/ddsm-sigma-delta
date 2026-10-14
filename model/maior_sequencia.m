function m = maior_sequencia(y)
% MAIOR_SEQUENCIA  Comprimento da maior sequencia de valores iguais em y.
    if isempty(y), m = 0; return; end
    mud = find(diff(y(:).') ~= 0);
    bordas = [0, mud, numel(y)];
    m = max(diff(bordas));
end
