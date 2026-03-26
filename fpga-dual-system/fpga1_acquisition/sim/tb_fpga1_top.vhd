library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.dual_fpga_system_pkg.all;

entity tb_fpga1_top is
end entity tb_fpga1_top;

architecture sim of tb_fpga1_top is
    constant C_CLOCK_PERIOD   : time     := 1 us;
    constant C_CLOCK_FREQ_HZ  : positive := 1_000_000;
    constant C_BAUD_RATE      : positive := 100_000;
    constant C_SAMPLE_GAP_CLKS : positive := 3_000;

    constant C_SEG_BLANK_N    : std_logic_vector(6 downto 0) := "1111111";
    constant C_SEG_0_N        : std_logic_vector(6 downto 0) := "1000000";
    constant C_SEG_1_N        : std_logic_vector(6 downto 0) := "1111001";
    constant C_SEG_2_N        : std_logic_vector(6 downto 0) := "0100100";
    constant C_SEG_3_N        : std_logic_vector(6 downto 0) := "0110000";
    constant C_SEG_5_N        : std_logic_vector(6 downto 0) := "0010010";
    constant C_SEG_7_N        : std_logic_vector(6 downto 0) := "1111000";
    subtype t_seg_word is std_logic_vector(41 downto 0);
    type t_byte_array is array (0 to C_FRAME_BYTE_COUNT - 1) of t_uart_byte;

    constant C_DISPLAY_0000   : t_seg_word := C_SEG_BLANK_N & C_SEG_BLANK_N & C_SEG_0_N & C_SEG_0_N & C_SEG_0_N & C_SEG_0_N;
    constant C_DISPLAY_0025   : t_seg_word := C_SEG_BLANK_N & C_SEG_BLANK_N & C_SEG_0_N & C_SEG_0_N & C_SEG_2_N & C_SEG_5_N;
    constant C_DISPLAY_0037   : t_seg_word := C_SEG_BLANK_N & C_SEG_BLANK_N & C_SEG_0_N & C_SEG_0_N & C_SEG_3_N & C_SEG_7_N;
    constant C_STABLE_SAMPLE_CODE : natural := 2_500;
    constant C_ALERT_SAMPLE_CODE  : natural := 3_700;

    signal clk               : std_logic := '0';
    signal rst               : std_logic := '1';
    signal sample_value      : t_sample := (others => '0');
    signal sample_valid      : std_logic := '0';
    signal uart_tx_line      : std_logic;
    signal local_error_led   : std_logic;
    signal hex5_n_o          : std_logic_vector(6 downto 0);
    signal hex4_n_o          : std_logic_vector(6 downto 0);
    signal hex3_n_o          : std_logic_vector(6 downto 0);
    signal hex2_n_o          : std_logic_vector(6 downto 0);
    signal hex1_n_o          : std_logic_vector(6 downto 0);
    signal hex0_n_o          : std_logic_vector(6 downto 0);
    signal monitor_byte      : std_logic_vector(7 downto 0);
    signal monitor_valid     : std_logic;
    signal captured_bytes    : t_byte_array := (others => (others => '0'));
    signal captured_count    : natural range 0 to C_FRAME_BYTE_COUNT := 0;
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
        signal clk_i         : in std_logic;
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

begin
    clk <= not clk after C_CLOCK_PERIOD / 2;

    u_dut : entity work.fpga1_top
        generic map (
            G_CLOCK_FREQ_HZ => C_CLOCK_FREQ_HZ,
            G_BAUD_RATE     => C_BAUD_RATE
        )
        port map (
            clk               => clk,
            rst               => rst,
            sample_value_i    => sample_value,
            sample_valid_i    => sample_valid,
            local_error_led_o => local_error_led,
            hex5_n_o          => hex5_n_o,
            hex4_n_o          => hex4_n_o,
            hex3_n_o          => hex3_n_o,
            hex2_n_o          => hex2_n_o,
            hex1_n_o          => hex1_n_o,
            hex0_n_o          => hex0_n_o,
            uart_tx_o         => uart_tx_line
        );

    u_monitor_uart_rx : entity work.uart_rx_monitor
        generic map (
            G_CLOCK_FREQ_HZ => C_CLOCK_FREQ_HZ,
            G_BAUD_RATE     => C_BAUD_RATE
        )
        port map (
            clk        => clk,
            rst        => rst,
            rx         => uart_tx_line,
            data_out   => monitor_byte,
            data_valid => monitor_valid
        );

    stimulus : process
        variable crc_input_v      : t_uart_byte_array(0 to 4);
        variable expected_sample_v : t_sample;
        variable expected_flags_v : t_uart_byte;
    begin
        wait_clock_cycles(clk, 10);
        rst <= '0';
        wait_clock_cycles(clk, 20);

        assert (hex5_n_o & hex4_n_o & hex3_n_o & hex2_n_o & hex1_n_o & hex0_n_o) = C_DISPLAY_0000
            report "FPGA1 should show 0000 before the first ADC sample is latched."
            severity failure;
        assert local_error_led = '0'
            report "FPGA1 local LED should stay off before any ADC sample is processed."
            severity failure;

        drive_sample(clk, sample_value, sample_valid, C_STABLE_SAMPLE_CODE);

        if captured_count /= C_FRAME_BYTE_COUNT then
            wait until captured_count = C_FRAME_BYTE_COUNT;
        end if;

        wait_clock_cycles(clk, 20);

        expected_sample_v := std_logic_vector(to_unsigned(C_STABLE_SAMPLE_CODE, C_SAMPLE_WIDTH));
        expected_flags_v  := sensor_state_to_flags(C_SENSOR_STATE_NORMAL, '1', '1');
        crc_input_v(0)    := C_FRAME_CONTROL;
        crc_input_v(1)    := x"00";
        crc_input_v(2)    := "0000" & expected_sample_v(C_SAMPLE_WIDTH - 1 downto 8);
        crc_input_v(3)    := expected_sample_v(7 downto 0);
        crc_input_v(4)    := expected_flags_v;

        assert (hex5_n_o & hex4_n_o & hex3_n_o & hex2_n_o & hex1_n_o & hex0_n_o) = C_DISPLAY_0025
            report "FPGA1 should display 25 when the incoming sample code is 2500."
            severity failure;
        assert local_error_led = '0'
            report "FPGA1 local LED should stay off while the sample remains inside the 1200..3600 range."
            severity failure;
        assert captured_bytes(0) = C_FRAME_HEADER
            report "FPGA1 frame byte 0 should be the frame header."
            severity failure;
        assert captured_bytes(1) = C_FRAME_CONTROL
            report "FPGA1 frame byte 1 should be the control byte."
            severity failure;
        assert captured_bytes(2) = x"00"
            report "FPGA1 frame byte 2 should contain the initial sequence counter."
            severity failure;
        assert captured_bytes(3)(7 downto 4) = "0000"
            report "FPGA1 frame byte 3 should keep the upper nibble reserved for a 12-bit ADC payload."
            severity failure;
        assert (captured_bytes(3)(3 downto 0) & captured_bytes(4)) = expected_sample_v
            report "FPGA1 should transmit the ADC code in the payload field."
            severity failure;
        assert captured_bytes(5) = expected_flags_v
            report "FPGA1 should set range-ok and source-is-ADC in the flags for a clean sample."
            severity failure;
        assert captured_bytes(6) = calc_crc8(crc_input_v)
            report "FPGA1 should transmit the CRC8 calculated over control, sequence, payload, and flags."
            severity failure;
        assert captured_bytes(7) = C_FRAME_FOOTER
            report "FPGA1 frame byte 7 should be the footer."
            severity failure;

        drive_sample(clk, sample_value, sample_valid, C_ALERT_SAMPLE_CODE);
        wait_clock_cycles(clk, 20);

        assert (hex5_n_o & hex4_n_o & hex3_n_o & hex2_n_o & hex1_n_o & hex0_n_o) = C_DISPLAY_0037
            report "FPGA1 should display 37 when the incoming sample code is 3700."
            severity failure;
        assert local_error_led = '1'
            report "FPGA1 local LED should blink when the sample code is above 3600."
            severity failure;

        drive_sample(clk, sample_value, sample_valid, C_STABLE_SAMPLE_CODE);
        wait_clock_cycles(clk, 20);

        assert (hex5_n_o & hex4_n_o & hex3_n_o & hex2_n_o & hex1_n_o & hex0_n_o) = C_DISPLAY_0025
            report "FPGA1 should return to 25 when the incoming sample code goes back to 2500."
            severity failure;
        assert local_error_led = '0'
            report "FPGA1 local LED should clear once the sample code returns inside the 1200..3600 window."
            severity failure;

        report "tb_fpga1_top completed successfully." severity note;
        tb_done <= '1';
        wait;
    end process;

    capture : process (clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                captured_count <= 0;
            elsif monitor_valid = '1' then
                if captured_count < C_FRAME_BYTE_COUNT then
                    captured_bytes(captured_count) <= monitor_byte;
                    captured_count                 <= captured_count + 1;
                end if;
            end if;
        end if;
    end process;

    timeout_guard : process
    begin
        wait for 80 ms;
        assert tb_done = '1'
            report "Timeout waiting for FPGA1 ADC/UART behavior."
            severity failure;
        wait;
    end process;
end architecture sim;
