# Compile testbench sources for Canola

# Set up util_part_path and lib_name
#------------------------------------------------------
quietly set lib_name "work"
quietly set part_name "canola"
# path from mpf-file in sim
quietly set util_part_path "../..//$part_name"
quietly set current_path [pwd]/../sim
quietly set run_path [pwd]/

vlib $run_path/$lib_name
vmap $lib_name $run_path/$lib_name

quietly set compdirectives_vhdl "-quiet -nologo -nostats -O5 -2008 -lint -work $lib_name"

echo "\n\n\n=== Compiling testbench sources\n"

eval vcom  $compdirectives_vhdl   $util_part_path/source/bench/can_bfm/can_bfm_pkg.vhd
eval vcom  $compdirectives_vhdl   $util_part_path/source/bench/can_bfm/can_uvvm_bfm_pkg.vhd
eval vcom  $compdirectives_vhdl   $util_part_path/source/bench/canola_tb_pkg.vhd
eval vcom  $compdirectives_vhdl   $util_part_path/source/bench/canola_btl_tb.vhd
eval vcom  $compdirectives_vhdl   $util_part_path/source/bench/canola_bsp_tb.vhd
eval vcom  $compdirectives_vhdl   $util_part_path/source/bench/canola_eml_tb.vhd
eval vcom  $compdirectives_vhdl   $util_part_path/source/bench/canola_top_tb.vhd
eval vcom  $compdirectives_vhdl   $util_part_path/source/bench/canola_axi_slave_tb.vhd
eval vcom  $compdirectives_vhdl   $util_part_path/source/bench/tmr_voters_tb.vhd
eval vcom  $compdirectives_vhdl   $util_part_path/source/bench/tmr_counters_tb.vhd

if {$1 == "opencores_tb" || ($1 == "all_tb" && $2 == "true")} {
    eval vcom  $compdirectives_vhdl   $util_part_path/source/bench/canola_vs_opencores_can_tb.vhd
}
