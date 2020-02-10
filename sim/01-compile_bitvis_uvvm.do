# Compiles the bitvis uvvm library sources
# Loads bitvis components listed in bitvis_component_list.txt

# Update relativ path to bitvis library
quietly set bitvis_path ../extern/UVVM
quietly set current_path [pwd]/../sim
quietly set run_path [pwd]/
do $bitvis_path/script/compile_all.do $bitvis_path/script/ $run_path $current_path/bitvis_component_list.txt

if {[file exists $bitvis_path/bitvis_vip_wishbone]} {
    echo "\n\nCompiling Bitvis VIP for Wishbone... (used by testbench w/ OpenCores controller.)"
    quietly set simulate_opencore_can "true"
    do $bitvis_path/script/compile_src.do $bitvis_path/bitvis_vip_wishbone $current_path
} else {
    echo "\n\nBitvis VIP for Wishbone missing, needed for testbench w/ OpenCores controller."
    quietly set simulate_opencore_can "false"
}
