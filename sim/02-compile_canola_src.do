# Compile source for Canola

# Set up util_part_path and lib_name
#------------------------------------------------------
quietly set lib_name "work"
quietly set part_name "canola"
# path from mpf-file in sim
quietly set util_part_path "../..//$part_name"

# (Re-)Generate library and Compile source files
#--------------------------------------------------
echo "\n\nRe-gen lib and compile $lib_name source"
#echo "$util_part_path/sim/$lib_name"
if {[file exists $util_part_path/sim/$lib_name]} {
  file delete -force $util_part_path/sim/$lib_name
}

vlib $util_part_path/sim/$lib_name
vmap $lib_name $util_part_path/sim/$lib_name

quietly set compdirectives_vhdl "-quiet -nologo -nostats -O5 -2008 -lint -work $lib_name"

quietly set compdirectives_vlog "-mixedsvvh s -93 -suppress 1346,1236 -quiet -work $lib_name +incdir+$util_part_path/source/rtl/can_controller/"

echo "\n\n\n=== Compiling $lib_name source\n"

eval vcom  $compdirectives_vhdl   $util_part_path/source/rtl/can_pkg.vhd
eval vcom  $compdirectives_vhdl   $util_part_path/source/rtl/can_time_quanta_gen.vhd
eval vcom  $compdirectives_vhdl   $util_part_path/source/rtl/can_crc.vhd
eval vcom  $compdirectives_vhdl   $util_part_path/source/rtl/can_btl.vhd
eval vcom  $compdirectives_vhdl   $util_part_path/source/rtl/can_bsp.vhd
eval vcom  $compdirectives_vhdl   $util_part_path/source/rtl/can_rx_fsm.vhd
eval vcom  $compdirectives_vhdl   $util_part_path/source/rtl/can_tx_fsm.vhd
eval vcom  $compdirectives_vhdl   $util_part_path/source/rtl/can_eml.vhd
eval vcom  $compdirectives_vhdl   $util_part_path/source/rtl/can_top.vhd
