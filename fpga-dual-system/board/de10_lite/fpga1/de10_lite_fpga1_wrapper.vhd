library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity de10_lite_fpga1_wrapper is
    generic (
        G_CLOCK_FREQ_HZ         : positive  := 50_000_000;
        G_BAUD_RATE             : positive  := 115_200;
        G_SENSOR_UPDATE_DIVIDER : positive  := 5_000_000;
        G_SENSOR_STEP           : positive  := 17;
        G_SOURCE_IS_ADC         : std_logic := '0';
        G_RESET_ACTIVE_LEVEL    : std_logic := '0'
    );
    port (
        -- To be mapped in Quartus to the DE10-Lite 50 MHz clock source.
        clock_50_i     : in  std_logic;
        -- To be mapped in Quartus to a chosen DE10-Lite button or switch.
        reset_source_i : in  std_logic;
        -- To be mapped in Quartus to a DE10-Lite user LED for local error indication.
        local_error_led_o : out std_logic;
        -- To be mapped in Quartus to the chosen board-to-board UART output pin.
        uart_tx_o      : out std_logic
    );
end entity de10_lite_fpga1_wrapper;

architecture rtl of de10_lite_fpga1_wrapper is
    signal core_rst : std_logic := '1';
begin
    u_reset_sync : entity work.reset_sync
        generic map (
            G_STAGES             => 2,
            G_INPUT_ACTIVE_LEVEL => G_RESET_ACTIVE_LEVEL
        )
        port map (
            clk       => clock_50_i,
            reset_in  => reset_source_i,
            reset_out => core_rst
        );

    u_core : entity work.fpga1_top
        generic map (
            G_CLOCK_FREQ_HZ         => G_CLOCK_FREQ_HZ,
            G_BAUD_RATE             => G_BAUD_RATE,
            G_SENSOR_UPDATE_DIVIDER => G_SENSOR_UPDATE_DIVIDER,
            G_SENSOR_STEP           => G_SENSOR_STEP,
            G_SOURCE_IS_ADC         => G_SOURCE_IS_ADC
        )
        port map (
            clk               => clock_50_i,
            rst               => core_rst,
            local_error_led_o => local_error_led_o,
            uart_tx_o         => uart_tx_o
        );
end architecture rtl;
