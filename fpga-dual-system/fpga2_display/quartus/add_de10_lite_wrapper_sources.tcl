set this_dir [file dirname [info script]]
set project_dir [file normalize [file join $this_dir .. ..]]

set_global_assignment -name FAMILY "MAX 10"
set_global_assignment -name DEVICE 10M50DAF484C7G
set_global_assignment -name VHDL_INPUT_VERSION VHDL_2008
set_global_assignment -name TOP_LEVEL_ENTITY de10_lite_fpga2_wrapper
set_global_assignment -name SDC_FILE [file join $this_dir de10_lite_fpga2_wrapper.sdc]

set_global_assignment -name VHDL_FILE [file join $project_dir board de10_lite common reset_sync.vhd]
set_global_assignment -name VHDL_FILE [file join $project_dir shared rtl dual_fpga_system_pkg.vhd]
set_global_assignment -name VHDL_FILE [file join $project_dir fpga2_display src pkg fpga2_pkg.vhd]
set_global_assignment -name VHDL_FILE [file join $project_dir fpga2_display src link_rx uart_rx.vhd]
set_global_assignment -name VHDL_FILE [file join $project_dir fpga2_display src link_rx frame_decoder.vhd]
set_global_assignment -name VHDL_FILE [file join $project_dir fpga2_display src control link_statistics.vhd]
set_global_assignment -name VHDL_FILE [file join $project_dir fpga2_display src control status_mapper.vhd]
set_global_assignment -name VHDL_FILE [file join $project_dir fpga2_display src display led_driver.vhd]
set_global_assignment -name VHDL_FILE [file join $project_dir fpga2_display src display vga_timing.vhd]
set_global_assignment -name VHDL_FILE [file join $project_dir fpga2_display src display vga_dashboard.vhd]
set_global_assignment -name VHDL_FILE [file join $project_dir fpga2_display src top fpga2_top.vhd]
set_global_assignment -name VHDL_FILE [file join $project_dir board de10_lite fpga2 de10_lite_fpga2_wrapper.vhd]

# Pin locations and I/O standards are intentionally omitted here.
# Use the companion DE10-Lite placeholder QSF template and fill in the
# board-specific assignments in Quartus.
