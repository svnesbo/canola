# Makefile

#Paths
RUN_DIR = run/

#Coverage
ifeq ($(COVERAGE), 1)
cov_param = "coverage"
else
cov_param = ""
endif

#targets
main: main_no_tmr


batch_all:
	(cd $(RUN_DIR) && vsim -do "do ../sim/05-compile_and_run_canola.do all_tb $(cov_param)" -c)

main_no_tmr:
	(cd $(RUN_DIR) && vsim -do "do ../sim/05-compile_and_run_canola.do main_tb_no_tmr $(cov_param)")

main_tmr_wrap_no_tmr:
	(cd $(RUN_DIR) && vsim -do "do ../sim/05-compile_and_run_canola.do main_tb_tmr_wrap_no_tmr $(cov_param)")

main_tmr_wrap_tmr:
	(cd $(RUN_DIR) && vsim -do "do ../sim/05-compile_and_run_canola.do main_tb_tmr_wrap_tmr $(cov_param)")

btl:
	(cd $(RUN_DIR) && vsim -do "do ../sim/05-compile_and_run_canola.do btl_tb $(cov_param)")

bsp:
	(cd $(RUN_DIR) && vsim -do "do ../sim/05-compile_and_run_canola.do bsp_tb $(cov_param)")

eml:
	(cd $(RUN_DIR) && vsim -do "do ../sim/05-compile_and_run_canola.do eml_tb $(cov_param)")

axi_tb_no_tmr:
	(cd $(RUN_DIR) && vsim -do "do ../sim/05-compile_and_run_canola.do axi_tb_no_tmr $(cov_param)")

axi_tb_tmr_wrap_no_tmr:
	(cd $(RUN_DIR) && vsim -do "do ../sim/05-compile_and_run_canola.do axi_tb_tmr_wrap_no_tmr $(cov_param)")

axi_tb_tmr_wrap_tmr:
	(cd $(RUN_DIR) && vsim -do "do ../sim/05-compile_and_run_canola.do axi_tb_tmr_wrap_tmr $(cov_param)")

opencores:
	(cd $(RUN_DIR) && vsim -do "do ../sim/05-compile_and_run_canola.do opencores_tb $(cov_param)")

tmr_voters:
	(cd $(RUN_DIR) && vsim -do "do ../sim/05-compile_and_run_canola.do tmr_voters_tb $(cov_param)")

tmr_counters:
	(cd $(RUN_DIR) && vsim -do "do ../sim/05-compile_and_run_canola.do tmr_counters_tb $(cov_param)")

environment:
	/bin/bash
