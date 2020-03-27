# Script takes one optional argument, which is the testbench to simulate.
#
# Possible options for testbench(es):
# all_tb                  - Simulate all testbenches in a sequence
# main_tb_no_tmr          - Simulate canola_top_tb with canola_top (default)
# main_tb_tmr_wrap_no_tmr - Simulate canola_top_tb with canola_top_tmr_wrapper with TMR disabled
# main_tb_tmr_wrap_tmr    - Simulate canola_top_tb with canola_top_tmr_wrapper with TMR enabled
# btl_tb                  - Simulate BTL testbench
# bsp_tb                  - Simulate BSP testbench
# eml_tb                  - Simulate EML testbench
# axi_tb_no_tmr           - Simulate canola_axi_slave_tb with canola_axi_slave
# axi_tb_tmr_wrap_no_tmr  - Simulate canola_axi_slave_tb with canola_axi_slave_tmr with TMR disabled
# axi_tb_tmr_wrap_tmr     - Simulate canola_axi_slave_tb with canola_axi_slave_tmr with TMR enabled
# opencores_tb            - Simulate canola vs. opencores CAN testbench
# tmr_voters_tb           - Simulate voters for TMR
# tmr_counters_tb         - Simulate counters for TMR

# Default argument
quietly set sim_test_bench "main_tb_no_tmr"
quietly set coverage "false"

echo "argc: $argc\n"

if { [info exists 1] } {
    if {$argc == 0} {
        error "Testbench not specified."
    } elseif {$argc <= 2} {
        quietly set sim_test_bench "$1"

        if {$1 != "all_tb" &&
            $1 != "main_tb_no_tmr" &&
            $1 != "main_tb_tmr_wrap_no_tmr" &&
            $1 != "main_tb_tmr_wrap_tmr" &&
            $1 != "btl_tb" &&
            $1 != "bsp_tb" &&
            $1 != "eml_tb" &&
            $1 != "axi_tb_no_tmr" &&
            $1 != "axi_tb_tmr_wrap_no_tmr" &&
            $1 != "axi_tb_tmr_wrap_tmr" &&
            $1 != "opencores_tb" &&
            $1 != "tmr_voters_tb" &&
            $1 != "tmr_counters_tb"} {
            error "Unknown testbench type $1."
        }

        if {$argc == 2} {
            if {$2 != "coverage"} {
                error "Unknown option $2."
            } else {
                quietly set coverage "true"
            }
        }
    } else {
        error "I take one argument only"
    }
}


# Check if UVVM is present
if {![file exists ../extern/UVVM]} {
    error "UVVM missing"
}

# Check if sources for Opencores CAN controller are present
if {[file exists ../extern/can_controller]} {
    quietly set opencores_can_present "true"
} else {
    quietly set opencores_can_present "false"
}

# Check if Wishbone VIP for UVVM is present
if {[file exists "../extern/UVVM/bitvis_vip_wishbone"]} {
    quietly set wishbone_vip_present "true"
} else {
    quietly set wishbone_vip_present "false"
}

quietly set simulate_opencores_tb "false"

# Check if prerequisites are met to simulate Opencores controller
if {$sim_test_bench == "opencores_tb"} {
    if {[string is false -strict $wishbone_vip_present]} {
        error "Can't simulate opencores testbench without Wishbone VIP"
    }

    if {[string is false -strict $opencores_can_present]} {
        error "Can't simulate opencores testbench without sources for opencores CAN"
    }

    quietly set simulate_opencores_tb "true"
}

# If we're simulating all testbenches, check if we have wishbone VIP
# and opencores CAN sources so we can simulate opencores testbench
if {$sim_test_bench == "all_tb"} {
    if {[string is true -strict $wishbone_vip_present] &&
        [string is true -strict $opencores_can_present]} {
        quietly set simulate_opencores_tb "true"
    }
}


echo "\n\nCompile Bitvis UVVM..."
do 01-compile_bitvis_uvvm.do $wishbone_vip_present
echo "\n\nCompile Canola sources..."
do 02-compile_canola_src.do $coverage

if {[string is true -strict $simulate_opencores_tb]} {
    echo "\n\nCompile OpenCores CAN sources..."
    do 03-compile_opencores_can_ctrl_src.do
}


echo "\n\nCompile Canola testbench..."
do 04-compile_canola_tb.do $sim_test_bench $simulate_opencores_tb

echo "\n\nRun simulation..."
do 00-sim_can_ctrl.do $sim_test_bench $simulate_opencores_tb $coverage
