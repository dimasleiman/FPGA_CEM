set this_dir [file dirname [info script]]
set project_dir [file normalize [file join $this_dir .. ..]]

set_global_assignment -name FAMILY "MAX 10"
set_global_assignment -name DEVICE 10M50DAF484C7G
set_global_assignment -name VHDL_INPUT_VERSION VHDL_2008
set_global_assignment -name TOP_LEVEL_ENTITY de10_lite_fpga1_wrapper
set_global_assignment -name SDC_FILE [file join $this_dir de10_lite_fpga1_wrapper.sdc]

set_global_assignment -name VHDL_FILE [file join $project_dir board de10_lite common reset_sync.vhd]
set_global_assignment -name VHDL_FILE [file join $project_dir shared rtl dual_fpga_system_pkg.vhd]
set_global_assignment -name VHDL_FILE [file join $project_dir fpga1_acquisition src display bin_to_bcd.vhd]
set_global_assignment -name VHDL_FILE [file join $project_dir fpga1_acquisition src display digit_to_7seg_decimal_n.vhd]
set_global_assignment -name VHDL_FILE [file join $project_dir fpga1_acquisition src link_tx uart_tx.vhd]
set_global_assignment -name VHDL_FILE [file join $project_dir fpga1_acquisition src top fpga1_top.vhd]
set_global_assignment -name VHDL_FILE [file join $project_dir board de10_lite fpga1 de10_lite_fpga1_wrapper.vhd]
