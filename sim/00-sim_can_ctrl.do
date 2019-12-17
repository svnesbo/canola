#vsim -gui -t ps -novopt work.can_btl_tb
#do 00-wave_can_ctrl.do
#run -all

#vsim -gui -t ps -novopt work.can_bsp_tb
#do 00-wave_can_ctrl.do
#run -all

#vsim -gui -t ps -novopt work.can_eml_tb
#do 00-wave_can_ctrl.do
#run -all

#vsim -gui -t ps -novopt work.can_top_tb
#do 00-wave_can_ctrl.do
#run -all

vsim -gui -t ps -novopt work.can_axi_slave_tb
do 00-wave_can_ctrl.do
run -all
