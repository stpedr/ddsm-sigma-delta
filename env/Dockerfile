# Ambiente para rodar o golden model (model/*.m) sem MATLAB.
#
#   make imagem-octave          # constroi ddsm-octave:local a partir deste arquivo
#   env/octave.sh <comando>     # roda um script/expressao do Octave no repo
#
# Versoes fixadas: octave e octave-signal, que determinam a numerica (hann e o
# proprio interpretador). gnuplot, ghostscript e fontes so afetam a
# renderizacao das figuras e ficam sem versao fixa (pacotes de atualizacao de
# seguranca saem do repositorio quando sao substituidos). Versoes da imagem
# usada nas medidas registradas: env/versoes.txt.
FROM ubuntu:24.04
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y --no-install-recommends \
        octave=8.4.0-1build5 \
        octave-signal=1.4.5-2 \
        gnuplot-nox \
        ghostscript \
        fonts-dejavu-core \
        fonts-freefont-otf \
    && rm -rf /var/lib/apt/lists/*
WORKDIR /work
