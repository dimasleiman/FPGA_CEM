library ieee;
use ieee.std_logic_1164.all;

library work;
use work.dual_fpga_system_pkg.all;

entity tb_fpga1_wrapper_fake_source is
end entity tb_fpga1_wrapper_fake_source;

architecture sim of tb_fpga1_wrapper_fake_source is
    constant C_CLOCK_PERIOD  : time     := 1 us;
    constant C_CLOCK_FREQ_HZ : positive := 1_000_000;
    constant C_BAUD_RATE     : positive := 100_000;
    subtype t_seg_word is std_logic_vector(41 downto 0);

    constant C_SEG_BLANK_N   : std_logic_vector(6 downto 0) := "1111111";
    constant C_SEG_0_N       : std_logic_vector(6 downto 0) := "1000000";
    constant C_DISPLAY_0000  : t_seg_word := C_SEG_BLANK_N & C_SEG_BLANK_N & C_SEG_0_N & C_SEG_0_N & C_SEG_0_N & C_SEG_0_N;

    signal clock_50_i        : std_logic := '0';
    signal reset_source_i    : std_logic := '0';
    signal local_error_led_o : std_logic;
    signal hex5_n_o          : std_logic_vector(6 downto 0);
    signal hex4_n_o          : std_logic_vector(6 downto 0);
    signal hex3_n_o          : std_logic_vector(6 downto 0);
    signal hex2_n_o          : std_logic_vector(6 downto 0);
    signal hex1_n_o          : std_logic_vector(6 downto 0);
    signal hex0_n_o          : std_logic_vector(6 downto 0);
    signal display_word      : t_seg_word;
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

    procedure wait_for_display_not_value (
        signal clk_i     : in std_logic;
        signal display_i : in t_seg_word;
        constant value   : in t_seg_word;
        constant cycles  : in positive;
        constant msg     : in string
    ) is
    begin
        for cycle_index in 1 to cycles loop
            if display_i /= value then
                return;
            end if;

            wait until rising_edge(clk_i);
        end loop;

        assert false
            report msg
            severity failure;
    end procedure wait_for_display_not_value;

    procedure wait_for_signal_value (
        signal clk_i    : in std_logic;
        signal signal_i : in std_logic;
        constant value  : in std_logic;
        constant cycles : in positive;
        constant msg    : in string
    ) is
    begin
        for cycle_index in 1 to cycles loop
            if signal_i = value then
                return;
            end if;

            wait until rising_edge(clk_i);
        end loop;

        assert false
            report msg
            severity failure;
    end procedure wait_for_signal_value;
begin
    clock_50_i <= not clock_50_i after C_CLOCK_PERIOD / 2;
    display_word <= hex5_n_o & hex4_n_o & hex3_n_o & hex2_n_o & hex1_n_o & hex0_n_o;

    u_dut : entity work.de10_lite_fpga1_wrapper
        generic map (
            G_CLOCK_FREQ_HZ                             => C_CLOCK_FREQ_HZ,
            G_BAUD_RATE                                 => C_BAUD_RATE,
            G_USE_FAKE_SENSOR_GENERATOR                 => true,
            G_FAKE_SENSOR_UPDATE_DIVIDER                => 4,
            G_FAKE_SENSOR_HOLD_TICKS_PER_VALUE          => 1,
            G_FAKE_SENSOR_STEP_CODE                     => 1_200,
            G_FAKE_SENSOR_RANDOM_SAMPLE_MODE            => false,
            G_FAKE_SENSOR_MIN_CODE                      => 1_200,
            G_FAKE_SENSOR_MAX_CODE                      => 3_900,
            G_RESET_ACTIVE_LEVEL                        => '0'
        )
        port map (
            clock_50_i        => clock_50_i,
            reset_source_i    => reset_source_i,
            local_error_led_o => local_error_led_o,
            hex5_n_o          => hex5_n_o,
            hex4_n_o          => hex4_n_o,
            hex3_n_o          => hex3_n_o,
            hex2_n_o          => hex2_n_o,
            hex1_n_o          => hex1_n_o,
            hex0_n_o          => hex0_n_o,
            ledr1_o           => open,
            ledr2_o           => open,
            ledr3_o           => open,
            ledr4_o           => open,
            ledr5_o           => open,
            ledr6_o           => open,
            ledr7_o           => open,
            ledr8_o           => open,
            ledr9_o           => open,
            uart_tx_o         => open
        );

    stimulus : process
    begin
        wait_clock_cycles(clock_50_i, 10);
        assert display_word = C_DISPLAY_0000
            report "FPGA1 wrapper should hold 0000 while reset keeps the fake sensor generator inactive."
            severity failure;
        assert local_error_led_o = '0'
            report "FPGA1 wrapper local LED should stay off while reset keeps the fake sensor generator inactive."
            severity failure;

        reset_source_i <= '1';
        wait_clock_cycles(clock_50_i, 10);

        wait_for_display_not_value(
            clk_i     => clock_50_i,
            display_i => display_word,
            value     => C_DISPLAY_0000,
            cycles    => 160,
            msg       => "FPGA1 wrapper display did not update after the fake sensor generator was enabled."
        );

        report "tb_fpga1_wrapper_fake_source completed successfully." severity note;
        tb_done <= '1';
        wait;
    end process;

    timeout_guard : process
    begin
        wait for 10 ms;
        assert tb_done = '1'
            report "Timeout waiting for the FPGA1 fake-source wrapper behavior."
            severity failure;
        wait;
    end process;
end architecture sim;
