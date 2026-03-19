# Interface Specification

Target board for later Quartus import:

- Board: Terasic DE10-Lite
- FPGA device: Intel/Altera MAX 10 `10M50DAF484C7G`
- Default onboard clock: `50 MHz`

Board-specific pin locations are intentionally not specified here. All top-level ports are placeholders to be mapped in Quartus.

## FPGA 1 Top Level

File: `fpga1_acquisition/src/top/fpga1_top.vhd`

### Generics

- `G_CLOCK_FREQ_HZ`: system clock frequency in hertz, default `50_000_000` for the DE10-Lite onboard clock
- `G_BAUD_RATE`: UART baud rate
- `G_SENSOR_UPDATE_DIVIDER`: number of clock cycles between fake sensor updates
- `G_SENSOR_STEP`: increment applied to the fake 12-bit sample each update

### Ports

- `clk`: system clock input, to be mapped in Quartus
- `rst`: active-high synchronous reset input, to be mapped in Quartus
- `uart_tx_o`: UART transmit output to FPGA 2, to be mapped in Quartus

## FPGA 2 Top Level

File: `fpga2_display/src/top/fpga2_top.vhd`

### Generics

- `G_CLOCK_FREQ_HZ`: system clock frequency in hertz, default `50_000_000` for the DE10-Lite onboard clock
- `G_BAUD_RATE`: UART baud rate

### Ports

- `clk`: system clock input, to be mapped in Quartus
- `rst`: active-high synchronous reset input, to be mapped in Quartus
- `uart_rx_i`: UART receive input from FPGA 1, to be mapped in Quartus
- `leds_o(3 downto 0)`: four LED status outputs, to be mapped in Quartus to any four of the DE10-Lite user LEDs

## Shared UART Link

- UART format: 8 data bits, no parity, 1 stop bit
- Idle level: logic `'1'`
- Frame length: 5 bytes
- Header byte: `x"AA"`
- Footer byte: `x"55"`

## LED Meanings

- `0001`: normal
- `0010`: warning
- `0100`: error
- `1000`: no valid frame yet / default state

## DE10-Lite Notes

- This starter design does not yet use the DE10-Lite switches, push-buttons, seven-segment displays, VGA, or Arduino header directly.
- No external ADC chip is assumed.
- A later FPGA 1 upgrade can replace `fake_sensor_gen.vhd` with a MAX 10 integrated ADC acquisition block while preserving the same frame format.
