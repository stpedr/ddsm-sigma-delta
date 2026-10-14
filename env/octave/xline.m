function h = xline(x, varargin)
% XLINE  Substituto minimo do xline do MATLAB, so para o Octave (env/octave.sh).
%   Ignora rotulo e opcoes; desenha uma linha vertical tracejada em x.
    yl = ylim(); hold on;
    h = plot([x x], yl, '--', 'Color', [0.3 0.3 0.3]);
end
