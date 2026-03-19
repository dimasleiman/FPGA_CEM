library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.fpga2_pkg.all;

entity fpga2_top is
    generic (
        G_CLOCK_FREQ_HZ : positive := 50_000_000;
        G_BAUD_RATE     : positive := 115_200
    );
    port (
        clk       : in  std_logic;
        rst       : in  std_logic;
        uart_rx_i : in  std_logic;
        leds_o    : out std_logic_vector(3 downto 0)
    );
end entity fpga2_top;

architecture rtl of fpga2_top is
    signal rx_byte        : t_uart_byte := (others => '0');
    signal rx_data_valid  : std_logic := '0';
    signal measured_value : t_sample := (others => '0');
    signal warning_flag   : std_logic := '0';
    signal error_flag     : std_logic := '0';
    signal frame_valid    : std_logic := '0';
    signal led_pattern    : std_logic_vector(3 downto 0) := C_LED_NO_FRAME;
begin
    u_uart_rx : entity work.uart_rx
        generic map (
            G_CLOCK_FREQ_HZ => G_CLOCK_FREQ_HZ,
            G_BAUD_RATE     => G_BAUD_RATE
        )
        port map (
            clk        => clk,
            rst        => rst,
            rx         => uart_rx_i,
            data_out   => rx_byte,
            data_valid => rx_data_valid
        );

    u_frame_decoder : entity work.frame_decoder
        port map (
            clk            => clk,
            rst            => rst,
            data_in        => rx_byte,
            data_valid     => rx_data_valid,
            measured_value => measured_value,
            warning_flag   => warning_flag,
            error_flag     => error_flag,
            frame_valid    => frame_valid
        );

    u_status_mapper : entity work.status_mapper
        port map (
            frame_valid  => frame_valid,
            warning_flag => warning_flag,
            error_flag   => error_flag,
            led_pattern  => led_pattern
        );

    u_led_driver : entity work.led_driver
        port map (
            clk    => clk,
            rst    => rst,
            load   => frame_valid,
            led_in => led_pattern,
            leds   => leds_o
        );
end architecture rtl;
