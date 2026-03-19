library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.dual_fpga_system_pkg.all;
use work.fpga2_pkg.all;

entity tb_fpga1_fpga2_integration is
end entity tb_fpga1_fpga2_integration;

architecture sim of tb_fpga1_fpga2_integration is
    constant C_CLOCK_PERIOD          : time     := 1 us;
    constant C_CLOCK_FREQ_HZ         : positive := 1_000_000;
    constant C_BAUD_RATE             : positive := 10_000;
    constant C_SENSOR_UPDATE_DIVIDER : positive := 12_000;
    constant C_SENSOR_STEP           : positive := 900;
    constant C_FRAME_TIMEOUT_CLKS    : positive := 40_000;

    signal clk         : std_logic := '0';
    signal rst         : std_logic := '1';
    signal uart_link   : std_logic := '1';
    signal leds_o      : std_logic_vector(3 downto 0);
    signal vga_hsync_o : std_logic;
    signal vga_vsync_o : std_logic;
    signal vga_r_o     : std_logic_vector(3 downto 0);
    signal vga_g_o     : std_logic_vector(3 downto 0);
    signal vga_b_o     : std_logic_vector(3 downto 0);
    signal tb_done     : std_logic := '0';

    procedure wait_for_led_pattern (
        signal clk_i    : in std_logic;
        signal leds_i   : in std_logic_vector(3 downto 0);
        constant value  : in std_logic_vector(3 downto 0);
        constant cycles : in positive;
        constant msg    : in string
    ) is
    begin
        for i in 1 to cycles loop
            wait until rising_edge(clk_i);

            if leds_i = value then
                return;
            end if;
        end loop;

        assert false
            report msg
            severity failure;
    end procedure wait_for_led_pattern;
begin
    clk <= not clk after C_CLOCK_PERIOD / 2;

    u_fpga1 : entity work.fpga1_top
        generic map (
            G_CLOCK_FREQ_HZ         => C_CLOCK_FREQ_HZ,
            G_BAUD_RATE             => C_BAUD_RATE,
            G_SENSOR_UPDATE_DIVIDER => C_SENSOR_UPDATE_DIVIDER,
            G_SENSOR_STEP           => C_SENSOR_STEP
        )
        port map (
            clk       => clk,
            rst       => rst,
            uart_tx_o => uart_link
        );

    u_fpga2 : entity work.fpga2_top
        generic map (
            G_CLOCK_FREQ_HZ       => C_CLOCK_FREQ_HZ,
            G_BAUD_RATE           => C_BAUD_RATE,
            G_FRAME_TIMEOUT_CLKS  => C_FRAME_TIMEOUT_CLKS,
            G_FAST_SIMULATION_VGA => true
        )
        port map (
            clk         => clk,
            rst         => rst,
            uart_rx_i   => uart_link,
            leds_o      => leds_o,
            vga_hsync_o => vga_hsync_o,
            vga_vsync_o => vga_vsync_o,
            vga_r_o     => vga_r_o,
            vga_g_o     => vga_g_o,
            vga_b_o     => vga_b_o
        );

    stimulus : process
    begin
        wait for 10 * C_CLOCK_PERIOD;
        wait until rising_edge(clk);
        rst <= '0';

        -- Before the first complete frame arrives, FPGA2 should stay in the
        -- reset/default no-frame state.
        wait for 100 * C_CLOCK_PERIOD;
        assert leds_o = C_LED_NO_FRAME
            report "FPGA2 LEDs should remain in the no-frame state after reset and before the first valid frame."
            severity failure;

        wait_for_led_pattern(
            clk_i  => clk,
            leds_i => leds_o,
            value  => C_LED_NORMAL,
            cycles => 30_000,
            msg    => "FPGA2 LEDs did not update to the normal pattern after the first valid frame."
        );

        wait_for_led_pattern(
            clk_i  => clk,
            leds_i => leds_o,
            value  => C_LED_WARNING,
            cycles => 30_000,
            msg    => "FPGA2 LEDs did not update to the warning pattern on a later valid frame."
        );

        wait_for_led_pattern(
            clk_i  => clk,
            leds_i => leds_o,
            value  => C_LED_ERROR,
            cycles => 30_000,
            msg    => "FPGA2 LEDs did not update to the error pattern on a later valid frame."
        );

        report "tb_fpga1_fpga2_integration completed successfully." severity note;
        tb_done <= '1';
        wait;
    end process;

    timeout_guard : process
    begin
        wait for 120 ms;
        assert tb_done = '1'
            report "Timeout waiting for end-to-end FPGA1/FPGA2 integration behavior."
            severity failure;
        wait;
    end process;
end architecture sim;
