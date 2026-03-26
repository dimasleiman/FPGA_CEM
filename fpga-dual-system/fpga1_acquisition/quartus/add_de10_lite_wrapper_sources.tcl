set this_dir [file dirname [info script]]
set project_dir [file normalize [file join $this_dir .. ..]]

set_global_assignment -name FAMILY "MAX 10"
set_global_assignment -name DEVICE 10M50DAF484C7G
set_global_assignment -name VHDL_INPUT_VERSION VHDL_2008
set_global_assignment -name TOP_LEVEL_ENTITY de10_lite_fpga1_wrapper
set_global_assignment -name SDC_FILE [file join $this_dir de10_lite_fpga1_wrapper.sdc]

set_global_assignment -name VHDL_FILE [file join $project_dir board de10_lite common reset_sync.vhd]
set_global_assignment -name VHDL_FILE [file join $project_dir shared rtl dual_fpga_system_pkg.vhd]
set_global_assignment -name VHDL_FILE [file join $project_dir fpga1_acquisition src pkg fpga1_pkg.vhd]
set_global_assignment -name VHDL_FILE [file join $project_dir fpga1_acquisition src display bin_to_bcd.vhd]
set_global_assignment -name VHDL_FILE [file join $project_dir fpga1_acquisition src display digit_to_7seg_decimal_n.vhd]
set_global_assignment -name VHDL_FILE [file join $project_dir fpga1_acquisition src processing fake_sensor_gen.vhd]
set_global_assignment -name VHDL_FILE [file join $project_dir fpga1_acquisition src processing sample_normalizer.vhd]
set_global_assignment -name VHDL_FILE [file join $project_dir fpga1_acquisition src processing sample_validator.vhd]
set_global_assignment -name VHDL_FILE [file join $project_dir fpga1_acquisition src processing sample_noise_monitor.vhd]
set_global_assignment -name VHDL_FILE [file join $project_dir fpga1_acquisition src processing sample_classifier.vhd]
set_global_assignment -name VHDL_FILE [file join $project_dir fpga1_acquisition src processing threshold_detector.vhd]
set_global_assignment -name VHDL_FILE [file join $project_dir fpga1_acquisition src link_tx frame_builder.vhd]
set_global_assignment -name VHDL_FILE [file join $project_dir fpga1_acquisition src link_tx uart_tx.vhd]
set_global_assignment -name VHDL_FILE [file join $project_dir fpga1_acquisition src top fpga1_top.vhd]
set_global_assignment -name VHDL_FILE [file join $project_dir board de10_lite fpga1 max10_adc_frontend.vhd]
set_global_assignment -name VERILOG_FILE [file join $project_dir board de10_lite fpga1 ip altera_up_avalon_adv_adc.v]
set_global_assignment -name VERILOG_FILE [file join $project_dir board de10_lite fpga1 ip altera_modular_adc_control.v]
set_global_assignment -name VERILOG_FILE [file join $project_dir board de10_lite fpga1 ip altera_modular_adc_control_avrg_fifo.v]
set_global_assignment -name VERILOG_FILE [file join $project_dir board de10_lite fpga1 ip altera_modular_adc_control_fsm.v]
set_global_assignment -name VERILOG_FILE [file join $project_dir board de10_lite fpga1 ip altera_modular_adc_sample_store.v]
set_global_assignment -name VERILOG_FILE [file join $project_dir board de10_lite fpga1 ip altera_modular_adc_sample_store_ram.v]
set_global_assignment -name VERILOG_FILE [file join $project_dir board de10_lite fpga1 ip altera_modular_adc_sequencer.v]
set_global_assignment -name VERILOG_FILE [file join $project_dir board de10_lite fpga1 ip altera_modular_adc_sequencer_csr.v]
set_global_assignment -name VERILOG_FILE [file join $project_dir board de10_lite fpga1 ip altera_modular_adc_sequencer_ctrl.v]
set_global_assignment -name VERILOG_FILE [file join $project_dir board de10_lite fpga1 ip chsel_code_converter_sw_to_hw.v]
set_global_assignment -name VERILOG_FILE [file join $project_dir board de10_lite fpga1 ip DE10_Lite_ADC_Core_modular_adc_0.v]
set_global_assignment -name VERILOG_FILE [file join $project_dir board de10_lite fpga1 ip fiftyfivenm_adcblock_primitive_wrapper.v]
set_global_assignment -name VERILOG_FILE [file join $project_dir board de10_lite fpga1 ip fiftyfivenm_adcblock_top_wrapper.v]
set_global_assignment -name VHDL_FILE [file join $project_dir board de10_lite fpga1 de10_lite_fpga1_wrapper.vhd]

# Pin locations and I/O standards are intentionally omitted here.
# Use the companion DE10-Lite placeholder QSF template and fill in the
# board-specific assignments in Quartus.
