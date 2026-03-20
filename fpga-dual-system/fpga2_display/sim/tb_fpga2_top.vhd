library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.dual_fpga_system_pkg.all;
use work.fpga2_pkg.all;

entity tb_fpga2_top is
end entity tb_fpga2_top;

architecture sim of tb_fpga2_top is
    constant C_CLOCK_PERIOD         : time     := 1 us;
    constant C_CLOCK_FREQ_HZ        : positive := 1_000_000;
    constant C_BAUD_RATE            : positive := 10_000;
    constant C_FRAME_TIMEOUT_CLKS   : positive := 20_000;
    constant C_BIT_PERIOD           : time     := C_CLOCK_PERIOD * (C_CLOCK_FREQ_HZ / C_BAUD_RATE);
    constant C_SEG_BLANK_N          : std_logic_vector(6 downto 0) := "1111111";
    constant C_SEG_E_N              : std_logic_vector(6 downto 0) := "0110000";
    constant C_SEG_R_N              : std_logic_vector(6 downto 0) := "1111010";
    constant C_SEG_O_N              : std_logic_vector(6 downto 0) := "0000001";

    signal clk              : std_logic := '0';
    signal rst              : std_logic := '1';
    signal uart_rx_line     : std_logic := '1';
    signal leds_o           : std_logic_vector(3 downto 0);
    signal hex5_n_o         : std_logic_vector(6 downto 0);
    signal hex4_n_o         : std_logic_vector(6 downto 0);
    signal hex3_n_o         : std_logic_vector(6 downto 0);
    signal hex2_n_o         : std_logic_vector(6 downto 0);
    signal hex1_n_o         : std_logic_vector(6 downto 0);
    signal hex0_n_o         : std_logic_vector(6 downto 0);
    signal vga_hsync_o      : std_logic;
    signal vga_vsync_o      : std_logic;
    signal vga_r_o          : std_logic_vector(3 downto 0);
    signal vga_g_o          : std_logic_vector(3 downto 0);
    signal vga_b_o          : std_logic_vector(3 downto 0);
    signal seen_hsync_edge  : std_logic := '0';
    signal seen_vsync_edge  : std_logic := '0';
    signal seen_non_black   : std_logic := '0';
    signal tb_done          : std_logic := '0';

    procedure send_uart_byte (
        signal serial_line : out std_logic;
        constant data_byte : in  std_logic_vector(7 downto 0)
    ) is
    begin
        serial_line <= '0';
        wait for C_BIT_PERIOD;

        for i in 0 to 7 loop
            serial_line <= data_byte(i);
            wait for C_BIT_PERIOD;
        end loop;

        serial_line <= '1';
        wait for C_BIT_PERIOD;
    end procedure send_uart_byte;

    procedure send_frame (
        signal serial_line   : out std_logic;
        constant sequence_id : in  natural;
        constant sample_code : in  natural;
        constant bad_crc     : in  boolean := false
    ) is
        variable frame_bytes  : t_uart_byte_array(0 to C_FRAME_BYTE_COUNT - 1);
        variable crc_input    : t_uart_byte_array(0 to 4);
        variable sample_value : t_sample;
        variable flags_value  : t_uart_byte;
        variable range_ok_v   : std_logic;
    begin
        sample_value := std_logic_vector(to_unsigned(sample_code, C_SAMPLE_WIDTH));
        range_ok_v   := sample_range_ok(sample_value);
        flags_value  := sensor_state_to_flags(
            classify_sample(sample_value, range_ok_v),
            range_ok_v,
            '0'
        );

        frame_bytes(0) := C_FRAME_HEADER;
        frame_bytes(1) := C_FRAME_CONTROL;
        frame_bytes(2) := std_logic_vector(to_unsigned(sequence_id mod 256, 8));
        frame_bytes(3) := "0000" & sample_value(C_SAMPLE_WIDTH - 1 downto 8);
        frame_bytes(4) := sample_value(7 downto 0);
        frame_bytes(5) := flags_value;
        crc_input(0)   := frame_bytes(1);
        crc_input(1)   := frame_bytes(2);
        crc_input(2)   := frame_bytes(3);
        crc_input(3)   := frame_bytes(4);
        crc_input(4)   := frame_bytes(5);
        frame_bytes(6) := calc_crc8(crc_input);
        frame_bytes(7) := C_FRAME_FOOTER;

        if bad_crc then
            frame_bytes(6) := not frame_bytes(6);
        end if;

        for byte_index in frame_bytes'range loop
            send_uart_byte(serial_line, frame_bytes(byte_index));
        end loop;
    end procedure send_frame;
begin
    clk <= not clk after C_CLOCK_PERIOD / 2;

    u_dut : entity work.fpga2_top
        generic map (
            G_CLOCK_FREQ_HZ       => C_CLOCK_FREQ_HZ,
            G_BAUD_RATE           => C_BAUD_RATE,
            G_FRAME_TIMEOUT_CLKS  => C_FRAME_TIMEOUT_CLKS,
            G_FAST_SIMULATION_VGA => true
        )
        port map (
            clk         => clk,
            rst         => rst,
            uart_rx_i   => uart_rx_line,
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
        assert leds_o = C_LED_NO_FRAME
            report "FPGA2 LEDs should start in the no-frame state."
            severity failure;
        assert (hex5_n_o = C_SEG_BLANK_N)
           and (hex4_n_o = C_SEG_BLANK_N)
           and (hex3_n_o = C_SEG_BLANK_N)
           and (hex2_n_o = C_SEG_BLANK_N)
           and (hex1_n_o = C_SEG_BLANK_N)
           and (hex0_n_o = C_SEG_BLANK_N)
            report "FPGA2 seven-segment displays should stay blank before any receive-side verification error."
            severity failure;

        send_frame(uart_rx_line, 0, 2000);
        wait for 20 * C_BIT_PERIOD;
        assert leds_o = C_LED_NORMAL
            report "FPGA2 LEDs should show the normal pattern after a valid normal frame."
            severity failure;
        assert (hex5_n_o = C_SEG_BLANK_N)
           and (hex4_n_o = C_SEG_BLANK_N)
           and (hex3_n_o = C_SEG_BLANK_N)
           and (hex2_n_o = C_SEG_BLANK_N)
           and (hex1_n_o = C_SEG_BLANK_N)
           and (hex0_n_o = C_SEG_BLANK_N)
            report "FPGA2 seven-segment displays should stay blank after a clean frame."
            severity failure;

        send_frame(uart_rx_line, 1, 3000);
        wait for 20 * C_BIT_PERIOD;
        assert leds_o = C_LED_WARNING
            report "FPGA2 LEDs should show the warning pattern after a valid warning frame."
            severity failure;
        assert (hex5_n_o = C_SEG_BLANK_N)
           and (hex4_n_o = C_SEG_BLANK_N)
           and (hex3_n_o = C_SEG_BLANK_N)
           and (hex2_n_o = C_SEG_BLANK_N)
           and (hex1_n_o = C_SEG_BLANK_N)
           and (hex0_n_o = C_SEG_BLANK_N)
            report "FPGA2 seven-segment displays should not flag a receive error for a clean warning-state frame."
            severity failure;

        send_frame(uart_rx_line, 2, 2200, true);
        wait for 20 * C_BIT_PERIOD;
        assert leds_o = C_LED_LINK_WARN
            report "FPGA2 LEDs should show the link-warning pattern after a corrupted frame."
            severity failure;
        assert (hex5_n_o = C_SEG_BLANK_N)
           and (hex4_n_o = C_SEG_E_N)
           and (hex3_n_o = C_SEG_R_N)
           and (hex2_n_o = C_SEG_R_N)
           and (hex1_n_o = C_SEG_O_N)
           and (hex0_n_o = C_SEG_R_N)
            report "FPGA2 seven-segment displays should spell the ERROR approximation after a corrupted frame."
            severity failure;

        send_frame(uart_rx_line, 4, 2000);
        wait for 20 * C_BIT_PERIOD;
        assert leds_o = C_LED_LINK_WARN
            report "FPGA2 LEDs should stay in the link-warning pattern when sequence continuity is broken."
            severity failure;
        assert (hex5_n_o = C_SEG_BLANK_N)
           and (hex4_n_o = C_SEG_E_N)
           and (hex3_n_o = C_SEG_R_N)
           and (hex2_n_o = C_SEG_R_N)
           and (hex1_n_o = C_SEG_O_N)
           and (hex0_n_o = C_SEG_R_N)
            report "FPGA2 seven-segment displays should keep the ERROR approximation while the receive link stays degraded."
            severity failure;

        send_frame(uart_rx_line, 5, 3500);
        wait for 20 * C_BIT_PERIOD;
        assert leds_o = C_LED_ERROR
            report "FPGA2 LEDs should recover to the current sensor error state after a clean frame."
            severity failure;
        assert (hex5_n_o = C_SEG_BLANK_N)
           and (hex4_n_o = C_SEG_BLANK_N)
           and (hex3_n_o = C_SEG_BLANK_N)
           and (hex2_n_o = C_SEG_BLANK_N)
           and (hex1_n_o = C_SEG_BLANK_N)
           and (hex0_n_o = C_SEG_BLANK_N)
            report "FPGA2 seven-segment displays should clear once receive verification has recovered, even if the sensor state is error."
            severity failure;

        wait for 30 ms;
        assert leds_o = C_LED_NO_FRAME
            report "FPGA2 LEDs should return to the no-frame pattern after the timeout interval expires."
            severity failure;
        assert (hex5_n_o = C_SEG_BLANK_N)
           and (hex4_n_o = C_SEG_BLANK_N)
           and (hex3_n_o = C_SEG_BLANK_N)
           and (hex2_n_o = C_SEG_BLANK_N)
           and (hex1_n_o = C_SEG_BLANK_N)
           and (hex0_n_o = C_SEG_BLANK_N)
            report "FPGA2 seven-segment displays should be blank again after the receive timeout state."
            severity failure;

        assert seen_hsync_edge = '1'
            report "FPGA2 should drive VGA horizontal sync activity."
            severity failure;
        assert seen_vsync_edge = '1'
            report "FPGA2 should drive VGA vertical sync activity."
            severity failure;
        assert seen_non_black = '1'
            report "FPGA2 should generate non-black VGA dashboard pixels."
            severity failure;

        report "tb_fpga2_top completed successfully." severity note;
        tb_done <= '1';
        wait;
    end process;

    monitor_hsync : process (vga_hsync_o)
    begin
        if rst = '0' and vga_hsync_o'event then
            seen_hsync_edge <= '1';
        end if;
    end process;

    monitor_vsync : process (vga_vsync_o)
    begin
        if rst = '0' and vga_vsync_o'event then
            seen_vsync_edge <= '1';
        end if;
    end process;

    monitor_pixels : process (clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                seen_non_black <= '0';
            elsif (vga_r_o /= x"0") or (vga_g_o /= x"0") or (vga_b_o /= x"0") then
                seen_non_black <= '1';
            end if;
        end if;
    end process;

    timeout_guard : process
    begin
        wait for 200 ms;
        assert tb_done = '1'
            report "Timeout waiting for FPGA2 LED update."
            severity failure;
        wait;
    end process;
end architecture sim;
