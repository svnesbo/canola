# Compile source for OpenCores CAN controller

# Set up util_part_path and lib_name
#------------------------------------------------------
quietly set lib_name "work"
quietly set part_name "can_controller"
# path from mpf-file in sim
quietly set util_part_path "../extern/$part_name"

# (Re-)Generate library and Compile source files
#--------------------------------------------------
#echo "\n\nRe-gen lib and compile $lib_name source"
#echo "$util_part_path/sim/$lib_name"
#if {[file exists $util_part_path/sim/$lib_name]} {
#  file delete -force $util_part_path/sim/$lib_name
#}

vlib $lib_name
vmap $lib_name $lib_name

quietly set compdirectives_vhdl "-quiet -nologo -nostats -O5 -2008 -lint -work $lib_name"

quietly set compdirectives_vlog "-mixedsvvh s -93 -suppress 1346,1236 -quiet -work $lib_name +incdir+$util_part_path/source/rtl/can_controller/"

echo "\n\n\n=== Compiling $lib_name source\n"

eval vlog  $compdirectives_vlog   $util_part_path/timescale.v
eval vlog  $compdirectives_vlog   $util_part_path/can_defines.v
eval vlog  $compdirectives_vlog   $util_part_path/can_ibo.v
eval vlog  $compdirectives_vlog   $util_part_path/can_crc.v
eval vlog  $compdirectives_vlog   $util_part_path/can_register.v
eval vlog  $compdirectives_vlog   $util_part_path/can_register_asyn.v
eval vlog  $compdirectives_vlog   $util_part_path/can_register_asyn_syn.v
eval vlog  $compdirectives_vlog   $util_part_path/can_register_syn.v
eval vlog  $compdirectives_vlog   $util_part_path/can_acf.v
eval vlog  $compdirectives_vlog   $util_part_path/can_bsp.v
eval vlog  $compdirectives_vlog   $util_part_path/can_btl.v
eval vlog  $compdirectives_vlog   $util_part_path/can_fifo.v
eval vlog  $compdirectives_vlog   $util_part_path/can_registers.v
eval vlog  $compdirectives_vlog   $util_part_path/can_top.v
eval vcom  $compdirectives_vhdl   $util_part_path/can_register_pkg.vhd
