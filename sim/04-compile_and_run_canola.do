echo "\n\nCompile Bitvis UVVM..."
do 01-compile_bitvis_uvvm.do
echo "\n\nCompile Canola sources..."
do 02-compile_canola_src.do
echo "\n\nCompile Canola testbench..."
do 03-compile_canola_tb.do
echo "\n\nRun simulation..."
do 00-sim_can_ctrl.do
