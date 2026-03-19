# FPGA Dual System

This repository is a starter VHDL codebase for a dual-FPGA design:

- FPGA 1 generates a fake 12-bit sensor sample, evaluates thresholds, and transmits framed UART data.
- FPGA 2 receives the UART frame, decodes it, and updates a small LED status display.

Confirmed target hardware:

- Board: Terasic DE10-Lite
- Device: Intel/Altera MAX 10 `10M50DAF484C7G`
- Default onboard clock: `50 MHz`

The code is written to stay:

- synthesizable
- modular
- beginner-friendly
- vendor-neutral
- easy to import into Quartus later
- neutral about pin naming until Quartus mapping time

## Repository Layout

```text
fpga-dual-system/
+-- README.md
+-- docs/
|   +-- interface_spec.md
|   +-- de10_lite_bringup.md
|   `-- quartus_project_setup.md
+-- board/
|   `-- de10_lite/
|       +-- common/
|       |   `-- reset_sync.vhd
|       +-- fpga1/
|       |   `-- de10_lite_fpga1_wrapper.vhd
|       `-- fpga2/
|           `-- de10_lite_fpga2_wrapper.vhd
+-- shared/
|   `-- protocol/
|       `-- frame_format.md
+-- fpga1_acquisition/
|   +-- src/
|   |   +-- top/
|   |   |   `-- fpga1_top.vhd
|   |   +-- processing/
|   |   |   +-- fake_sensor_gen.vhd
|   |   |   `-- threshold_detector.vhd
|   |   +-- link_tx/
|   |   |   +-- frame_builder.vhd
|   |   |   `-- uart_tx.vhd
|   |   `-- pkg/
|   |       `-- fpga1_pkg.vhd
|   +-- sim/
|   |   +-- tb_fpga1_top.vhd
|   |   `-- uart_rx_monitor.vhd
|   `-- quartus/
|       +-- add_sources.tcl
|       +-- add_de10_lite_wrapper_sources.tcl
|       `-- de10_lite_placeholder.qsf
`-- fpga2_display/
    +-- src/
    |   +-- top/
    |   |   `-- fpga2_top.vhd
    |   +-- link_rx/
    |   |   +-- uart_rx.vhd
    |   |   `-- frame_decoder.vhd
    |   +-- display/
    |   |   `-- led_driver.vhd
    |   +-- control/
    |   |   `-- status_mapper.vhd
    |   `-- pkg/
    |       `-- fpga2_pkg.vhd
    +-- sim/
    |   `-- tb_fpga2_top.vhd
    `-- quartus/
        +-- add_sources.tcl
        +-- add_de10_lite_wrapper_sources.tcl
        `-- de10_lite_placeholder.qsf
```

## Design Notes

- UART framing is fixed at 5 bytes: `0xAA`, sample high byte, sample low nibble in a byte, flags byte, `0x55`.
- Thresholds are handled in FPGA 1 before transmission.
- FPGA 2 only updates the LEDs when a full valid frame is decoded.
- All logic uses synchronous processes with explicit reset behavior.

## Suggested Compile Order

### FPGA 1 Design

1. `fpga1_acquisition/src/pkg/fpga1_pkg.vhd`
2. `fpga1_acquisition/src/processing/fake_sensor_gen.vhd`
3. `fpga1_acquisition/src/processing/threshold_detector.vhd`
4. `fpga1_acquisition/src/link_tx/frame_builder.vhd`
5. `fpga1_acquisition/src/link_tx/uart_tx.vhd`
6. `fpga1_acquisition/src/top/fpga1_top.vhd`

Simulation extras:

- `fpga1_acquisition/sim/uart_rx_monitor.vhd`
- `fpga1_acquisition/sim/tb_fpga1_top.vhd`

### FPGA 2 Design

1. `fpga2_display/src/pkg/fpga2_pkg.vhd`
2. `fpga2_display/src/link_rx/uart_rx.vhd`
3. `fpga2_display/src/link_rx/frame_decoder.vhd`
4. `fpga2_display/src/control/status_mapper.vhd`
5. `fpga2_display/src/display/led_driver.vhd`
6. `fpga2_display/src/top/fpga2_top.vhd`

Simulation extras:

- `fpga2_display/sim/tb_fpga2_top.vhd`

### Cross-Partition Integration Simulation

Compile after both FPGA 1 and FPGA 2 source sets:

- `sim/tb_fpga1_fpga2_integration.vhd`

See `docs/quartus_project_setup.md` for the exact Quartus project split and import steps.
See `docs/de10_lite_bringup.md` for the wrapper-based DE10-Lite bring-up path.
For manual first-board setup choices, use the simple bring-up checklist in `docs/de10_lite_bringup.md`.

## Phase 1 Scope

This phase uses `fake_sensor_gen.vhd` instead of a real ADC. The next logical milestone is replacing that block with a real ADC interface while preserving the frame format and the FPGA 2 receive/display path.

For the DE10-Lite target, that future ADC step should use the MAX 10 integrated ADC path on the board rather than assuming an external ADC chip.
