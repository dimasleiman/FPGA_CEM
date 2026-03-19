# DE10-Lite Target Notes

This project is intended for the Terasic DE10-Lite board with device `10M50DAF484C7G`.

Confirmed board resources for this project:

- onboard `50 MHz` clock
- `10` user LEDs
- `10` slide switches
- `2` push-buttons
- `6` seven-segment displays
- VGA output
- Arduino Uno R3 header
- MAX 10 integrated ADC path available through the Arduino analog header

Current design usage:

- FPGA 1 currently uses `clk`, `rst`, and `uart_tx_o`
- FPGA 2 currently uses `clk`, `rst`, `uart_rx_i`, and `leds_o(3 downto 0)`
- `leds_o(3 downto 0)` is intentionally narrower than the full board LED count; map it to any four user LEDs in Quartus

Constraints for this repository:

- no pin assignments are stored yet
- no board signal names are assumed
- Quartus pin mapping is deferred to project setup
- no external ADC chip is assumed
- board-wrapper ports are placeholders to be mapped in Quartus

Bring-up support now included:

- a DE10-Lite wrapper per FPGA
- a reset synchronization helper
- a placeholder QSF template per FPGA project

Planned direction:

- keep the current fake-sensor path for starter bring-up
- later replace `fpga1_acquisition/src/processing/fake_sensor_gen.vhd` with a MAX 10 integrated ADC interface
- preserve the existing UART frame format so FPGA 2 can stay stable while FPGA 1 evolves
