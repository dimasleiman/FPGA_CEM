library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.dual_fpga_system_pkg.all;
use work.fpga2_pkg.all;

entity tb_de10_lite_wrappers is
end entity tb_de10_lite_wrappers;

architecture sim of tb_de10_lite_wrappers is
    constant C_CLOCK_PERIOD          : time     := 1 us;
    constant C_CLOCK_FREQ_HZ         : positive := 1_000_000;
    constant C_BAUD_RATE             : positive := 10_000;
    constant C_SENSOR_UPDATE_DIVIDER : positive := 12_000;
    constant C_SENSOR_STEP           : positive := 900;
    constant C_FRAME_TIMEOUT_CLKS    : positive := 40_000;

    signal clock_50_i        : std_logic := '0';
    signal fpga1_reset_src_i : std_logic := '0';
    signal fpga2_reset_src_i : std_logic := '0';
    signal uart_link         : std_logic := '1';
    signal leds_o            : std_logic_vector(3 downto 0);
    signal vga_hsync_o       : std_logic;
    signal vga_vsync_o       : std_logic;
    signal vga_r_o           : std_logic_vector(3 downto 0);
    signal vga_g_o           : std_logic_vector(3 downto 0);
    signal vga_b_o           : std_logic_vector(3 downto 0);
    signal tb_done           : std_logic := '0';

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
    clock_50_i <= not clock_50_i after C_CLOCK_PERIOD / 2;

    u_fpga1_wrapper : entity work.de10_lite_fpga1_wrapper
        generic map (
            G_CLOCK_FREQ_HZ         => C_CLOCK_FREQ_HZ,
            G_BAUD_RATE             => C_BAUD_RATE,
            G_SENSOR_UPDATE_DIVIDER => C_SENSOR_UPDATE_DIVIDER,
            G_SENSOR_STEP           => C_SENSOR_STEP,
            G_RESET_ACTIVE_LEVEL    => '0'
        )
        port map (
            clock_50_i     => clock_50_i,
            reset_source_i => fpga1_reset_src_i,
            uart_tx_o      => uart_link
        );

    u_fpga2_wrapper : entity work.de10_lite_fpga2_wrapper
        generic map (
            G_CLOCK_FREQ_HZ       => C_CLOCK_FREQ_HZ,
            G_BAUD_RATE           => C_BAUD_RATE,
            G_FRAME_TIMEOUT_CLKS  => C_FRAME_TIMEOUT_CLKS,
            G_FAST_SIMULATION_VGA => true,
            G_RESET_ACTIVE_LEVEL  => '0'
        )
        port map (
            clock_50_i     => clock_50_i,
            reset_source_i => fpga2_reset_src_i,
            uart_rx_i      => uart_link,
            leds_o         => leds_o,
            vga_hsync_o    => vga_hsync_o,
            vga_vsync_o    => vga_vsync_o,
            vga_r_o        => vga_r_o,
            vga_g_o        => vga_g_o,
            vga_b_o        => vga_b_o
        );

    stimulus : process
    begin
        wait for 10 * C_CLOCK_PERIOD;
        wait until rising_edge(clock_50_i);
        fpga1_reset_src_i <= '1';
        fpga2_reset_src_i <= '1';

        -- The board-facing reset source is active-low. After release, the
        -- wrappers still hold the cores in synchronized reset briefly.
        wait for 100 * C_CLOCK_PERIOD;
        assert leds_o = C_LED_NO_FRAME
            report "Wrapper-level bring-up should keep FPGA2 LEDs in the no-frame state before the first valid frame."
            severity failure;

        wait_for_led_pattern(
            clk_i  => clock_50_i,
            leds_i => leds_o,
            value  => C_LED_NORMAL,
            cycles => 30_000,
            msg    => "DE10-Lite wrapper flow did not produce the normal LED pattern after reset release."
        );

        wait_for_led_pattern(
            clk_i  => clock_50_i,
            leds_i => leds_o,
            value  => C_LED_WARNING,
            cycles => 30_000,
            msg    => "DE10-Lite wrapper flow did not produce the warning LED pattern on a later frame."
        );

        wait_for_led_pattern(
            clk_i  => clock_50_i,
            leds_i => leds_o,
            value  => C_LED_ERROR,
            cycles => 30_000,
            msg    => "DE10-Lite wrapper flow did not produce the error LED pattern on a later frame."
        );

        wait until rising_edge(clock_50_i);
        fpga1_reset_src_i <= '0';
        fpga2_reset_src_i <= '0';
        wait for 4 * C_CLOCK_PERIOD;
        wait until rising_edge(clock_50_i);
        fpga1_reset_src_i <= '1';
        fpga2_reset_src_i <= '1';

        wait for 100 * C_CLOCK_PERIOD;
        assert leds_o = C_LED_NO_FRAME
            report "Reasserting the board-facing reset source should restore the FPGA2 no-frame LED state."
            severity failure;

        wait_for_led_pattern(
            clk_i  => clock_50_i,
            leds_i => leds_o,
            value  => C_LED_NORMAL,
            cycles => 30_000,
            msg    => "DE10-Lite wrapper flow did not recover to the normal LED pattern after a second reset release."
        );

        report "tb_de10_lite_wrappers completed successfully." severity note;
        tb_done <= '1';
        wait;
    end process;

    timeout_guard : process
    begin
        wait for 180 ms;
        assert tb_done = '1'
            report "Timeout waiting for DE10-Lite wrapper behavior."
            severity failure;
        wait;
    end process;
end architecture sim;
