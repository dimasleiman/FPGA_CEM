library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_uart_counter_link is
end entity tb_uart_counter_link;

architecture sim of tb_uart_counter_link is
    constant C_CLOCK_FREQ_HZ : positive := 20_000_000;
    constant C_BAUD_RATE     : positive := 2_000_000;
    constant C_CLOCK_PERIOD  : time := 50 ns;

    signal clk        : std_logic := '0';
    signal rst        : std_logic := '1';
    signal start_tx   : std_logic := '0';
    signal uart_wire  : std_logic := '1';
    signal fpga1_leds : std_logic_vector(9 downto 0);
    signal fpga2_leds : std_logic_vector(9 downto 0);
    signal fpga1_hex5_n : std_logic_vector(6 downto 0);
    signal fpga1_hex4_n : std_logic_vector(6 downto 0);
    signal fpga1_hex3_n : std_logic_vector(6 downto 0);
    signal fpga1_hex2_n : std_logic_vector(6 downto 0);
    signal fpga1_hex1_n : std_logic_vector(6 downto 0);
    signal fpga1_hex0_n : std_logic_vector(6 downto 0);
    signal fpga2_hex5_n : std_logic_vector(6 downto 0);
    signal fpga2_hex4_n : std_logic_vector(6 downto 0);
    signal fpga2_hex3_n : std_logic_vector(6 downto 0);
    signal fpga2_hex2_n : std_logic_vector(6 downto 0);
    signal fpga2_hex1_n : std_logic_vector(6 downto 0);
    signal fpga2_hex0_n : std_logic_vector(6 downto 0);
begin
    clk <= not clk after C_CLOCK_PERIOD / 2;

    u_fpga1 : entity work.fpga1_top
        generic map (
            G_CLOCK_FREQ_HZ => C_CLOCK_FREQ_HZ,
            G_BAUD_RATE     => C_BAUD_RATE
        )
        port map (
            clk       => clk,
            rst       => rst,
            start_i   => start_tx,
            ledr_o    => fpga1_leds,
            hex5_n_o  => fpga1_hex5_n,
            hex4_n_o  => fpga1_hex4_n,
            hex3_n_o  => fpga1_hex3_n,
            hex2_n_o  => fpga1_hex2_n,
            hex1_n_o  => fpga1_hex1_n,
            hex0_n_o  => fpga1_hex0_n,
            uart_tx_o => uart_wire
        );

    u_fpga2 : entity work.fpga2_top
        generic map (
            G_CLOCK_FREQ_HZ => C_CLOCK_FREQ_HZ,
            G_BAUD_RATE     => C_BAUD_RATE
        )
        port map (
            clk       => clk,
            rst       => rst,
            uart_rx_i => uart_wire,
            ledr_o    => fpga2_leds,
            hex5_n_o  => fpga2_hex5_n,
            hex4_n_o  => fpga2_hex4_n,
            hex3_n_o  => fpga2_hex3_n,
            hex2_n_o  => fpga2_hex2_n,
            hex1_n_o  => fpga2_hex1_n,
            hex0_n_o  => fpga2_hex0_n
        );

    stimulus : process
    begin
        rst <= '1';
        wait for 1 us;
        rst <= '0';

        wait for 500 ns;
        start_tx <= '1';
        wait for C_CLOCK_PERIOD;
        start_tx <= '0';

        wait for 2 ms;

        assert fpga2_leds(8) = '0'
            report "FPGA2 latched a UART counter mismatch."
            severity failure;

        assert fpga1_leds(8) = '0'
            report "FPGA1 did not return to IDLE after the counter burst."
            severity failure;

        assert fpga2_leds(7 downto 0) = x"FF"
            report "FPGA2 did not receive the full 0..255 UART counter burst."
            severity failure;

        wait;
    end process;
end architecture sim;
