#!/usr/bin/env bash
# Roda um comando do Octave no golden model, dentro da imagem ddsm-octave:local.
#
#   env/octave.sh tons_idle_dc
#   env/octave.sh "ddsm1_fixo; figuras_validacao"
#
# Rode a partir da raiz do repo (Linux/WSL). O repo e montado em /work e o
# diretorio de trabalho e /work/model. Os arquivos gerados pertencem ao seu
# usuario. Para construir a imagem: make imagem-octave.
set -euo pipefail

IMAGEM="${DDSM_OCTAVE_IMAGEM:-ddsm-octave:local}"
RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if [ $# -lt 1 ]; then
    echo "uso: env/octave.sh <comando do Octave>" >&2
    exit 2
fi
if ! docker image inspect "$IMAGEM" >/dev/null 2>&1; then
    echo "imagem $IMAGEM ausente: rode 'make imagem-octave'" >&2
    exit 1
fi

# O gnuplot imprime avisos de manutencao em toda execucao; sao filtrados.
docker run --rm --user "$(id -u):$(id -g)" -e HOME=/tmp \
    -v "$RAIZ":/work -w /work/model "$IMAGEM" \
    octave-cli --no-gui --eval "source('/work/env/octave/octave_init.m'); $*" 2>&1 \
  | grep -vE "gnuplot graphics toolkit|not actively maintained|limitations that are|one-directional pipe|Octave interpreter so|reflected in the graphics|window is closed|notified and will not|qt toolkit is recommended|iconv failed" \
  ; exit "${PIPESTATUS[0]}"
