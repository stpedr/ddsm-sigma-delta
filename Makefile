# Makefile — DDSM 1a ordem
#
# make          -> compila e roda a comparacao bit a bit
# make lint     -> lint com Verilator
# make synth    -> sintese exploratoria com Yosys (contagem de celulas)
# make wave     -> abre as formas de onda no GTKWave
# make clean

RTL   := rtl/ddsm1.v
TB    := tb/tb_ddsm1.v
SIM   := sim/sim
VCD   := sim/tb_ddsm1.vcd

.PHONY: all run lint synth wave clean

all: run

$(SIM): $(RTL) $(TB)
	@mkdir -p sim
	iverilog -g2005 -o $(SIM) $(TB) $(RTL)

# Os vetores din.hex e yref.hex sao gerados pela secao C de model/ddsm1_fixo.m
# e devem estar no diretorio a partir do qual a simulacao roda.
run: $(SIM)
	cd sim && ./sim

lint:
	verilator --lint-only -Wall $(RTL)

synth:
	yosys -p "read_verilog $(RTL); synth -top ddsm1; stat"

wave: $(VCD)
	gtkwave $(VCD) &

clean:
	rm -rf sim/sim sim/*.vcd
