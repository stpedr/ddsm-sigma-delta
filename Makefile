# Makefile — DDSM 1a ordem
#
# make          -> compila e roda a comparacao bit a bit (senoide)
# make dc       -> comparacao bit a bit dos vetores DC
# make lint     -> lint com Verilator
# make synth    -> sintese exploratoria com Yosys (contagem de celulas)
# make wave     -> abre as formas de onda no GTKWave
# make clean

RTL   := rtl/ddsm1.v
PARAMS:= rtl/ddsm1_params.vh
INC   := -Irtl
TB    := tb/tb_ddsm1.v
SIM   := sim/sim
VCD   := sim/tb_ddsm1.vcd

.PHONY: all run dc lint synth wave clean

all: run

$(SIM): $(RTL) $(TB) $(PARAMS)
	@mkdir -p sim
	iverilog -g2005 $(INC) -o $(SIM) $(TB) $(RTL)

# O testbench le direto sim/vetores_*.txt, gravados pelo golden model
# (model/grava_vetores.m), e recusa vetores gerados com outro W_IN/W_ACC.
#   make     -> senoide (sim/vetores_ddsm1.txt, secao C de ddsm1_fixo.m)
#   make dc  -> todos os sim/vetores_dc_*.txt (model/tons_idle_dc.m)
run: $(SIM)
	cd sim && ./sim

dc: $(SIM)
	@cd sim && ok=0; tot=0; \
	for v in vetores_dc_*.txt; do \
	  tot=$$((tot+1)); \
	  ./sim +VEC=$$v | grep -E "resultado|comparadas|divergencias|primeira|overflow|densidade|>>>"; \
	  ./sim +VEC=$$v | grep -q "RTL BATE" && ok=$$((ok+1)); \
	done; \
	echo "=== $$ok de $$tot vetores DC batem bit a bit ==="; \
	test $$ok -eq $$tot

lint:
	verilator --lint-only -Wall $(INC) $(RTL)

synth:
	yosys -p "read_verilog $(INC) $(RTL); synth -top ddsm1; stat"

wave: $(VCD)
	gtkwave $(VCD) &

clean:
	rm -rf sim/sim sim/*.vcd
