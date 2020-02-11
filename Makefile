# Makefile

#Paths
RUN_DIR = run/

MODELSIM_CMD = vsim -do "../sim/05-compile_and_run_canola.do"

#targets
main: main_no_tmr

console:
	(cd $(RUN_DIR) && $(MODELSIM_CMD) -c)

batch_all:
	(cd $(RUN_DIR) && vsim -do "do ../sim/05-compile_and_run_canola.do all_tb" -c)

main_no_tmr:
	(cd $(RUN_DIR) && vsim -do "do ../sim/05-compile_and_run_canola.do main_tb_no_tmr")

main_tmr_wrap_no_tmr:
	(cd $(RUN_DIR) && vsim -do "do ../sim/05-compile_and_run_canola.do main_tb_tmr_wrap_no_tmr")

main_tmr_wrap_tmr:
	(cd $(RUN_DIR) && vsim -do "do ../sim/05-compile_and_run_canola.do main_tb_tmr_wrap_tmr")

btl:
	(cd $(RUN_DIR) && vsim -do "do ../sim/05-compile_and_run_canola.do btl_tb")

bsp:
	(cd $(RUN_DIR) && vsim -do "do ../sim/05-compile_and_run_canola.do bsp_tb")

eml:
	(cd $(RUN_DIR) && vsim -do "do ../sim/05-compile_and_run_canola.do eml_tb")

axi_tb_no_tmr:
	(cd $(RUN_DIR) && vsim -do "do ../sim/05-compile_and_run_canola.do axi_tb_no_tmr")

axi_tb_tmr_wrap_no_tmr:
	(cd $(RUN_DIR) && vsim -do "do ../sim/05-compile_and_run_canola.do axi_tb_tmr_wrap_no_tmr")

axi_tb_tmr_wrap_tmr:
	(cd $(RUN_DIR) && vsim -do "do ../sim/05-compile_and_run_canola.do axi_tb_tmr_wrap_tmr")

opencores:
	(cd $(RUN_DIR) && vsim -do "do ../sim/05-compile_and_run_canola.do opencores_tb")

tmr_voters:
	(cd $(RUN_DIR) && vsim -do "do ../sim/05-compile_and_run_canola.do tmr_voters_tb")

tmr_counters:
	(cd $(RUN_DIR) && vsim -do "do ../sim/05-compile_and_run_canola.do tmr_counters_tb")

environment:
	/bin/bash
