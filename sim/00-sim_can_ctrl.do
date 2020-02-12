echo "Args: $1"

# Simulate TMR voters
if {$1 == "tmr_voters_tb" || $1 == "all_tb"} {
    vsim -gui -t ps -novopt work.tmr_voters_tb
    do 00-wave_can_ctrl.do
    run -all
}

# Simulate counters (TMR and no TMR)
if {$1 == "tmr_counters_tb" || $1 == "all_tb"} {
    vsim -gui -t ps -novopt work.tmr_counters_tb
    do 00-wave_can_ctrl.do
    run -all
}

# Simulate Bit Timing Logic (BTL)
if {$1 == "btl_tb" || $1 == "all_tb"} {
    vsim -gui -t ps -novopt work.canola_btl_tb
    do 00-wave_can_ctrl.do
    run -all
}

# Simulate Bit Stream Processor (BSP)
if {$1 == "bsp_tb" || $1 == "all_tb"} {
    vsim -gui -t ps -novopt work.canola_bsp_tb
    do 00-wave_can_ctrl.do
    run -all
}

# Simulate Error Management Logic (EML)
if {$1 == "eml_tb" || $1 == "all_tb"} {
    vsim -gui -t ps -novopt work.canola_eml_tb
    do 00-wave_can_ctrl.do
    run -all
}

# Simulate standard top-level canola_top that doesn't use TMR wrappers
if {$1 == "main_tb_no_tmr" || $1 == "all_tb"} {
    vsim -gui -t ps -novopt -gG_TMR_TOP_MODULE_EN=false work.canola_top_tb
    do 00-wave_can_ctrl.do
    run -all
}

# Simulate top-level canola_top_tmr with triplication disabled
if {$1 == "main_tb_tmr_wrap_no_tmr" || $1 == "all_tb"} {
    vsim -gui -t ps -novopt -gG_TMR_TOP_MODULE_EN=true -gG_SEE_MITIGATION_EN=false work.canola_top_tb
    do 00-wave_can_ctrl.do
    run -all
}

# Simulate top-level canola_top_tmr with triplication enabled
if {$1 == "main_tb_tmr_wrap_tmr" || $1 == "all_tb"} {
    vsim -gui -t ps -novopt -gG_TMR_TOP_MODULE_EN=true -gG_SEE_MITIGATION_EN=true work.canola_top_tb
    do 00-wave_can_ctrl.do
    run -all
}

# Simulate standard top-level canola_axi_slave that doesn't use TMR wrappers
if {$1 == "axi_tb_no_tmr" || $1 == "all_tb"} {
    vsim -gui -t ps -novopt -gG_TMR_TOP_MODULE_EN=false work.canola_axi_slave_tb
    do 00-wave_can_ctrl.do
    run -all
}

# Simulate canola_axi_slave_tmr that with triplication disabled
if {$1 == "axi_tb_tmr_wrap_no_tmr" || $1 == "all_tb"} {
    vsim -gui -t ps -novopt -gG_TMR_TOP_MODULE_EN=true -gG_SEE_MITIGATION_EN=false work.canola_axi_slave_tb
    do 00-wave_can_ctrl.do
    run -all
}

# Simulate canola_axi_slave_tmr that with triplication enabled
if {$1 == "axi_tb_tmr_wrap_tmr" || $1 == "all_tb"} {
    vsim -gui -t ps -novopt -gG_TMR_TOP_MODULE_EN=true -gG_SEE_MITIGATION_EN=true work.canola_axi_slave_tb
    do 00-wave_can_ctrl.do
    run -all
}

# Simulate Canola vs. Opencores CAN testbench
if {$1 == "opencores_tb" || ($1 == "all_tb" && $2 == "true")} {
    vsim -gui -t ps -novopt work.canola_vs_opencores_can_tb
    do 00-wave_can_ctrl.do
    run -all
}
