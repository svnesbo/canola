# Compile source for Canola

# Set up util_part_path and lib_name
#------------------------------------------------------
quietly set lib_name "work"
quietly set part_name "canola"
# path from mpf-file in sim
quietly set util_part_path "../..//$part_name"
quietly set current_path [pwd]/../sim
quietly set run_path [pwd]/

# (Re-)Generate library and Compile source files
#--------------------------------------------------
echo "\n\nRe-gen lib and compile $lib_name source"
#echo "$util_part_path/sim/$lib_name"
if {[file exists $run_path/$lib_name]} {
  file delete -force $run_path/$lib_name
}

vlib $run_path/$lib_name
vmap $lib_name $run_path/$lib_name

quietly set coverage_directives_vhdl ""

if {$1 == "true"} {
    quietly set coverage_directives_vhdl "-check_synthesis -fsmdebug -fsmimplicittrans -fsmverbose bw -coverExcludeDefault -cover sbceft3"
}

quietly set compdirectives_vhdl "-quiet -nologo -nostats -O5 -2008 -lint -work $lib_name $coverage_directives_vhdl"




quietly set compdirectives_vlog "-mixedsvvh s -93 -suppress 1346,1236 -quiet -work $lib_name +incdir+$util_part_path/source/rtl/can_controller/"

echo "\n\n\n=== Compiling Canola sources\n"

eval vcom  $compdirectives_vhdl  $util_part_path/source/rtl/tmr_voters/mismatch.vhd
eval vcom  $compdirectives_vhdl  $util_part_path/source/rtl/tmr_voters/tmr_pkg.vhd
eval vcom  $compdirectives_vhdl  $util_part_path/source/rtl/tmr_voters/tmr_voter_pkg.vhd
eval vcom  $compdirectives_vhdl  $util_part_path/source/rtl/tmr_voters/tmr_voter.vhd
eval vcom  $compdirectives_vhdl  $util_part_path/source/rtl/tmr_voters/tmr_voter_triplicated.vhd
eval vcom  $compdirectives_vhdl  $util_part_path/source/rtl/tmr_voters/tmr_voter_array.vhd
eval vcom  $compdirectives_vhdl  $util_part_path/source/rtl/tmr_voters/tmr_voter_triplicated_array.vhd
eval vcom  $compdirectives_vhdl  $util_part_path/source/rtl/counters/counter_saturating.vhd
eval vcom  $compdirectives_vhdl  $util_part_path/source/rtl/counters/up_counter.vhd
eval vcom  $compdirectives_vhdl  $util_part_path/source/rtl/canola_pkg.vhd
eval vcom  $compdirectives_vhdl  $util_part_path/source/rtl/canola_time_quanta_gen.vhd
eval vcom  $compdirectives_vhdl  $util_part_path/source/rtl/canola_crc.vhd
eval vcom  $compdirectives_vhdl  $util_part_path/source/rtl/canola_btl.vhd
eval vcom  $compdirectives_vhdl  $util_part_path/source/rtl/canola_bsp.vhd
eval vcom  $compdirectives_vhdl  $util_part_path/source/rtl/canola_frame_rx_fsm.vhd
eval vcom  $compdirectives_vhdl  $util_part_path/source/rtl/canola_frame_tx_fsm.vhd
eval vcom  $compdirectives_vhdl  $util_part_path/source/rtl/canola_eml.vhd
eval vcom  $compdirectives_vhdl  $util_part_path/source/rtl/canola_top.vhd
eval vcom  $compdirectives_vhdl  $util_part_path/source/rtl/canola_counters.vhd
eval vcom  $compdirectives_vhdl  $util_part_path/source/rtl/axi_slave/axi_pkg.vhd
eval vcom  $compdirectives_vhdl  $util_part_path/source/rtl/axi_slave/canola_axi_slave_pif_pkg.vhd
eval vcom  $compdirectives_vhdl  $util_part_path/source/rtl/axi_slave/canola_axi_slave_axi_pif.vhd
eval vcom  $compdirectives_vhdl  $util_part_path/source/rtl/axi_slave/canola_axi_slave.vhd
eval vcom  $compdirectives_vhdl  $util_part_path/source/rtl/tmr_wrappers/counter_saturating_tmr_wrapper_triplicated.vhd
eval vcom  $compdirectives_vhdl  $util_part_path/source/rtl/tmr_wrappers/up_counter_tmr_wrapper.vhd
eval vcom  $compdirectives_vhdl  $util_part_path/source/rtl/tmr_wrappers/canola_time_quanta_gen_tmr_wrapper.vhd
eval vcom  $compdirectives_vhdl  $util_part_path/source/rtl/tmr_wrappers/canola_bsp_tmr_wrapper.vhd
eval vcom  $compdirectives_vhdl  $util_part_path/source/rtl/tmr_wrappers/canola_btl_tmr_wrapper.vhd
eval vcom  $compdirectives_vhdl  $util_part_path/source/rtl/tmr_wrappers/canola_eml_tmr_wrapper.vhd
eval vcom  $compdirectives_vhdl  $util_part_path/source/rtl/tmr_wrappers/canola_frame_rx_fsm_tmr_wrapper.vhd
eval vcom  $compdirectives_vhdl  $util_part_path/source/rtl/tmr_wrappers/canola_frame_tx_fsm_tmr_wrapper.vhd
eval vcom  $compdirectives_vhdl  $util_part_path/source/rtl/tmr_wrappers/tmr_wrapper_pkg.vhd
eval vcom  $compdirectives_vhdl  $util_part_path/source/rtl/tmr_wrappers/tmr_wrapper_cfg.vhd
eval vcom  $compdirectives_vhdl  $util_part_path/source/rtl/canola_top_tmr.vhd
eval vcom  $compdirectives_vhdl  $util_part_path/source/rtl/canola_counters_tmr.vhd
eval vcom  $compdirectives_vhdl  $util_part_path/source/rtl/axi_slave/canola_axi_slave_tmr.vhd
