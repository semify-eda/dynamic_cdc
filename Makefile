# CLI params to pass to verilator
SYNTHESIS 											:=0
GLITCH_MONITOR		 							:=0
METASTABILITY_PROBABILITY 			:=100
GLOBAL_METASTABILITY_ENABLE 		:=0
METASTABILITY_HIERARCHY_TOGGLE 	:=TOP.*

SV_RNG_SEED := 883
TOP_TB := fsm_tb

TIMESCALE:=--timescale 1ns/1ps

SOURCES := $(wildcard src/*.sv)

PLUSARGS :=\
	+metastability_probability=$(METASTABILITY_PROBABILITY)\
	+global_metastability_enable=$(GLOBAL_METASTABILITY_ENABLE)\
	+metastability_hierarchy_toggle=$(METASTABILITY_HIERARCHY_TOGGLE)\

VERILATOR_FLAGS :=\
	--trace\
	--assert\
	--trace-structs\
	--Wno-fatal\
	-j 0\
	$(TIMESCALE)\

OPT_FLAGS :=\
	--assert\
	--Wno-fatal\
	-j 0\
	$(TIMESCALE)\
	-O3\
	-GSYNTHESIS=$(SYNTHESIS)\
	-GENABLE_GLITCH_MONITOR=$(GLITCH_MONITOR)

run_sim: testbench
	./obj_dir/V$(TOP_TB) +verilator+seed+$(SV_RNG_SEED) $(PLUSARGS)

testbench:
	verilator --binary $(VERILATOR_FLAGS) $(SOURCES) tb/$(TOP_TB).sv --top-module $(TOP_TB)

benchmark:
	verilator --binary $(OPT_FLAGS) $(SOURCES) tb/$(TOP_TB).sv --top-module $(TOP_TB)
	time ./obj_dir/V$(TOP_TB) +verilator+seed+$(SV_RNG_SEED) $(PLUSARGS)

clean:
	rm -rf ./obj_dir waves.vcd
