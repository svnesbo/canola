echo "\n\nCompile Bitvis UVVM..."
do 01-compile_bitvis_uvvm.do
echo "\n\nCompile Canola sources..."
do 02-compile_canola_src.do

if {[file exists ../contrib/can_controller]} {
    echo "\n\nCompile OpenCores CAN sources..."
    quietly set opencore_can_present "true"
    do 03-compile_opencores_can_ctrl_src.do
} else {
    quietly set opencore_can_present "false"
}

echo "\n\nCompile Canola testbench..."
do 04-compile_canola_tb.do
echo "\n\nRun simulation..."
do 00-sim_can_ctrl.do
