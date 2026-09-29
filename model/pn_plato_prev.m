function pn = pn_plato_prev(e, P, OSR)
% PN_PLATO_PREV  Ruido na banda previsto dentro de um plato de tons idle.
%   pn = pn_plato_prev(e, P, OSR)
%   e : desvio da fracao central, em fracao de FS (vetor)
%   P : periodo do ciclo-limite no centro (denominador de (1+x)/2)
%   pn: potencia na banda relativa a FS^2
%
%   Com DC a saida {0,1} e uma sequencia de rotacao de densidade
%   rho = a/P + e/2. As raias de k = m*P ficam em m*P*|e|/2, com amplitude
%   |sin(pi m P e/2)| / (pi m P); na saida bipolar, cada uma contribui
%   8 sin^2(pi m P e/2) / (pi m P)^2 de potencia. Somam-se as que caem na
%   banda (m*P*|e|/2 < 1/(2 OSR)). Em e = 0 nao ha raia na banda: pn = 0.
    fB = 1/(2*OSR);
    pn = zeros(size(e));
    for j = 1:numel(e)
        a = P * abs(e(j)) / 2;
        if a == 0, continue; end
        m = 1:floor(fB / a);
        pn(j) = sum(8 * sin(pi*m*a).^2 ./ (pi*m*P).^2);
    end
end
