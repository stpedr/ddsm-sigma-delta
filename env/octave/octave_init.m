% OCTAVE_INIT  Preparacao do Octave para rodar os scripts de model/.
%   Chamado por env/octave.sh antes de cada comando. Nao use no MATLAB.
%
%   - pkg signal: hann() com a mesma definicao do MATLAB (simetrica)
%   - gnuplot, figuras invisiveis: renderizacao sem display
%   - esta pasta no path: substitutos de xline e yline (o Octave 8.4 nao tem).
%     So entra no path do Octave; no MATLAB vale o xline nativo.
pkg load signal;
addpath(fileparts(mfilename('fullpath')));
graphics_toolkit('gnuplot');
set(0, 'defaultfigurevisible', 'off');
warning('off', 'Octave:gnuplot-graphics');
