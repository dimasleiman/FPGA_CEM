library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.dual_fpga_system_pkg.all;

entity tb_fpga1_fpga2_integration is
end entity tb_fpga1_fpga2_integration;

architecture sim of tb_fpga1_fpga2_integration is
    constant C_CLOCK_PERIOD      : time     := 1 us;
    constant C_CLOCK_FREQ_HZ     : positive := 1_000_000;
    constant C_BAUD_RATE         : positive := 100_000;
    constant C_FRAME_TIMEOUT_CLKS : positive := 40_000;
    constant C_SAMPLE_GAP_CLKS   : positive := 3_000;
    constant C_STABLE_SAMPLE_CODE : natural := 1_883;
    constant C_NOISY_SAMPLE_HIGH_CODE : natural := 1_945;

    constant C_LEDS_OFF          : std_logic_vector(3 downto 0) := (others => '0');
    constant C_SEG_BLANK_N       : std_logic_vector(6 downto 0) := "1111111";
    constant C_SEG_G_N           : std_logic_vector(6 downto 0) := "0000010";
    constant C_SEG_E_N           : std_logic_vector(6 downto 0) := "0000110";
    constant C_SEG_R_N           : std_logic_vector(6 downto 0) := "0101111";
    constant C_SEG_N_N           : std_logic_vector(6 downto 0) := "0101011";
    constant C_SEG_O_N           : std_logic_vector(6 downto 0) := "1000000";
    constant C_SEG_D_N           : std_logic_vector(6 downto 0) := "0100001";
    subtype t_seg_word is std_logic_vector(41 downto 0);
    constant C_DISPLAY_GOOD      : t_seg_word := C_SEG_BLANK_N & C_SEG_BLANK_N & C_SEG_G_N & C_SEG_O_N & C_SEG_O_N & C_SEG_D_N;
    constant C_DISPLAY_NONE      : t_seg_word := C_SEG_BLANK_N & C_SEG_BLANK_N & C_SEG_N_N & C_SEG_O_N & C_SEG_N_N & C_SEG_E_N;

    signal clk               : std_logic := '0';
    signal rst               : std_logic := '1';
    signal sample_value      : t_sample := (others => '0');
    signal sample_valid      : std_logic := '0';
    signal uart_link         : std_logic := '1';
    signal local_error_led_o : std_logic;
    signal leds_o            : std_logic_vector(3 downto 0);
    signal hex5_n_o          : std_logic_vector(6 downto 0);
    signal hex4_n_o          : std_logic_vector(6 downto 0);
    signal hex3_n_o          : std_logic_vector(6 downto 0);
    signal hex2_n_o          : std_logic_vector(6 downto 0);
    signal hex1_n_o          : std_logic_vector(6 downto 0);
    signal hex0_n_o          : std_logic_vector(6 downto 0);
    signal display_word      : t_seg_word;
    signal vga_hsync_o       : std_logic;
    signal vga_vsync_o       : std_logic;
    signal vga_r_o           : std_logic_vector(3 downto 0);
    signal vga_g_o           : std_logic_vector(3 downto 0);
    signal vga_b_o           : std_logic_vector(3 downto 0);
    signal tb_done           : std_logic := '0';

    procedure wait_clock_cycles (
        signal clk_i    : in std_logic;
        constant cycles : in positive
    ) is
    begin
        for cycle_index in 1 to cycles loop
            wait until rising_edge(clk_i);
        end loop;
    end procedure wait_clock_cycles;

    procedure drive_sample (
        signal clk_i          : in std_logic;
        signal sample_value_i : out t_sample;
        signal sample_valid_i : out std_logic;
        constant sample_code  : in natural
    ) is
    begin
        sample_value_i <= std_logic_vector(to_unsigned(sample_code, C_SAMPLE_WIDTH));
        sample_valid_i <= '1';
        wait until rising_edge(clk_i);
        sample_valid_i <= '0';
        wait_clock_cycles(clk_i, C_SAMPLE_GAP_CLKS);
    end procedure drive_sample;

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
    clk <= not clk after C_CLOCK_PERIOD / 2;
    display_word <= hex5_n_o & hex4_n_o & hex3_n_o & hex2_n_o & hex1_n_o & hex0_n_o;

    u_fpga1 : entity work.fpga1_top
        generic map (
            G_CLOCK_FREQ_HZ => C_CLOCK_FREQ_HZ,
            G_BAUD_RATE     => C_BAUD_RATE
        )
        port map (
            clk               => clk,
            rst               => rst,
            sample_value_i    => sample_value,
            sample_valid_i    => sample_valid,
            local_error_led_o => local_error_led_o,
            hex5_n_o          => open,
            hex4_n_o          => open,
            hex3_n_o          => open,
            hex2_n_o          => open,
            hex1_n_o          => open,
            hex0_n_o          => open,
            uart_tx_o         => uart_link
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
            hex5_n_o    => hex5_n_o,
            hex4_n_o    => hex4_n_o,
            hex3_n_o    => hex3_n_o,
            hex2_n_o    => hex2_n_o,
            hex1_n_o    => hex1_n_o,
            hex0_n_o    => hex0_n_o,
            vga_hsync_o => vga_hsync_o,
            vga_vsync_o => vga_vsync_o,
            vga_r_o     => vga_r_o,
            vga_g_o     => vga_g_o,
            vga_b_o     => vga_b_o
        );

    stimulus : process
    begin
        wait_clock_cycles(clk, 10);
        rst <= '0';

        wait_clock_cycles(clk, 100);
        assert leds_o = C_LEDS_OFF
            report "FPGA2 LEDs should remain off before the first valid UART frame arrives."
            severity failure;
        assert local_error_led_o = '0'
            report "FPGA1 local LED should remain off before any ADC sample is processed."
            severity failure;
        assert display_word = C_DISPLAY_NONE
            report "FPGA2 should spell NONE before the first clean frame is received."
            severity failure;

        drive_sample(clk, sample_value, sample_valid, C_STABLE_SAMPLE_CODE);

        wait_for_display_value(
            clk_i    => clk,
            display_i => display_word,
            value    => C_DISPLAY_GOOD,
            cycles   => 10_000,
            msg      => "FPGA2 did not update the seven-segment display to GOOD after the first valid ADC frame."
        );
        assert leds_o = C_LEDS_OFF
            report "FPGA2 LEDs should stay off after the first valid frame."
            severity failure;

        for sample_index in 1 to 8 loop
            if (sample_index mod 2) = 0 then
                drive_sample(clk, sample_value, sample_valid, C_NOISY_SAMPLE_HIGH_CODE);
            else
                drive_sample(clk, sample_value, sample_valid, C_STABLE_SAMPLE_CODE);
            end if;
        end loop;

        wait_clock_cycles(clk, 20);
        assert local_error_led_o = '1'
            report "FPGA1 should raise the local warning LED when the sliding-window spread indicates EMI-like noise."
            severity failure;

        wait_for_display_value(
            clk_i     => clk,
            display_i => display_word,
            value     => C_DISPLAY_GOOD,
            cycles    => 5_000,
            msg       => "FPGA2 did not settle back to GOOD after receiving the EMI-warning frames."
        );
        assert leds_o = C_LEDS_OFF
            report "FPGA2 communication LEDs should stay off while the UART link remains healthy."
            severity failure;

        report "tb_fpga1_fpga2_integration completed successfully." severity note;
        tb_done <= '1';
        wait;
    end process;

    timeout_guard : process
    begin
        wait for 80 ms;
        assert tb_done = '1'
            report "Timeout waiting for FPGA1/FPGA2 integration behavior."
            severity failure;
        wait;
    end process;
end architecture sim;
