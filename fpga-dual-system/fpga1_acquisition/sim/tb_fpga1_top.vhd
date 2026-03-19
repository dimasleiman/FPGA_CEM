library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_fpga1_top is
end entity tb_fpga1_top;

architecture sim of tb_fpga1_top is
    constant C_CLOCK_PERIOD          : time     := 1 us;
    constant C_CLOCK_FREQ_HZ         : positive := 1_000_000;
    constant C_BAUD_RATE             : positive := 10_000;
    constant C_SENSOR_UPDATE_DIVIDER : positive := 16;
    constant C_SENSOR_STEP           : positive := 17;

    type t_byte_array is array (0 to 4) of std_logic_vector(7 downto 0);

    signal clk            : std_logic := '0';
    signal rst            : std_logic := '1';
    signal uart_tx_line   : std_logic;
    signal monitor_byte   : std_logic_vector(7 downto 0);
    signal monitor_valid  : std_logic;
    signal captured_bytes : t_byte_array := (others => (others => '0'));
    signal captured_count : natural range 0 to 5 := 0;
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
                if captured_count < 5 then
                    captured_bytes(captured_count) <= monitor_byte;
                    captured_count                 <= captured_count + 1;
                end if;
            end if;
        end if;
    end process;

    checks : process
    begin
        wait until rst = '0';
        wait until captured_count = 5;
        wait for 10 * C_CLOCK_PERIOD;

        assert captured_bytes(0) = x"AA"
            report "FPGA1 frame byte 0 should be the header xAA."
            severity failure;
        assert captured_bytes(1) = x"01"
            report "FPGA1 frame byte 1 should contain the upper sample bits for the first sample."
            severity failure;
        assert captured_bytes(2) = x"01"
            report "FPGA1 frame byte 2 should contain the lower sample nibble for the first sample."
            severity failure;
        assert captured_bytes(3) = x"00"
            report "FPGA1 frame byte 3 should contain cleared flags for the first sample."
            severity failure;
        assert captured_bytes(4) = x"55"
            report "FPGA1 frame byte 4 should be the footer x55."
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
