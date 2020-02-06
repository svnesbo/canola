#vsim -gui -t ps -novopt work.tmr_voters_tb
#do 00-wave_can_ctrl.do
#run -all

#vsim -gui -t ps -novopt work.tmr_counters_tb
#do 00-wave_can_ctrl.do
#run -all

#vsim -gui -t ps -novopt work.canola_btl_tb
#do 00-wave_can_ctrl.do
#run -all

#vsim -gui -t ps -novopt work.canola_bsp_tb
#do 00-wave_can_ctrl.do
#run -all

#vsim -gui -t ps -novopt work.canola_eml_tb
#do 00-wave_can_ctrl.do
#run -all

# Simulate top-level canola_top without TMR
vsim -gui -t ps -novopt -gG_TMR_EN=false work.canola_top_tb
do 00-wave_can_ctrl.do
run -all

# Simulate top-level canola_top_tmr with triplication disabled
#vsim -gui -t ps -novopt -gG_TMR_EN=true -gG_SEE_MITIGATION_EN=false work.canola_top_tb
#do 00-wave_can_ctrl.do
#run -all

# Simulate top-level canola_top_tmr with triplication enabled
#vsim -gui -t ps -novopt -gG_TMR_EN=true -gG_SEE_MITIGATION_EN=true work.canola_top_tb
#do 00-wave_can_ctrl.do
#run -all

#if {[string is true -strict $simulate_opencore_can]} {
#    vsim -gui -t ps -novopt work.canola_vs_opencores_can_tb
#    do 00-wave_can_ctrl.do
#    run -all
#}

#vsim -gui -t ps -novopt work.canola_axi_slave_tb
#do 00-wave_can_ctrl.do
#run -all
