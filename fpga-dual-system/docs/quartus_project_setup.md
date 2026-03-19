# Quartus Project Setup

Create two separate Quartus projects so each FPGA can be built independently.

Confirmed hardware target for both projects:

- Board: Terasic DE10-Lite
- Device: Intel/Altera MAX 10 `10M50DAF484C7G`
- Clock source: onboard `50 MHz`

The source-controlled Quartus inputs in this repository are:

- wrapper and core VHDL source files
- `add_sources.tcl` / `add_de10_lite_wrapper_sources.tcl`
- `de10_lite_placeholder.qsf`

Treat any local Quartus-generated `db/`, `output_files/`, `.qws`, or auto-generated
project revision content as a convenience copy and prefer the wrapper VHDL, Tcl
scripts, and placeholder `.qsf` files as the repository source of truth.

## FPGA 1 Project

- Project directory: `fpga1_acquisition/quartus/`
- Core top-level entity: `fpga1_top`
- DE10-Lite wrapper top-level entity: `de10_lite_fpga1_wrapper`
- Design role: acquisition and UART transmission

Source files, in compile order:

1. `fpga1_acquisition/src/pkg/fpga1_pkg.vhd`
2. `fpga1_acquisition/src/processing/fake_sensor_gen.vhd`
3. `fpga1_acquisition/src/processing/threshold_detector.vhd`
4. `fpga1_acquisition/src/link_tx/frame_builder.vhd`
5. `fpga1_acquisition/src/link_tx/uart_tx.vhd`
6. `fpga1_acquisition/src/top/fpga1_top.vhd`

Helper script:

- `fpga1_acquisition/quartus/add_sources.tcl`
- `fpga1_acquisition/quartus/add_de10_lite_wrapper_sources.tcl`

Both scripts set the family, exact device, top-level entity, and `VHDL_2008`
input mode before adding synthesis sources.

Placeholder constraints:

- `fpga1_acquisition/quartus/de10_lite_placeholder.qsf`

Simulation-only files to keep out of the Quartus project:

- `fpga1_acquisition/sim/uart_rx_monitor.vhd`
- `fpga1_acquisition/sim/tb_fpga1_top.vhd`

## FPGA 2 Project

- Project directory: `fpga2_display/quartus/`
- Core top-level entity: `fpga2_top`
- DE10-Lite wrapper top-level entity: `de10_lite_fpga2_wrapper`
- Design role: UART reception and LED display

Source files, in compile order:

1. `fpga2_display/src/pkg/fpga2_pkg.vhd`
2. `fpga2_display/src/link_rx/uart_rx.vhd`
3. `fpga2_display/src/link_rx/frame_decoder.vhd`
4. `fpga2_display/src/control/status_mapper.vhd`
5. `fpga2_display/src/display/led_driver.vhd`
6. `fpga2_display/src/top/fpga2_top.vhd`

Helper script:

- `fpga2_display/quartus/add_sources.tcl`
- `fpga2_display/quartus/add_de10_lite_wrapper_sources.tcl`

Both scripts set the family, exact device, top-level entity, and `VHDL_2008`
input mode before adding synthesis sources.

Placeholder constraints:

- `fpga2_display/quartus/de10_lite_placeholder.qsf`

Simulation-only files to keep out of the Quartus project:

- `fpga2_display/sim/tb_fpga2_top.vhd`

## Quartus Import Sequence

For each FPGA:

1. Create a new Quartus project in the matching `quartus/` directory.
2. Select the DE10-Lite wrapper top-level entity listed above.
3. Set the target device to `10M50DAF484C7G` if the project wizard has not already done so.
4. Source the local `add_de10_lite_wrapper_sources.tcl` script from the Quartus Tcl console.
5. Copy the local `de10_lite_placeholder.qsf` content into the project `.qsf`, or transfer the same placeholder assignments manually.
6. Confirm the imported assignments still show `MAX 10`, `10M50DAF484C7G`, and `VHDL_2008`.
7. Fill in the exact DE10-Lite pin locations and I/O standards in the `.qsf`.
8. Map `clock_50_i` to the DE10-Lite 50 MHz clock input.
9. Map `reset_source_i` to a chosen switch or push-button and set `G_RESET_ACTIVE_LEVEL` to match that source.
10. Map `uart_tx_o` and `uart_rx_i` to the chosen board-to-board GPIO path.
11. For FPGA 2, map `leds_o(3 downto 0)` to any four of the DE10-Lite user LEDs.
12. Compile.

## Cross-FPGA Connection

- Connect FPGA 1 `uart_tx_o` to FPGA 2 `uart_rx_i`
- Share a common ground between boards
- Keep both FPGA projects on the same UART baud-rate setting
- Do not add pin assignments until you decide the exact GPIO path between the two DE10-Lite boards

## Current Scope Versus Board Resources

- Current code uses only clock, reset, UART link, and four status LEDs.
- The remaining DE10-Lite LEDs, switches, push-buttons, seven-segment displays, VGA, and Arduino analog header are available for later phases.
- When the fake sensor is replaced, prefer the MAX 10 integrated ADC path on the DE10-Lite instead of assuming an external ADC device.

## Reset Note

- The board wrapper now converts a chosen board-facing reset source into the active-high synchronous reset expected by the core RTL.
- The synchronizer samples reset on `clock_50_i`, so assertion and release are both synchronous to the board clock.
- With the current wrapper configuration, reset stays active until the external source has been inactive for two clock cycles.
- The wrapper does not debounce a push-button input.
- For first hardware bring-up, a switch is the simpler reset source.

## Simulation Compile Note

- The end-to-end integration testbench is `sim/tb_fpga1_fpga2_integration.vhd`.
- Compile it only after both FPGA 1 and FPGA 2 source sets and packages are already in the work library.
- The wrapper-level bring-up testbench is `sim/tb_de10_lite_wrappers.vhd`.
- Compile it after `board/de10_lite/common/reset_sync.vhd`, both source sets, and both DE10-Lite wrapper entities.
