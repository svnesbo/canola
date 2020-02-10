# Compiles the bitvis uvvm library sources
# Loads bitvis components listed in bitvis_component_list.txt

# Update relativ path to bitvis library
quietly set bitvis_path ../extern/UVVM
quietly set wishbone_vip_path ../extern/UVVM/bitvis_vip_wishbone
quietly set current_path [pwd]/../sim
quietly set run_path [pwd]/
do $bitvis_path/script/compile_all.do $bitvis_path/script/ $run_path $current_path/bitvis_component_list.txt


if {[file exists $wishbone_vip_path]} {
    echo "\n\nCompiling Bitvis VIP for Wishbone... (used by testbench w/ OpenCores controller.)"
    quietly set wishbone_vip_present "true"
    do $bitvis_path/script/compile_src.do $wishbone_vip_path $run_path
} else {
    echo "\n\nBitvis VIP for Wishbone missing, needed for testbench w/ OpenCores controller."
    quietly set wishbone_vip_present "false"
}
