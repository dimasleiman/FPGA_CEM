set this_dir [file dirname [info script]]
set src_dir [file normalize [file join $this_dir .. src]]
set project_dir [file normalize [file join $this_dir .. ..]]

set_global_assignment -name FAMILY "MAX 10"
set_global_assignment -name DEVICE 10M50DAF484C7G
set_global_assignment -name VHDL_INPUT_VERSION VHDL_2008
set_global_assignment -name TOP_LEVEL_ENTITY fpga2_top
set_global_assignment -name VHDL_FILE [file join $project_dir shared rtl dual_fpga_system_pkg.vhd]
set_global_assignment -name VHDL_FILE [file join $src_dir pkg fpga2_pkg.vhd]
set_global_assignment -name VHDL_FILE [file join $src_dir link_rx uart_rx.vhd]
set_global_assignment -name VHDL_FILE [file join $src_dir link_rx frame_decoder.vhd]
set_global_assignment -name VHDL_FILE [file join $src_dir control link_statistics.vhd]
set_global_assignment -name VHDL_FILE [file join $src_dir control status_mapper.vhd]
set_global_assignment -name VHDL_FILE [file join $src_dir display led_driver.vhd]
set_global_assignment -name VHDL_FILE [file join $src_dir display vga_timing.vhd]
set_global_assignment -name VHDL_FILE [file join $src_dir display vga_dashboard.vhd]
set_global_assignment -name VHDL_FILE [file join $src_dir top fpga2_top.vhd]

# Pin locations are intentionally omitted here.
# Map the top-level ports to DE10-Lite board pins in Quartus.
