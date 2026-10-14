function r = recuperacao2(tr, y, n_fim, env, R)
% RECUPERACAO2  Criterio de recuperacao da 2a ordem, fixado antes da medida.
%   r = recuperacao2(tr, y, n_fim, env, R)
%   tr    : trajetoria de ddsm2 (tr.w1, tr.w2)
%   y     : saida de ddsm2
%   n_fim : ultima amostra do estimulo; depois dela a entrada e zero
%   env   : envelope normal [e1 e2] (excursao com entrada zero x margem)
%   R     : prazo maximo de recuperacao, em ciclos
%
%   r.ok      : os dois estados entram no envelope em ate R ciclos apos n_fim
%               e nao saem mais ate o fim da janela
%   r.t       : ciclos apos n_fim ate a entrada definitiva no envelope
%               (Inf se nunca)
%   r.travado : a saida fica constante do fim do estimulo ao fim da janela
%   r.seq     : maior sequencia de bits iguais na fase de entrada zero
    w1 = tr.w1(n_fim+1:end); w2 = tr.w2(n_fim+1:end);
    fora = abs(w1) > env(1) | abs(w2) > env(2);
    ult = find(fora, 1, 'last');
    if isempty(ult), r.t = 0;
    elseif ult == numel(fora), r.t = Inf;
    else, r.t = ult;
    end
    r.ok = r.t <= R;
    yz = y(n_fim+1:end);
    r.seq = maior_sequencia(yz);
    r.travado = all(yz == yz(1));
end
