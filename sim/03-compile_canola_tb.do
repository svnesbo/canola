# Compile testbench sources for Canola

# Set up util_part_path and lib_name
#------------------------------------------------------
quietly set lib_name "work"
quietly set part_name "canola"
# path from mpf-file in sim
quietly set util_part_path "../..//$part_name"

vlib $util_part_path/sim/$lib_name
vmap $lib_name $util_part_path/sim/$lib_name

quietly set compdirectives_vhdl "-quiet -nologo -nostats -O5 -2008 -lint -work $lib_name"

echo "\n\n\n=== Compiling $lib_name source\n"

eval vcom  $compdirectives_vhdl   $util_part_path/source/bench/can_bfm/can_bfm_pkg.vhd
eval vcom  $compdirectives_vhdl   $util_part_path/source/bench/can_bfm/can_uvvm_bfm_pkg.vhd
eval vcom  $compdirectives_vhdl   $util_part_path/source/bench/can_tb_pkg.vhd
eval vcom  $compdirectives_vhdl   $util_part_path/source/bench/can_btl_tb.vhd
eval vcom  $compdirectives_vhdl   $util_part_path/source/bench/can_bsp_tb.vhd
eval vcom  $compdirectives_vhdl   $util_part_path/source/bench/can_eml_tb.vhd
eval vcom  $compdirectives_vhdl   $util_part_path/source/bench/can_top_tb.vhd
eval vcom  $compdirectives_vhdl   $util_part_path/source/bench/can_axi_slave_tb.vhd
