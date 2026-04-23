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
    signal start_button : std_logic := '1';
    signal burst_sync : std_logic := '0';
    signal burst_sync_prev : std_logic := '0';
    signal burst_sync_count : natural := 0;
    signal auto_flash_seen : std_logic := '0';
    signal rx_activity_seen : std_logic := '0';
    signal inject_error : std_logic := '0';
    signal uart_wire  : std_logic := '1';
    signal uart_to_fpga2 : std_logic := '1';
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
    uart_to_fpga2 <= not uart_wire when inject_error = '1' else uart_wire;

    u_fpga1 : entity work.de10_lite_fpga1_wrapper
        generic map (
            G_CLOCK_FREQ_HZ               => C_CLOCK_FREQ_HZ,
            G_BAUD_RATE                   => C_BAUD_RATE,
            G_RESET_ACTIVE_LEVEL          => '1',
            G_START_BUTTON_ACTIVE_LEVEL   => '0',
            G_SYNC_PULSE_CLKS             => 16,
            G_AUTO_RESTART_PULSE_CLKS     => 4,
            G_START_AFTER_SYNC_DELAY_CLKS => 20
        )
        port map (
            clock_50_i     => clk,
            reset_source_i => rst,
            start_button_i => start_button,
            ledr_o         => fpga1_leds,
            hex5_n_o       => fpga1_hex5_n,
            hex4_n_o       => fpga1_hex4_n,
            hex3_n_o       => fpga1_hex3_n,
            hex2_n_o       => fpga1_hex2_n,
            hex1_n_o       => fpga1_hex1_n,
            hex0_n_o       => fpga1_hex0_n,
            burst_sync_o   => burst_sync,
            uart_tx_o      => uart_wire
        );

    u_fpga2 : entity work.de10_lite_fpga2_wrapper
        generic map (
            G_CLOCK_FREQ_HZ             => C_CLOCK_FREQ_HZ,
            G_BAUD_RATE                 => C_BAUD_RATE,
            G_RESET_ACTIVE_LEVEL        => '1',
            G_ERROR_BLINK_TOGGLE_CLKS   => 16,
            G_RESET_FLASH_TOGGLE_CLKS   => 4,
            G_RESET_FLASH_DURATION_CLKS => 20,
            G_MANUAL_SYNC_MIN_CLKS      => 8
        )
        port map (
            clock_50_i     => clk,
            reset_source_i => rst,
            burst_sync_i   => burst_sync,
            uart_rx_i      => uart_to_fpga2,
            ledr_o         => fpga2_leds,
            hex5_n_o       => fpga2_hex5_n,
            hex4_n_o       => fpga2_hex4_n,
            hex3_n_o       => fpga2_hex3_n,
            hex2_n_o       => fpga2_hex2_n,
            hex1_n_o       => fpga2_hex1_n,
            hex0_n_o       => fpga2_hex0_n
        );

    sync_monitor : process (clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                burst_sync_prev  <= '0';
                burst_sync_count <= 0;
                auto_flash_seen  <= '0';
                rx_activity_seen <= '0';
            else
                burst_sync_prev <= burst_sync;

                if burst_sync = '1' and burst_sync_prev = '0' then
                    burst_sync_count <= burst_sync_count + 1;
                end if;

                if burst_sync_count >= 2 and fpga2_leds(0) = '1' then
                    auto_flash_seen <= '1';
                end if;

                if fpga2_leds(1) = '1' then
                    rx_activity_seen <= '1';
                end if;
            end if;
        end if;
    end process;

    stimulus : process
    begin
        rst <= '1';
        start_button <= '1';
        wait for 1 us;
        rst <= '0';

        wait for 500 ns;
        start_button <= '0';
        wait for 4 * C_CLOCK_PERIOD;
        start_button <= '1';

        wait for 4 ms;

        assert burst_sync_count >= 2
            report "FPGA1 did not automatically restart after the first counter burst."
            severity failure;

        assert fpga1_leds = (fpga1_leds'range => '0')
            report "FPGA1 LEDs should stay off after the counter burst."
            severity failure;

        assert fpga2_leds(9 downto 2) = (9 downto 2 => '0')
            report "FPGA2 error LEDs should be off after clean UART counter bursts."
            severity failure;

        assert rx_activity_seen = '1'
            report "FPGA2 LEDR1 should light when UART data is received."
            severity failure;

        assert auto_flash_seen = '0'
            report "FPGA2 reset flash should not blink during automatic restarts."
            severity failure;

        assert fpga2_hex2_n = "1000000"
            report "FPGA2 hundreds error digit should be 0 for a clean burst."
            severity failure;

        assert fpga2_hex1_n = "1000000"
            report "FPGA2 tens error digit should be 0 for a clean burst."
            severity failure;

        assert fpga2_hex0_n = "1000000"
            report "FPGA2 ones error digit should be 0 for a clean burst."
            severity failure;

        inject_error <= '1';
        wait for 20 us;
        inject_error <= '0';

        wait for 200 us;

        assert fpga2_hex2_n /= "1000000" or fpga2_hex1_n /= "1000000" or fpga2_hex0_n /= "1000000"
            report "FPGA2 did not count the injected UART error."
            severity failure;

        assert fpga2_leds(1) = '1'
            report "FPGA2 LEDR1 should still indicate UART reception after an injected error."
            severity failure;

        wait for 2 ms;

        assert fpga2_hex2_n /= "1000000" or fpga2_hex1_n /= "1000000" or fpga2_hex0_n /= "1000000"
            report "FPGA2 automatic restart cleared the error count."
            severity failure;

        wait;
    end process;
end architecture sim;
