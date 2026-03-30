# Dual FPGA UART Counter Check

This repository is now a minimal two-FPGA DE10-Lite project.

- FPGA1 stays in `IDLE` until a start button pulse, then sends an 8-bit `0..255` counter over UART once.
- FPGA2 receives each byte and compares it against its own expected counter.
- If FPGA2 sees an unexpected value, it latches a mismatch flag.
- Seven-segment outputs are preserved on the wrappers but kept blank for now.
- VGA, sensor, ADC, frame formatting, and statistics logic were removed.

## Folder Layout

```text
fpga-dual-system/
+-- README.md
+-- shared/
|   `-- rtl/
|       `-- dual_fpga_system_pkg.vhd
+-- board/
|   `-- de10_lite/
|       +-- common/
|       |   `-- reset_sync.vhd
|       +-- fpga1/
|       |   `-- de10_lite_fpga1_wrapper.vhd
|       `-- fpga2/
|           `-- de10_lite_fpga2_wrapper.vhd
+-- fpga1_acquisition/
|   +-- src/
|   |   +-- display/
|   |   |   +-- bin_to_bcd.vhd
|   |   |   `-- digit_to_7seg_decimal_n.vhd
|   |   +-- link_tx/
|   |   |   `-- uart_tx.vhd
|   |   `-- top/
|   |       `-- fpga1_top.vhd
|   `-- quartus/
|       +-- add_sources.tcl
|       +-- add_de10_lite_wrapper_sources.tcl
|       +-- de10_lite_fpga1_wrapper.qpf
|       +-- de10_lite_fpga1_wrapper.qsf
|       +-- de10_lite_fpga1_wrapper.sdc
|       `-- de10_lite_placeholder.qsf
+-- fpga2_display/
|   +-- src/
|   |   +-- link_rx/
|   |   |   `-- uart_rx.vhd
|   |   `-- top/
|   |       `-- fpga2_top.vhd
|   `-- quartus/
|       +-- add_sources.tcl
|       +-- add_de10_lite_wrapper_sources.tcl
|       +-- de10_lite_fpga2_wrapper.qpf
|       +-- de10_lite_fpga2_wrapper.qsf
|       +-- de10_lite_fpga2_wrapper.sdc
|       `-- de10_lite_placeholder.qsf
`-- sim/
    `-- tb_uart_counter_link.vhd
```

## LED Behavior

FPGA1 LEDs:
- `LEDR[7:0]`: current counter byte
- `LEDR[8]`: FPGA1 burst active
- `LEDR[9]`: UART transmitter busy

FPGA2 LEDs:
- `LEDR[7:0]`: last received UART byte
- `LEDR[8]`: latched mismatch flag
- `LEDR[9]`: toggles on each received byte

## DE10-Lite Buttons

FPGA1 wrapper inputs:

- `KEY0` on `reset_source_i`: reset
- `KEY1` on `start_button_i`: start one UART counter burst

## Quartus Use

Open one of these projects:

- `fpga1_acquisition/quartus/de10_lite_fpga1_wrapper.qpf`
- `fpga2_display/quartus/de10_lite_fpga2_wrapper.qpf`

The active top levels are:

- `de10_lite_fpga1_wrapper`
- `de10_lite_fpga2_wrapper`

## Simulation

A single integration testbench is provided:

- `sim/tb_uart_counter_link.vhd`

It connects `fpga1_top` UART TX directly to `fpga2_top` UART RX and checks
that the mismatch LED stays low during the test run.
