# FPGA_CEM

## Project Objective

This repository contains a dual-FPGA setup used to evaluate the immunity of a wired digital link against electromagnetic waves.

The active hardware design is located in:

- `fpga-dual-system/`

The test bench uses two Terasic DE10-Lite boards connected together:

- FPGA1 transmits a known UART sequence
- FPGA2 receives the sequence, checks it, and counts communication errors

The purpose is to expose the setup to EM waves and observe whether the link is still reliable or whether transmission errors appear.

## Test Concept

The two boards are connected with:

- one UART data line
- one synchronization line
- one common ground connection

FPGA1 sends bursts of bytes from `0` to `255`.
FPGA2 verifies the received values and increments an error counter when the received byte does not match the expected byte.

This gives a simple visual result during immunity testing:

- no error: the link remains robust
- non-zero error count: the EM environment disturbed the communication

## Hardware Platform

- Board: Terasic DE10-Lite
- Device: `10M50DAF484C7G`
- Clock: `50 MHz`
- UART baud rate: `115200`

## Quartus Projects

Use the following Quartus projects inside `fpga-dual-system/`:

- FPGA1: `fpga-dual-system/fpga1_acquisition/quartus/de10_lite_fpga1_wrapper.qpf`
- FPGA2: `fpga-dual-system/fpga2_display/quartus/de10_lite_fpga2_wrapper.qpf`

Top-level entities:

- FPGA1: `de10_lite_fpga1_wrapper`
- FPGA2: `de10_lite_fpga2_wrapper`

Note:

- Quartus generated files such as `output_files/` are not guaranteed to be present in the repository.
- If the `.sof` programming files are missing, run a compilation first.

## How to Deploy FPGA1 with Quartus

1. Open Quartus Prime.
2. Open `fpga-dual-system/fpga1_acquisition/quartus/de10_lite_fpga1_wrapper.qpf`.
3. Check that the top-level entity is `de10_lite_fpga1_wrapper`.
4. Run `Processing -> Start Compilation`.
5. Open `Tools -> Programmer`.
6. Select your `USB-Blaster` in `Hardware Setup`.
7. Add:
   `fpga-dual-system/fpga1_acquisition/quartus/output_files/de10_lite_fpga1_wrapper.sof`
8. Check `Program/Configure`.
9. Click `Start`.

## How to Deploy FPGA2 with Quartus

1. Open Quartus Prime.
2. Open `fpga-dual-system/fpga2_display/quartus/de10_lite_fpga2_wrapper.qpf`.
3. Check that the top-level entity is `de10_lite_fpga2_wrapper`.
4. Run `Processing -> Start Compilation`.
5. Open `Tools -> Programmer`.
6. Select your `USB-Blaster` in `Hardware Setup`.
7. Add:
   `fpga-dual-system/fpga2_display/quartus/output_files/de10_lite_fpga2_wrapper.sof`
8. Check `Program/Configure`.
9. Click `Start`.

## How to Connect the Two Boards

Make the following connections between the boards:

- FPGA1 `uart_tx_o` on `PIN_V10` -> FPGA2 `uart_rx_i` on `PIN_V10`
- FPGA1 `burst_sync_o` on `PIN_W10` -> FPGA2 `burst_sync_i` on `PIN_W10`
- GND of FPGA1 -> GND of FPGA2

Board controls:

- `KEY0` on each board: local reset
- `KEY1` on FPGA1: manual start of the test

Important:

- FPGA2 does not need `KEY1` for the current design.
- The two boards must share ground.

## How to Run the Immunity Test

1. Program FPGA1.
2. Program FPGA2.
3. Connect the two boards with the wires listed above.
4. Power both boards.
5. Press `KEY1` on FPGA1 to start the transmission.
6. Expose the wired setup to the EM environment under test.
7. Observe FPGA2:
   - `LEDR1` shows UART reception activity
   - `LEDR[9:2]` blink if errors have been detected
   - `HEX2..HEX0` display the error count

## Expected Result

During a good baseline test:

- FPGA2 receives data correctly
- the error count stays at `000`

During EM exposure:

- if the link remains immune, the error count stays at `000`
- if the link is disturbed, the error count increases

## More Information

For more details about the internal design, behavior of the LEDs and displays, and the detailed workflow, see:

- `fpga-dual-system/README.md`
