library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.dual_fpga_system_pkg.all;

entity tb_fpga1_top is
end entity tb_fpga1_top;

architecture sim of tb_fpga1_top is
    constant C_CLOCK_PERIOD          : time     := 1 us;
    constant C_CLOCK_FREQ_HZ         : positive := 1_000_000;
    constant C_BAUD_RATE             : positive := 10_000;
    constant C_SENSOR_UPDATE_DIVIDER : positive := 16;
    constant C_SENSOR_STEP           : positive := 17;

    type t_byte_array is array (0 to C_FRAME_BYTE_COUNT - 1) of t_uart_byte;

    signal clk            : std_logic := '0';
    signal rst            : std_logic := '1';
    signal uart_tx_line   : std_logic;
    signal monitor_byte   : std_logic_vector(7 downto 0);
    signal monitor_valid  : std_logic;
    signal captured_bytes : t_byte_array := (others => (others => '0'));
    signal captured_count : natural range 0 to C_FRAME_BYTE_COUNT := 0;
    signal tb_done        : std_logic := '0';
begin
    clk <= not clk after C_CLOCK_PERIOD / 2;

    u_dut : entity work.fpga1_top
        generic map (
            G_CLOCK_FREQ_HZ         => C_CLOCK_FREQ_HZ,
            G_BAUD_RATE             => C_BAUD_RATE,
            G_SENSOR_UPDATE_DIVIDER => C_SENSOR_UPDATE_DIVIDER,
            G_SENSOR_STEP           => C_SENSOR_STEP
        )
        port map (
            clk       => clk,
            rst       => rst,
            uart_tx_o => uart_tx_line
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
    begin
        wait for 10 * C_CLOCK_PERIOD;
        wait until rising_edge(clk);
        rst <= '0';
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

    checks : process
        variable crc_input        : t_uart_byte_array(0 to 4);
        variable expected_sample  : t_sample;
        variable expected_flags   : t_uart_byte;
        variable reconstructed    : t_sample;
        variable expected_range_ok : std_logic;
    begin
        wait until rst = '0';
        wait until captured_count = C_FRAME_BYTE_COUNT;
        wait for 10 * C_CLOCK_PERIOD;

        reconstructed := captured_bytes(3)(3 downto 0) & captured_bytes(4);
        expected_sample := std_logic_vector(to_unsigned(C_SENSOR_MIN_CODE + C_SENSOR_STEP, C_SAMPLE_WIDTH));
        expected_range_ok := sample_range_ok(expected_sample);
        expected_flags := sensor_state_to_flags(
            classify_sample(expected_sample, expected_range_ok),
            expected_range_ok,
            '0'
        );

        crc_input(0) := captured_bytes(1);
        crc_input(1) := captured_bytes(2);
        crc_input(2) := captured_bytes(3);
        crc_input(3) := captured_bytes(4);
        crc_input(4) := captured_bytes(5);

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
            report "FPGA1 frame byte 3 should keep the upper nibble reserved for a 12-bit sample payload."
            severity failure;
        assert reconstructed = expected_sample
            report "FPGA1 should transmit the first fake-sensor sample in the payload field."
            severity failure;
        assert captured_bytes(5) = expected_flags
            report "FPGA1 should transmit flags consistent with the first sample classification."
            severity failure;
        assert captured_bytes(6) = calc_crc8(crc_input)
            report "FPGA1 should transmit the CRC8 calculated across control, sequence, payload, and flags."
            severity failure;
        assert captured_bytes(7) = C_FRAME_FOOTER
            report "FPGA1 frame byte 7 should be the footer."
            severity failure;

        report "tb_fpga1_top completed successfully." severity note;
        tb_done <= '1';
        wait;
    end process;

    timeout_guard : process
    begin
        wait for 10 ms;
        assert tb_done = '1'
            report "Timeout waiting for FPGA1 UART traffic."
            severity failure;
        wait;
    end process;
end architecture sim;
