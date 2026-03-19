set this_dir [file dirname [info script]]
set project_dir [file normalize [file join $this_dir .. ..]]

set_global_assignment -name FAMILY "MAX 10"
set_global_assignment -name DEVICE 10M50DAF484C7G
set_global_assignment -name TOP_LEVEL_ENTITY de10_lite_fpga1_wrapper

set_global_assignment -name VHDL_FILE [file join $project_dir board de10_lite common reset_sync.vhd]
set_global_assignment -name VHDL_FILE [file join $project_dir fpga1_acquisition src pkg fpga1_pkg.vhd]
set_global_assignment -name VHDL_FILE [file join $project_dir fpga1_acquisition src processing fake_sensor_gen.vhd]
set_global_assignment -name VHDL_FILE [file join $project_dir fpga1_acquisition src processing threshold_detector.vhd]
set_global_assignment -name VHDL_FILE [file join $project_dir fpga1_acquisition src link_tx frame_builder.vhd]
set_global_assignment -name VHDL_FILE [file join $project_dir fpga1_acquisition src link_tx uart_tx.vhd]
set_global_assignment -name VHDL_FILE [file join $project_dir fpga1_acquisition src top fpga1_top.vhd]
set_global_assignment -name VHDL_FILE [file join $project_dir board de10_lite fpga1 de10_lite_fpga1_wrapper.vhd]

# Pin locations and I/O standards are intentionally omitted here.
# Use the companion DE10-Lite placeholder QSF template and fill in the
# board-specific assignments in Quartus.
