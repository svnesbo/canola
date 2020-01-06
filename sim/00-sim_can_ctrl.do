#vsim -gui -t ps -novopt work.canola_btl_tb
#do 00-wave_can_ctrl.do
#run -all

#vsim -gui -t ps -novopt work.canola_bsp_tb
#do 00-wave_can_ctrl.do
#run -all

#vsim -gui -t ps -novopt work.canola_eml_tb
#do 00-wave_can_ctrl.do
#run -all

vsim -gui -t ps -novopt work.canola_top_tb
do 00-wave_can_ctrl.do
run -all

#vsim -gui -t ps -novopt work.canola_axi_slave_tb
#do 00-wave_can_ctrl.do
#run -all
