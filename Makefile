# Makefile

#Paths
RUN_DIR = run/

MODELSIM_CMD = vsim -do "../sim/05-compile_and_run_canola.do"

#targets
main: gui

gui:
	(cd $(RUN_DIR) && $(MODELSIM_CMD))

console:
	(cd $(RUN_DIR) && $(MODELSIM_CMD) -c)

environment:
	/bin/bash
