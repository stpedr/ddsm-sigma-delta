function h = yline(y, estilo, varargin)
% YLINE  Substituto minimo do yline do MATLAB, so para o Octave (env/octave.sh).
%   Desenha uma linha horizontal em y com o estilo de linha dado ('--', ':'...)
%   e aceita os pares 'LineWidth' e 'Color'; ignora rotulos.
    if nargin < 2 || isempty(estilo), estilo = '--'; end
    xl = xlim(); hold on;
    h = plot(xl, [y y], estilo, 'Color', [0.3 0.3 0.3]);
    for k = 1:2:numel(varargin)-1
        if any(strcmpi(varargin{k}, {'LineWidth', 'Color'}))
            set(h, varargin{k}, varargin{k+1});
        end
    end
end
