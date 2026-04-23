set this_dir [file dirname [info script]]
set src_dir [file normalize [file join $this_dir .. src]]
set project_dir [file normalize [file join $this_dir .. ..]]

set_global_assignment -name FAMILY "MAX 10"
set_global_assignment -name DEVICE 10M50DAF484C7G
set_global_assignment -name VHDL_INPUT_VERSION VHDL_2008
set_global_assignment -name TOP_LEVEL_ENTITY fpga2_top
set_global_assignment -name VHDL_FILE [file join $project_dir shared rtl dual_fpga_system_pkg.vhd]
set_global_assignment -name VHDL_FILE [file join $project_dir fpga1_acquisition src display bin_to_bcd.vhd]
set_global_assignment -name VHDL_FILE [file join $project_dir fpga1_acquisition src display digit_to_7seg_decimal_n.vhd]
set_global_assignment -name VHDL_FILE [file join $src_dir link_rx uart_rx.vhd]
set_global_assignment -name VHDL_FILE [file join $src_dir top fpga2_top.vhd]
