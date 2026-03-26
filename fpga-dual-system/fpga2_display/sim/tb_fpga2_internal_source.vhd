library ieee;
use ieee.std_logic_1164.all;

library work;
use work.dual_fpga_system_pkg.all;

entity tb_fpga2_internal_source is
end entity tb_fpga2_internal_source;

architecture sim of tb_fpga2_internal_source is
    constant C_CLOCK_PERIOD       : time     := 1 us;
    constant C_CLOCK_FREQ_HZ      : positive := 1_000_000;
    constant C_BAUD_RATE          : positive := 10_000;
    constant C_FRAME_TIMEOUT_CLKS : positive := 40_000;
    constant C_FRAME_GAP_CLKS     : positive := 4_000;
    subtype t_seg_word is std_logic_vector(41 downto 0);
    constant C_LEDS_OFF           : std_logic_vector(3 downto 0) := (others => '0');
    constant C_SEG_BLANK_N        : std_logic_vector(6 downto 0) := "1111111";
    constant C_SEG_G_N            : std_logic_vector(6 downto 0) := "0000010";
    constant C_SEG_E_N            : std_logic_vector(6 downto 0) := "0000110";
    constant C_SEG_R_N            : std_logic_vector(6 downto 0) := "0101111";
    constant C_SEG_N_N            : std_logic_vector(6 downto 0) := "0101011";
    constant C_SEG_O_N            : std_logic_vector(6 downto 0) := "1000000";
    constant C_SEG_D_N            : std_logic_vector(6 downto 0) := "0100001";
    constant C_DISPLAY_GOOD       : t_seg_word := C_SEG_BLANK_N & C_SEG_BLANK_N & C_SEG_G_N & C_SEG_O_N & C_SEG_O_N & C_SEG_D_N;
    constant C_DISPLAY_NONE       : t_seg_word := C_SEG_BLANK_N & C_SEG_BLANK_N & C_SEG_N_N & C_SEG_O_N & C_SEG_N_N & C_SEG_E_N;
    constant C_DISPLAY_ERROR      : t_seg_word := C_SEG_BLANK_N & C_SEG_E_N & C_SEG_R_N & C_SEG_R_N & C_SEG_O_N & C_SEG_R_N;

    signal clk         : std_logic := '0';
    signal rst         : std_logic := '1';
    signal leds_o      : std_logic_vector(3 downto 0);
    signal hex5_n_o    : std_logic_vector(6 downto 0);
    signal hex4_n_o    : std_logic_vector(6 downto 0);
    signal hex3_n_o    : std_logic_vector(6 downto 0);
    signal hex2_n_o    : std_logic_vector(6 downto 0);
    signal hex1_n_o    : std_logic_vector(6 downto 0);
    signal hex0_n_o    : std_logic_vector(6 downto 0);
    signal vga_hsync_o : std_logic;
    signal vga_vsync_o : std_logic;
    signal vga_r_o     : std_logic_vector(3 downto 0);
    signal vga_g_o     : std_logic_vector(3 downto 0);
    signal vga_b_o     : std_logic_vector(3 downto 0);
    signal display_word : t_seg_word;
    signal tb_done     : std_logic := '0';

    procedure wait_for_display_value (
        signal clk_i     : in std_logic;
        signal display_i : in t_seg_word;
        constant value   : in t_seg_word;
        constant cycles  : in positive;
        constant msg     : in string
    ) is
    begin
        for i in 1 to cycles loop
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

    u_dut : entity work.fpga2_top
        generic map (
            G_CLOCK_FREQ_HZ       => C_CLOCK_FREQ_HZ,
            G_BAUD_RATE           => C_BAUD_RATE,
            G_FRAME_TIMEOUT_CLKS  => C_FRAME_TIMEOUT_CLKS,
            G_FAST_SIMULATION_VGA => true,
            G_USE_INTERNAL_UART_TEST_SOURCE => true,
            G_INTERNAL_UART_FRAME_GAP_CLKS => C_FRAME_GAP_CLKS,
            G_INTERNAL_UART_SAMPLE_HOLD_FRAMES => 1,
            G_INTERNAL_UART_SAMPLE_STEP => 100,
            G_INTERNAL_UART_CORRUPT_FRAME_TEST => true,
            G_INTERNAL_UART_CORRUPT_FRAME_PERIOD => 4
        )
        port map (
            clk         => clk,
            rst         => rst,
            uart_rx_i   => '1',
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
        wait for 10 * C_CLOCK_PERIOD;
        wait until rising_edge(clk);
        rst <= '0';

        wait for 20 * C_CLOCK_PERIOD;
        assert leds_o = C_LEDS_OFF
            report "FPGA2 internal-source mode should keep LEDs off before the first frame."
            severity failure;
        assert display_word = C_DISPLAY_NONE
            report "FPGA2 internal-source mode should start on NONE before the first internally generated frame."
            severity failure;

        wait_for_display_value(
            clk_i     => clk,
            display_i => display_word,
            value     => C_DISPLAY_GOOD,
            cycles    => 40_000,
            msg       => "FPGA2 internal-source mode did not reach GOOD after the internal UART generator started."
        );

        assert leds_o = C_LEDS_OFF
            report "FPGA2 internal-source mode should keep LEDs off once GOOD is displayed."
            severity failure;

        wait_for_display_value(
            clk_i     => clk,
            display_i => display_word,
            value     => C_DISPLAY_ERROR,
            cycles    => 80_000,
            msg       => "FPGA2 internal-source mode did not show ERROR after an internally injected bad frame."
        );

        assert leds_o = C_LEDS_OFF
            report "FPGA2 internal-source mode should keep LEDs off once ERROR is displayed."
            severity failure;

        report "tb_fpga2_internal_source completed successfully." severity note;
        tb_done <= '1';
        wait;
    end process;

    timeout_guard : process
    begin
        wait for 100 ms;
        assert tb_done = '1'
            report "Timeout waiting for FPGA2 internal UART source behavior."
            severity failure;
        wait;
    end process;
end architecture sim;
