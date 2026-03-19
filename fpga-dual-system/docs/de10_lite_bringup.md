# DE10-Lite Bring-Up Preparation

This repository now separates three layers:

## 1. Core RTL

These files are board-neutral and should remain reusable:

- `fpga1_acquisition/src/...`
- `fpga2_display/src/...`

Core top entities:

- `fpga1_top`
- `fpga2_top`

They expect:

- `clk`: clean system clock
- `rst`: active-high synchronous reset

## 2. Board Wrapper

These files adapt the core to the DE10-Lite board shape:

- `board/de10_lite/common/reset_sync.vhd`
- `board/de10_lite/fpga1/de10_lite_fpga1_wrapper.vhd`
- `board/de10_lite/fpga2/de10_lite_fpga2_wrapper.vhd`

Wrapper top entities:

- `de10_lite_fpga1_wrapper`
- `de10_lite_fpga2_wrapper`

They expose only placeholder board-facing ports to be mapped in Quartus:

- `clock_50_i`
- `reset_source_i`
- `uart_tx_o` or `uart_rx_i`
- `leds_o(3 downto 0)` for FPGA 2

## 3. Quartus Placeholder Constraints

Per-project files:

- `fpga1_acquisition/quartus/add_de10_lite_wrapper_sources.tcl`
- `fpga1_acquisition/quartus/de10_lite_placeholder.qsf`
- `fpga2_display/quartus/add_de10_lite_wrapper_sources.tcl`
- `fpga2_display/quartus/de10_lite_placeholder.qsf`

These set the device family and top-level wrapper but intentionally leave all
pin locations and I/O standards for manual completion.

These files, together with the wrapper VHDL, are the source-controlled bring-up
inputs. If a local Quartus-generated `db/`, `output_files/`, `.qws`, or project
revision file also exists, treat it as a convenience copy and prefer these
source-controlled files as the repository source of truth.

## Reset Strategy

The DE10-Lite wrapper converts a board-facing reset source into the
active-high synchronous reset expected by the core.

Current wrapper behavior:

- `reset_source_i` is treated as an external board signal
- `G_RESET_ACTIVE_LEVEL` defines whether that source is active-high or active-low
- `reset_sync.vhd` samples reset on `clock_50_i`, so assertion and release are both synchronous
- with the current wrapper default of two stages, reset remains active until the external source has been inactive for two clock cycles
- the wrapper passes the synchronized active-high reset into the core `rst`

What this does not do yet:

- no debounce
- no selection between switch and push-button is forced
- no exact polarity is assumed for your final board mapping

Practical recommendation:

- for first bring-up, use a stable switch as `reset_source_i`
- hold the chosen reset source steady long enough to span multiple `clock_50_i` edges during release
- if you prefer a push-button later, consider adding a debouncer after basic bring-up succeeds

## Simple First Bring-Up Plan

Use the same basic strategy on both DE10-Lite boards:

- clock source: map `clock_50_i` to the board `CLOCK_50`
- reset source: map `reset_source_i` to one chosen slide switch
- UART link:
  - FPGA 1 board: map `uart_tx_o` to one chosen GPIO output pin
  - FPGA 2 board: map `uart_rx_i` to one chosen GPIO input pin
- FPGA 2 display: map `leds_o(3 downto 0)` to any four user LEDs

Recommended first bring-up choices:

- use the onboard `CLOCK_50` on both boards
- use one slide switch per board as reset
- use one direct board-to-board GPIO wire for UART
- use four adjacent LEDs on FPGA 2 if convenient

Board-to-board wiring for the first test:

- FPGA 1 chosen UART TX GPIO pin -> FPGA 2 chosen UART RX GPIO pin
- common ground between the two boards

## Manual QSF Fill-In: FPGA 1

In `fpga1_acquisition/quartus/de10_lite_placeholder.qsf`, fill in:

1. `clock_50_i`
   Replace `<CLOCK_50_PIN>` with the exact DE10-Lite `CLOCK_50` pin location.
   Replace `"<FILL_ME>"` with the I/O standard required by that clock pin setup.

2. `reset_source_i`
   Replace `<RESET_SOURCE_PIN>` with the exact pin location of your chosen slide switch.
   Replace `"<FILL_ME>"` with the correct I/O standard for that switch input.

3. `uart_tx_o`
   Replace `<UART_TX_PIN>` with the exact GPIO/header pin you chose for FPGA 1 transmit.
   Replace `"<FILL_ME>"` with the correct I/O standard for that output pin.

4. Optional generic override
   In Quartus, set wrapper generic `G_RESET_ACTIVE_LEVEL` to match the switch behavior you want.
   If your chosen switch should assert reset when driven low, keep the default `'0'`.
   If your chosen switch should assert reset when driven high, change it to `'1'`.

The placeholder file already fixes the family, exact device, top-level wrapper,
and `VHDL_2008` input mode. Only fill in the unresolved board-specific items.

## Manual QSF Fill-In: FPGA 2

In `fpga2_display/quartus/de10_lite_placeholder.qsf`, fill in:

1. `clock_50_i`
   Replace `<CLOCK_50_PIN>` with the exact DE10-Lite `CLOCK_50` pin location.
   Replace `"<FILL_ME>"` with the I/O standard required by that clock pin setup.

2. `reset_source_i`
   Replace `<RESET_SOURCE_PIN>` with the exact pin location of your chosen slide switch.
   Replace `"<FILL_ME>"` with the correct I/O standard for that switch input.

3. `uart_rx_i`
   Replace `<UART_RX_PIN>` with the exact GPIO/header pin you chose for FPGA 2 receive.
   Replace `"<FILL_ME>"` with the correct I/O standard for that input pin.

4. `leds_o(3 downto 0)`
   Replace `<LED0_PIN>` through `<LED3_PIN>` with the exact pin locations for the four chosen LEDs.
   Replace each `"<FILL_ME>"` with the correct I/O standard for those LED output pins.

5. Optional generic override
   In Quartus, set wrapper generic `G_RESET_ACTIVE_LEVEL` to match the switch behavior you want.
   If your chosen switch should assert reset when driven low, keep the default `'0'`.
   If your chosen switch should assert reset when driven high, change it to `'1'`.

The placeholder file already fixes the family, exact device, top-level wrapper,
and `VHDL_2008` input mode. Only fill in the unresolved board-specific items.

## Quartus Checklist: FPGA 1 Board

1. Create or open the Quartus project in `fpga1_acquisition/quartus/`.
2. Confirm device `10M50DAF484C7G`.
3. Set the top-level entity to `de10_lite_fpga1_wrapper`.
4. Run `source add_de10_lite_wrapper_sources.tcl` in the Quartus Tcl console.
5. Copy the placeholder assignments from `de10_lite_placeholder.qsf` into the project `.qsf`, or enter them manually.
6. Confirm the imported assignments still show `MAX 10`, `10M50DAF484C7G`, and `VHDL_2008`.
7. Fill in the exact pin and I/O standard for `clock_50_i`.
8. Fill in the exact pin and I/O standard for `reset_source_i`.
9. Fill in the exact pin and I/O standard for `uart_tx_o`.
10. Set `G_RESET_ACTIVE_LEVEL` if needed.
11. Compile.

## Quartus Checklist: FPGA 2 Board

1. Create or open the Quartus project in `fpga2_display/quartus/`.
2. Confirm device `10M50DAF484C7G`.
3. Set the top-level entity to `de10_lite_fpga2_wrapper`.
4. Run `source add_de10_lite_wrapper_sources.tcl` in the Quartus Tcl console.
5. Copy the placeholder assignments from `de10_lite_placeholder.qsf` into the project `.qsf`, or enter them manually.
6. Confirm the imported assignments still show `MAX 10`, `10M50DAF484C7G`, and `VHDL_2008`.
7. Fill in the exact pin and I/O standard for `clock_50_i`.
8. Fill in the exact pin and I/O standard for `reset_source_i`.
9. Fill in the exact pin and I/O standard for `uart_rx_i`.
10. Fill in the exact pin and I/O standard for `leds_o(3 downto 0)`.
11. Set `G_RESET_ACTIVE_LEVEL` if needed.
12. Compile.

## What You Still Need To Fill In Manually In Quartus

For each FPGA project:

1. choose whether the reset source is a switch or push-button
2. decide the active level for that chosen reset source
3. fill in the exact DE10-Lite pin locations
4. fill in the I/O standard assignments
5. choose the exact GPIO/header path for the board-to-board UART link
6. for FPGA 2, choose which four of the ten LEDs drive `leds_o(3 downto 0)`

## Wrapper-Level Simulation

Before hardware bring-up, you can simulate the wrapper path with:

- `sim/tb_de10_lite_wrappers.vhd`

That testbench keeps the core RTL separate, instantiates both DE10-Lite wrappers,
and checks that the active-low board-facing reset source still produces the
expected FPGA1-to-FPGA2 UART/LED behavior through the synchronized reset path.
