set this_dir [file dirname [info script]]
set src_dir [file normalize [file join $this_dir .. src]]
set project_dir [file normalize [file join $this_dir .. ..]]

set_global_assignment -name FAMILY "MAX 10"
set_global_assignment -name DEVICE 10M50DAF484C7G
set_global_assignment -name VHDL_INPUT_VERSION VHDL_2008
set_global_assignment -name TOP_LEVEL_ENTITY fpga1_top
set_global_assignment -name VHDL_FILE [file join $project_dir shared rtl dual_fpga_system_pkg.vhd]
set_global_assignment -name VHDL_FILE [file join $src_dir pkg fpga1_pkg.vhd]
set_global_assignment -name VHDL_FILE [file join $src_dir display bin_to_bcd.vhd]
set_global_assignment -name VHDL_FILE [file join $src_dir display digit_to_7seg_decimal_n.vhd]
set_global_assignment -name VHDL_FILE [file join $src_dir processing sample_normalizer.vhd]
set_global_assignment -name VHDL_FILE [file join $src_dir processing sample_validator.vhd]
set_global_assignment -name VHDL_FILE [file join $src_dir processing sample_noise_monitor.vhd]
set_global_assignment -name VHDL_FILE [file join $src_dir processing sample_classifier.vhd]
set_global_assignment -name VHDL_FILE [file join $src_dir processing threshold_detector.vhd]
set_global_assignment -name VHDL_FILE [file join $src_dir link_tx frame_builder.vhd]
set_global_assignment -name VHDL_FILE [file join $src_dir link_tx uart_tx.vhd]
set_global_assignment -name VHDL_FILE [file join $src_dir top fpga1_top.vhd]

# Pin locations are intentionally omitted here.
# Map the top-level ports to DE10-Lite board pins in Quartus.
