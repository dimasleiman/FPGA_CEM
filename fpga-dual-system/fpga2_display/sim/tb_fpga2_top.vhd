library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.fpga2_pkg.all;

entity tb_fpga2_top is
end entity tb_fpga2_top;

architecture sim of tb_fpga2_top is
    constant C_CLOCK_PERIOD  : time     := 1 us;
    constant C_CLOCK_FREQ_HZ : positive := 1_000_000;
    constant C_BAUD_RATE     : positive := 10_000;
    constant C_BIT_PERIOD    : time     := C_CLOCK_PERIOD * (C_CLOCK_FREQ_HZ / C_BAUD_RATE);

    signal clk          : std_logic := '0';
    signal rst          : std_logic := '1';
    signal uart_rx_line : std_logic := '1';
    signal leds_o       : std_logic_vector(3 downto 0);
    signal tb_done      : std_logic := '0';

    procedure send_uart_byte (
        signal serial_line : out std_logic;
        constant data_byte : in  std_logic_vector(7 downto 0)
    ) is
    begin
        serial_line <= '0';
        wait for C_BIT_PERIOD;

        for i in 0 to 7 loop
            serial_line <= data_byte(i);
            wait for C_BIT_PERIOD;
        end loop;

        serial_line <= '1';
        wait for C_BIT_PERIOD;
    end procedure send_uart_byte;
begin
    clk <= not clk after C_CLOCK_PERIOD / 2;

    u_dut : entity work.fpga2_top
        generic map (
            G_CLOCK_FREQ_HZ => C_CLOCK_FREQ_HZ,
            G_BAUD_RATE     => C_BAUD_RATE
        )
        port map (
            clk       => clk,
            rst       => rst,
            uart_rx_i => uart_rx_line,
            leds_o    => leds_o
        );

    stimulus : process
    begin
        wait for 10 * C_CLOCK_PERIOD;
        wait until rising_edge(clk);
        rst <= '0';

        wait for 20 * C_CLOCK_PERIOD;
        assert leds_o = C_LED_NO_FRAME
            report "FPGA2 LEDs should start in the no-frame state."
            severity failure;

        send_uart_byte(uart_rx_line, x"AA");
        send_uart_byte(uart_rx_line, x"AA");
        send_uart_byte(uart_rx_line, x"08");
        send_uart_byte(uart_rx_line, x"01");
        send_uart_byte(uart_rx_line, x"55");

        wait for 20 * C_BIT_PERIOD;

        assert leds_o = C_LED_WARNING
            report "FPGA2 LEDs should show the warning pattern after a valid warning frame."
            severity failure;

        report "tb_fpga2_top completed successfully." severity note;
        tb_done <= '1';
        wait;
    end process;

    timeout_guard : process
    begin
        wait for 10 ms;
        assert tb_done = '1'
            report "Timeout waiting for FPGA2 LED update."
            severity failure;
        wait;
    end process;
end architecture sim;
