library ieee;
use ieee.std_logic_1164.all;

library work;
use work.dual_fpga_system_pkg.all;
use work.fpga1_pkg.all;

entity tb_de10_lite_wrappers is
end entity tb_de10_lite_wrappers;

architecture sim of tb_de10_lite_wrappers is
    constant C_CLOCK_PERIOD       : time     := 1 us;
    constant C_CLOCK_FREQ_HZ      : positive := 1_000_000;
    constant C_BAUD_RATE          : positive := 100_000;
    constant C_FRAME_TIMEOUT_CLKS : positive := 40_000;
    subtype t_seg_word is std_logic_vector(41 downto 0);

    constant C_SEG_BLANK_N        : std_logic_vector(6 downto 0) := "1111111";
    constant C_SEG_0_N            : std_logic_vector(6 downto 0) := "1000000";
    constant C_SEG_1_N            : std_logic_vector(6 downto 0) := "1111001";
    constant C_SEG_2_N            : std_logic_vector(6 downto 0) := "0100100";
    constant C_SEG_5_N            : std_logic_vector(6 downto 0) := "0010010";
    constant C_SEG_G_N            : std_logic_vector(6 downto 0) := "0000010";
    constant C_SEG_E_N            : std_logic_vector(6 downto 0) := "0000110";
    constant C_SEG_N_N            : std_logic_vector(6 downto 0) := "0101011";
    constant C_SEG_O_N            : std_logic_vector(6 downto 0) := "1000000";
    constant C_SEG_D_N            : std_logic_vector(6 downto 0) := "0100001";
    constant C_DISPLAY_GOOD       : t_seg_word := C_SEG_BLANK_N & C_SEG_BLANK_N & C_SEG_G_N & C_SEG_O_N & C_SEG_O_N & C_SEG_D_N;
    constant C_DISPLAY_NONE       : t_seg_word := C_SEG_BLANK_N & C_SEG_BLANK_N & C_SEG_N_N & C_SEG_O_N & C_SEG_N_N & C_SEG_E_N;
    constant C_DISPLAY_0000       : t_seg_word := C_SEG_BLANK_N & C_SEG_BLANK_N & C_SEG_0_N & C_SEG_0_N & C_SEG_0_N & C_SEG_0_N;
    constant C_DISPLAY_0020       : t_seg_word := C_SEG_BLANK_N & C_SEG_BLANK_N & C_SEG_0_N & C_SEG_0_N & C_SEG_2_N & C_SEG_0_N;
    constant C_FPGA1_FORCED_LED_OFF : std_logic_vector(9 downto 1) := (others => '0');
    constant C_FPGA2_LEDR_OFF     : std_logic_vector(9 downto 0) := (others => '0');

    signal clock_50_i             : std_logic := '0';
    signal fpga1_reset_src_i      : std_logic := '0';
    signal fpga2_reset_src_i      : std_logic := '0';
    signal uart_link              : std_logic := '1';
    signal local_error_led_o      : std_logic;
    signal fpga1_forced_leds_o    : std_logic_vector(9 downto 1) := (others => '0');
    signal fpga1_hex5_n_o         : std_logic_vector(6 downto 0);
    signal fpga1_hex4_n_o         : std_logic_vector(6 downto 0);
    signal fpga1_hex3_n_o         : std_logic_vector(6 downto 0);
    signal fpga1_hex2_n_o         : std_logic_vector(6 downto 0);
    signal fpga1_hex1_n_o         : std_logic_vector(6 downto 0);
    signal fpga1_hex0_n_o         : std_logic_vector(6 downto 0);
    signal fpga2_ledr_o           : std_logic_vector(9 downto 0);
    signal hex5_n_o               : std_logic_vector(6 downto 0);
    signal hex4_n_o               : std_logic_vector(6 downto 0);
    signal hex3_n_o               : std_logic_vector(6 downto 0);
    signal hex2_n_o               : std_logic_vector(6 downto 0);
    signal hex1_n_o               : std_logic_vector(6 downto 0);
    signal hex0_n_o               : std_logic_vector(6 downto 0);
    signal fpga1_display_word     : t_seg_word;
    signal fpga2_display_word     : t_seg_word;
    signal vga_hsync_o            : std_logic;
    signal vga_vsync_o            : std_logic;
    signal vga_r_o                : std_logic_vector(3 downto 0);
    signal vga_g_o                : std_logic_vector(3 downto 0);
    signal vga_b_o                : std_logic_vector(3 downto 0);
    signal tb_done                : std_logic := '0';

    procedure wait_for_display_value (
        signal clk_i      : in std_logic;
        signal display_i  : in t_seg_word;
        constant value    : in t_seg_word;
        constant cycles   : in positive;
        constant msg      : in string
    ) is
    begin
        for cycle_index in 1 to cycles loop
            wait until rising_edge(clk_i);

            if display_i = value then
                return;
            end if;
        end loop;

        assert false
            report msg
            severity failure;
    end procedure wait_for_display_value;
begin
    clock_50_i <= not clock_50_i after C_CLOCK_PERIOD / 2;
    fpga1_display_word <= fpga1_hex5_n_o & fpga1_hex4_n_o & fpga1_hex3_n_o & fpga1_hex2_n_o & fpga1_hex1_n_o & fpga1_hex0_n_o;
    fpga2_display_word <= hex5_n_o & hex4_n_o & hex3_n_o & hex2_n_o & hex1_n_o & hex0_n_o;

    u_fpga1_wrapper : entity work.de10_lite_fpga1_wrapper
        generic map (
            G_CLOCK_FREQ_HZ         => C_CLOCK_FREQ_HZ,
            G_BAUD_RATE             => C_BAUD_RATE,
            G_USE_TEST_SAMPLE_SOURCE => true,
            G_USE_FAKE_SENSOR_GENERATOR => false,
            G_TEST_SAMPLE_PERIOD_CLKS => C_DEFAULT_SIM_SAMPLE_PERIOD_CLKS,
            G_TEST_SAMPLE_CODE      => C_DEFAULT_SIM_SAMPLE_CODE,
            G_RESET_ACTIVE_LEVEL    => '0'
        )
        port map (
            clock_50_i       => clock_50_i,
            reset_source_i   => fpga1_reset_src_i,
            local_error_led_o => local_error_led_o,
            hex5_n_o         => fpga1_hex5_n_o,
            hex4_n_o         => fpga1_hex4_n_o,
            hex3_n_o         => fpga1_hex3_n_o,
            hex2_n_o         => fpga1_hex2_n_o,
            hex1_n_o         => fpga1_hex1_n_o,
            hex0_n_o         => fpga1_hex0_n_o,
            ledr1_o          => fpga1_forced_leds_o(1),
            ledr2_o          => fpga1_forced_leds_o(2),
            ledr3_o          => fpga1_forced_leds_o(3),
            ledr4_o          => fpga1_forced_leds_o(4),
            ledr5_o          => fpga1_forced_leds_o(5),
            ledr6_o          => fpga1_forced_leds_o(6),
            ledr7_o          => fpga1_forced_leds_o(7),
            ledr8_o          => fpga1_forced_leds_o(8),
            ledr9_o          => fpga1_forced_leds_o(9),
            uart_tx_o        => uart_link
        );

    u_fpga2_wrapper : entity work.de10_lite_fpga2_wrapper
        generic map (
            G_CLOCK_FREQ_HZ       => C_CLOCK_FREQ_HZ,
            G_BAUD_RATE           => C_BAUD_RATE,
            G_FRAME_TIMEOUT_CLKS  => C_FRAME_TIMEOUT_CLKS,
            G_FAST_SIMULATION_VGA => true,
            G_USE_INTERNAL_UART_TEST_SOURCE => false,
            G_RESET_ACTIVE_LEVEL  => '0'
        )
        port map (
            clock_50_i     => clock_50_i,
            reset_source_i => fpga2_reset_src_i,
            uart_rx_i      => uart_link,
            ledr0_o        => fpga2_ledr_o(0),
            ledr1_o        => fpga2_ledr_o(1),
            ledr2_o        => fpga2_ledr_o(2),
            ledr3_o        => fpga2_ledr_o(3),
            ledr4_o        => fpga2_ledr_o(4),
            ledr5_o        => fpga2_ledr_o(5),
            ledr6_o        => fpga2_ledr_o(6),
            ledr7_o        => fpga2_ledr_o(7),
            ledr8_o        => fpga2_ledr_o(8),
            ledr9_o        => fpga2_ledr_o(9),
            hex5_n_o       => hex5_n_o,
            hex4_n_o       => hex4_n_o,
            hex3_n_o       => hex3_n_o,
            hex2_n_o       => hex2_n_o,
            hex1_n_o       => hex1_n_o,
            hex0_n_o       => hex0_n_o,
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

        wait for 100 * C_CLOCK_PERIOD;
        assert fpga2_ledr_o = C_FPGA2_LEDR_OFF
            report "Wrapper bring-up should keep all FPGA2 LEDs off before the first valid frame."
            severity failure;
        assert local_error_led_o = '0'
            report "Wrapper bring-up should keep the FPGA1 local LED off before the first ADC sample."
            severity failure;
        assert fpga1_forced_leds_o = C_FPGA1_FORCED_LED_OFF
            report "FPGA1 LEDR1 through LEDR9 should remain forced low."
            severity failure;
        assert fpga1_display_word = C_DISPLAY_0000
            report "FPGA1 should show 0000 before the first test ADC sample is emitted."
            severity failure;
        assert fpga2_display_word = C_DISPLAY_NONE
            report "FPGA2 should spell NONE before the first clean wrapper-level frame arrives."
            severity failure;

        wait_for_display_value(
            clk_i     => clock_50_i,
            display_i => fpga1_display_word,
            value     => C_DISPLAY_0020,
            cycles    => 20_000,
            msg       => "FPGA1 wrapper did not update its seven-segment display after the simulated ADC sample."
        );

        wait_for_display_value(
            clk_i     => clock_50_i,
            display_i => fpga2_display_word,
            value     => C_DISPLAY_GOOD,
            cycles    => 20_000,
            msg       => "DE10-Lite wrapper flow did not produce GOOD after the first valid ADC frame."
        );

        assert fpga2_ledr_o = C_FPGA2_LEDR_OFF
            report "FPGA2 LEDs should remain off while clean frames continue."
            severity failure;
        assert local_error_led_o = '0'
            report "FPGA1 local LED should stay off for a stable simulated ADC source."
            severity failure;

        report "tb_de10_lite_wrappers completed successfully." severity note;
        tb_done <= '1';
        wait;
    end process;

    timeout_guard : process
    begin
        wait for 80 ms;
        assert tb_done = '1'
            report "Timeout waiting for DE10-Lite wrapper behavior."
            severity failure;
        wait;
    end process;
end architecture sim;
