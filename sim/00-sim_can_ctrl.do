# Arguments
# 1: Test bench name (all_tb to simulate them all)
# 2: Simulate opencores testbench (true/false) when simulating all_tb
# 3: Simulate coverage (true/false)
echo "Args: $1 $2 $3"

quietly set tb_name $1
quietly set sim_oc_tb $2
quietly set sim_coverage $3

quietly set coverage_option ""
quietly set debug_db_option ""

if {$sim_coverage == "true"} {
    quietly set coverage_option "-coverage"
    quietly set debug_db_option "-debugDB"
}

# Simulate TMR voters
if {$tb_name == "tmr_voters_tb" || $tb_name == "all_tb"} {
    vsim $coverage_option $debug_db_option -gui -t ps -novopt work.tmr_voters_tb
    do 00-wave_can_ctrl.do
    run -all
    if {$sim_coverage == "true"} {
        coverage save -assert -directive -cvg -code bcefs -testname TMR_VOTERS -instance sim:/tmr_voters_tb UCDB/tmr_voters_tb.ucdb
    }
}

# Simulate counters (TMR and no TMR)
if {$tb_name == "tmr_counters_tb" || $tb_name == "all_tb"} {
    vsim $coverage_option $debug_db_option -gui -t ps -novopt work.tmr_counters_tb
    do 00-wave_can_ctrl.do
    run -all
    if {$sim_coverage == "true"} {
        coverage save -assert -directive -cvg -code bcefs -testname COUNTERS -instance sim:/tmr_counters_tb UCDB/tmr_counters_tb.ucdb
    }
}

# Simulate Bit Timing Logic (BTL)
if {$tb_name == "btl_tb" || $tb_name == "all_tb"} {
    vsim $coverage_option $debug_db_option -gui -t ps -novopt work.canola_btl_tb
    do 00-wave_can_ctrl.do
    run -all
    if {$sim_coverage == "true"} {
        coverage save -assert -directive -cvg -code bcefs -testname CANOLA_BTL -instance sim:/canola_btl_tb UCDB/canola_btl_tb.ucdb
    }
}

# Simulate Bit Stream Processor (BSP)
if {$tb_name == "bsp_tb" || $tb_name == "all_tb"} {
    vsim $coverage_option $debug_db_option -gui -t ps -novopt work.canola_bsp_tb
    do 00-wave_can_ctrl.do
    run -all
    if {$sim_coverage == "true"} {
        coverage save -assert -directive -cvg -code bcefs -testname CANOLA_BSP -instance sim:/canola_bsp_tb UCDB/canola_bsp_tb.ucdb
    }
}

# Simulate Error Management Logic (EML)
if {$tb_name == "eml_tb" || $tb_name == "all_tb"} {
    vsim $coverage_option $debug_db_option -gui -t ps -novopt work.canola_eml_tb
    do 00-wave_can_ctrl.do
    run -all
    if {$sim_coverage == "true"} {
        coverage save -assert -directive -cvg -code bcefs -testname CANOLA_EML -instance sim:/canola_eml_tb UCDB/canola_eml_tb.ucdb
    }
}

# Simulate standard top-level canola_top that doesn't use TMR wrappers
if {$tb_name == "main_tb_no_tmr" || $tb_name == "all_tb"} {
    vsim $coverage_option $debug_db_option -gui -t ps -novopt -gG_TMR_TOP_MODULE_EN=false work.canola_top_tb
    do 00-wave_can_ctrl.do
    run -all
    if {$sim_coverage == "true"} {
        coverage save -assert -directive -cvg -code bcefs -testname CANOLA_MAIN_NO_TMR -instance sim:/canola_top_tb UCDB/canola_top_tb_no_tmr.ucdb
    }
}

# Simulate top-level canola_top_tmr with triplication disabled
if {$tb_name == "main_tb_tmr_wrap_no_tmr" || $tb_name == "all_tb"} {
    vsim $coverage_option $debug_db_option -gui -t ps -novopt -gG_TMR_TOP_MODULE_EN=true -gG_SEE_MITIGATION_EN=false work.canola_top_tb
    do 00-wave_can_ctrl.do
    run -all
    if {$sim_coverage == "true"} {
        coverage save -assert -directive -cvg -code bcefs -testname CANOLA_MAIN_TMR_WRAP_NO_TMR -instance sim:/canola_top_tb UCDB/canola_top_tb_tmr_wrap_no_tmr.ucdb
    }
}

# Simulate top-level canola_top_tmr with triplication enabled
if {$tb_name == "main_tb_tmr_wrap_tmr" || $tb_name == "all_tb"} {
    vsim $coverage_option $debug_db_option -gui -t ps -novopt -gG_TMR_TOP_MODULE_EN=true -gG_SEE_MITIGATION_EN=true work.canola_top_tb
    do 00-wave_can_ctrl.do
    run -all
    if {$sim_coverage == "true"} {
        coverage save -assert -directive -cvg -code bcefs -testname CANOLA_MAIN_TMR_WRAP_TMR -instance sim:/canola_top_tb UCDB/canola_top_tb_tmr_wrap_no_tmr.ucdb
    }
}

# Simulate standard top-level canola_axi_slave that doesn't use TMR wrappers
if {$tb_name == "axi_tb_no_tmr" || $tb_name == "all_tb"} {
    vsim $coverage_option $debug_db_option -gui -t ps -novopt -gG_TMR_TOP_MODULE_EN=false work.canola_axi_slave_tb
    do 00-wave_can_ctrl.do
    run -all
    if {$sim_coverage == "true"} {
        coverage save -assert -directive -cvg -code bcefs -testname CANOLA_AXI_NO_TMR -instance sim:/canola_axi_slave_tb UCDB/canola_axi_slave_tb_no_tmr.ucdb
    }
}

# Simulate canola_axi_slave_tmr that with triplication disabled
if {$tb_name == "axi_tb_tmr_wrap_no_tmr" || $tb_name == "all_tb"} {
    vsim $coverage_option $debug_db_option -gui -t ps -novopt -gG_TMR_TOP_MODULE_EN=true -gG_SEE_MITIGATION_EN=false work.canola_axi_slave_tb
    do 00-wave_can_ctrl.do
    run -all
    if {$sim_coverage == "true"} {
        coverage save -assert -directive -cvg -code bcefs -testname CANOLA_AXI_TMR_WRAP_NO_TMR -instance sim:/canola_axi_slave_tb UCDB/canola_axi_slave_tb_tmr_wrap_no_tmr.ucdb
    }
}

# Simulate canola_axi_slave_tmr that with triplication enabled
if {$tb_name == "axi_tb_tmr_wrap_tmr" || $tb_name == "all_tb"} {
    vsim $coverage_option $debug_db_option -gui -t ps -novopt -gG_TMR_TOP_MODULE_EN=true -gG_SEE_MITIGATION_EN=true work.canola_axi_slave_tb
    do 00-wave_can_ctrl.do
    run -all
    if {$sim_coverage == "true"} {
        coverage save -assert -directive -cvg -code bcefs -testname CANOLA_AXI_TMR_WRAP_TMR -instance sim:/canola_axi_slave_tb UCDB/canola_axi_slave_tb_tmr_wrap_tmr.ucdb
    }
}

# Simulate Canola vs. Opencores CAN testbench
if {$tb_name == "opencores_tb" || ($tb_name == "all_tb" && $sim_oc_tb == "true")} {
    vsim $coverage_option $debug_db_option -gui -t ps -novopt work.canola_vs_opencores_can_tb
    do 00-wave_can_ctrl.do
    run -all
    if {$sim_coverage == "true"} {
        coverage save -assert -directive -cvg -code bcefs -testname CANOLA_VS_OPENCORES -instance sim:/canola_vs_opencores_can_tb UCDB/canola_vs_opencores_can_tb.ucdb
    }
}

if {$sim_coverage == "true"} {
    vcover merge -64 merged.ucdb UCDB/*.ucdb
    vcover report -details -html -htmldir covhtmlreport -threshL 50 -threshH 90 merged.ucdb; #
}
