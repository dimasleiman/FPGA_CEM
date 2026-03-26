library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.dual_fpga_system_pkg.all;
use work.fpga1_pkg.all;

entity fpga1_top is
    generic (
        G_CLOCK_FREQ_HZ         : positive := 50_000_000;
        G_BAUD_RATE             : positive := 115_200;
        G_SOURCE_IS_ADC         : std_logic := C_REAL_SENSOR_SOURCE_IS_ADC;
        G_EMI_WINDOW_SIZE       : positive := C_DEFAULT_EMI_WINDOW_SIZE;
        G_EMI_SPREAD_WARNING_THRESHOLD : positive := C_DEFAULT_EMI_SPREAD_WARNING_THRESHOLD_CODES;
        G_TEST_FORCE_LEDR0_BLINK : boolean := false;
        G_TEST_FORCE_FIXED_DISPLAY : boolean := false;
        G_TEST_FIXED_DISPLAY_VALUE : natural := 1234;
        G_TEST_FORCE_LOW_DIGIT_SEQUENCE : boolean := false;
        G_TEST_FORCE_SEGMENT_PATTERN_LOOP : boolean := false;
        G_TEST_DISPLAY_SEQUENCE_STEP_CLKS : positive := 50_000_000
    );
    port (
        clk               : in  std_logic;
        rst               : in  std_logic;
        sample_value_i    : in  t_sample;
        sample_valid_i    : in  std_logic;
        local_error_led_o : out std_logic;
        hex5_n_o          : out std_logic_vector(6 downto 0);
        hex4_n_o          : out std_logic_vector(6 downto 0);
        hex3_n_o          : out std_logic_vector(6 downto 0);
        hex2_n_o          : out std_logic_vector(6 downto 0);
        hex1_n_o          : out std_logic_vector(6 downto 0);
        hex0_n_o          : out std_logic_vector(6 downto 0);
        uart_tx_o         : out std_logic
    );
end entity fpga1_top;

architecture rtl of fpga1_top is
    function max_positive(
        left_value  : natural;
        right_value : natural
    ) return positive is
    begin
        if left_value >= right_value then
            return left_value;
        end if;

        return right_value;
    end function max_positive;

    type t_tx_state is (
        ST_IDLE,
        ST_LOAD_FRAME,
        ST_WAIT_FRAME_READY,
        ST_START_BYTE,
        ST_WAIT_UART_BUSY,
        ST_WAIT_UART_DONE
    );
    subtype t_decimal_digit is std_logic_vector(3 downto 0);
    type t_display_sequence_array is array (natural range <>) of t_sample;
    type t_segment_pattern_row is array (4 downto 0) of t_decimal_digit;
    type t_segment_pattern_array is array (natural range <>) of t_segment_pattern_row;

    constant C_ERROR_LED_BLINK_HZ    : positive := 8;
    constant C_ERROR_LED_TOGGLE_CLKS : positive := max_positive(
        1,
        G_CLOCK_FREQ_HZ / (2 * C_ERROR_LED_BLINK_HZ)
    );
    constant C_TEST_LED_BLINK_HZ     : positive := 4;
    constant C_SEG_MINUS_N           : std_logic_vector(6 downto 0) := "0111111";
    constant C_HEX_OFF_N             : std_logic_vector(6 downto 0) := (others => '1');
    constant C_BLANK_DIGIT           : t_decimal_digit := (others => '1');
    constant C_LOW_DIGIT_SEQUENCE_VALUES : t_display_sequence_array(0 to 18) := (
        std_logic_vector(to_unsigned(1500, C_SAMPLE_WIDTH)),
        std_logic_vector(to_unsigned(1501, C_SAMPLE_WIDTH)),
        std_logic_vector(to_unsigned(1502, C_SAMPLE_WIDTH)),
        std_logic_vector(to_unsigned(1503, C_SAMPLE_WIDTH)),
        std_logic_vector(to_unsigned(1504, C_SAMPLE_WIDTH)),
        std_logic_vector(to_unsigned(1505, C_SAMPLE_WIDTH)),
        std_logic_vector(to_unsigned(1506, C_SAMPLE_WIDTH)),
        std_logic_vector(to_unsigned(1507, C_SAMPLE_WIDTH)),
        std_logic_vector(to_unsigned(1508, C_SAMPLE_WIDTH)),
        std_logic_vector(to_unsigned(1509, C_SAMPLE_WIDTH)),
        std_logic_vector(to_unsigned(1510, C_SAMPLE_WIDTH)),
        std_logic_vector(to_unsigned(1520, C_SAMPLE_WIDTH)),
        std_logic_vector(to_unsigned(1530, C_SAMPLE_WIDTH)),
        std_logic_vector(to_unsigned(1540, C_SAMPLE_WIDTH)),
        std_logic_vector(to_unsigned(1550, C_SAMPLE_WIDTH)),
        std_logic_vector(to_unsigned(1560, C_SAMPLE_WIDTH)),
        std_logic_vector(to_unsigned(1570, C_SAMPLE_WIDTH)),
        std_logic_vector(to_unsigned(1580, C_SAMPLE_WIDTH)),
        std_logic_vector(to_unsigned(1590, C_SAMPLE_WIDTH))
    );
    constant C_SEGMENT_PATTERN_VALUES : t_segment_pattern_array(0 to 3) := (
        0 => (4 => C_BLANK_DIGIT, 3 => "0010", 2 => "0011", 1 => "0100", 0 => "0101"),
        1 => (4 => "0001",        3 => "0001", 2 => "0001", 1 => "0001", 0 => "0001"),
        2 => (4 => C_BLANK_DIGIT, 3 => "0001", 2 => "0000", 1 => "0000", 0 => "0101"),
        3 => (4 => C_BLANK_DIGIT, 3 => "0000", 2 => "1000", 1 => "0001", 0 => "1000")
    );
    constant C_TEST_LED_TOGGLE_CLKS  : positive := max_positive(
        1,
        G_CLOCK_FREQ_HZ / (2 * C_TEST_LED_BLINK_HZ)
    );
    constant C_LED_COUNTER_MAX_CLKS  : positive := max_positive(
        C_ERROR_LED_TOGGLE_CLKS,
        C_TEST_LED_TOGGLE_CLKS
    );

    signal raw_sample             : t_sample := (others => '0');
    signal raw_sample_valid       : std_logic := '0';
    signal normalized_temperature_c : integer range C_DISPLAY_TEMP_MIN_C to C_DISPLAY_TEMP_MAX_C := 0;
    signal normalized_sample_valid : std_logic := '0';
    signal sample_range_ok        : std_logic := '0';
    signal sample_range_error     : std_logic := '1';
    signal sensor_state           : t_sensor_state := C_SENSOR_STATE_INVALID;

    signal pending_sample         : t_sample := (others => '0');
    signal pending_range_ok       : std_logic := '0';
    signal pending_display_number : natural range 0 to 9999 := 0;
    signal pending_display_negative : std_logic := '0';
    signal pending_sample_ready   : std_logic := '0';

    signal latched_sample         : t_sample := (others => '0');
    signal latched_range_ok       : std_logic := '0';
    signal latched_sensor_state   : t_sensor_state := C_SENSOR_STATE_INVALID;
    signal latched_display_number : natural range 0 to 9999 := 0;
    signal latched_display_negative : std_logic := '0';
    signal display_number         : natural range 0 to 9999 := 0;
    signal display_negative       : std_logic := '0';
    signal display_bcd            : std_logic_vector(15 downto 0) := (others => '0');
    signal display_binary         : std_logic_vector(13 downto 0) := (others => '0');
    signal display_hex4_digit     : t_decimal_digit := C_BLANK_DIGIT;
    signal display_thousands      : t_decimal_digit := (others => '0');
    signal display_hundreds       : t_decimal_digit := (others => '0');
    signal display_tens           : t_decimal_digit := (others => '0');
    signal display_units          : t_decimal_digit := (others => '0');
    signal display_sequence_index : natural range 0 to C_LOW_DIGIT_SEQUENCE_VALUES'length - 1 := 0;
    signal display_sequence_count : natural range 0 to G_TEST_DISPLAY_SEQUENCE_STEP_CLKS - 1 := 0;
    signal hex4_digit_n           : std_logic_vector(6 downto 0) := C_HEX_OFF_N;
    signal hex3_digit_n           : std_logic_vector(6 downto 0) := C_HEX_OFF_N;
    signal hex2_digit_n           : std_logic_vector(6 downto 0) := C_HEX_OFF_N;
    signal hex1_digit_n           : std_logic_vector(6 downto 0) := C_HEX_OFF_N;
    signal hex0_digit_n           : std_logic_vector(6 downto 0) := C_HEX_OFF_N;

    signal frame_load       : std_logic := '0';
    signal frame_ready      : std_logic := '0';
    signal frame_byte_index : unsigned(2 downto 0) := (others => '0');
    signal frame_byte       : t_uart_byte := (others => '0');

    signal uart_data        : t_uart_byte := (others => '0');
    signal uart_start       : std_logic := '0';
    signal uart_busy        : std_logic := '0';

    signal tx_state         : t_tx_state := ST_IDLE;
    signal local_error_active   : std_logic := '0';
    signal local_error_active_d : std_logic := '0';
    signal local_error_led_reg  : std_logic := '0';
    signal error_led_counter    : natural range 0 to C_LED_COUNTER_MAX_CLKS - 1 := 0;
begin
    assert G_TEST_FIXED_DISPLAY_VALUE < 10_000
        report "fpga1_top requires G_TEST_FIXED_DISPLAY_VALUE to fit on the 4-digit decimal display."
        severity failure;
    assert not (G_TEST_FORCE_LOW_DIGIT_SEQUENCE and G_TEST_FORCE_SEGMENT_PATTERN_LOOP)
        report "fpga1_top requires at most one display sequence test mode at a time."
        severity failure;

    raw_sample       <= sample_value_i;
    raw_sample_valid <= sample_valid_i;

    u_sample_normalizer : entity work.sample_normalizer
        port map (
            sample_in      => raw_sample,
            sample_valid_i => raw_sample_valid,
            temp_c_o       => normalized_temperature_c,
            sample_valid_o => normalized_sample_valid
        );

    u_sample_validator : entity work.sample_validator
        port map (
            sample_value => raw_sample,
            sample_valid => raw_sample_valid,
            range_ok     => sample_range_ok,
            range_error  => sample_range_error
        );

    u_sample_classifier : entity work.sample_classifier
        port map (
            sample_valid => pending_sample_ready,
            range_ok     => pending_range_ok,
            sensor_state => sensor_state
        );

    u_display_bcd : entity work.bin_to_bcd
        generic map (
            G_INPUT_WIDTH => 14,
            G_DIGIT_COUNT => 4
        )
        port map (
            binary_i => display_binary,
            bcd_o    => display_bcd
        );

    u_hex4_digit : entity work.digit_to_7seg_decimal_n
        port map (
            digit_i     => display_hex4_digit,
            seg_n_o     => hex4_digit_n
        );

    u_hex3_digit : entity work.digit_to_7seg_decimal_n
        port map (
            digit_i     => display_thousands,
            seg_n_o     => hex3_digit_n
        );

    u_hex2_digit : entity work.digit_to_7seg_decimal_n
        port map (
            digit_i => display_hundreds,
            seg_n_o     => hex2_digit_n
        );

    u_hex1_digit : entity work.digit_to_7seg_decimal_n
        port map (
            digit_i => display_tens,
            seg_n_o     => hex1_digit_n
        );

    u_hex0_digit : entity work.digit_to_7seg_decimal_n
        port map (
            digit_i => display_units,
            seg_n_o     => hex0_digit_n
        );

    u_frame_builder : entity work.frame_builder
        port map (
            clk           => clk,
            rst           => rst,
            load_frame    => frame_load,
            sample_value  => latched_sample,
            sensor_state  => latched_sensor_state,
            range_ok      => latched_range_ok,
            source_is_adc => G_SOURCE_IS_ADC,
            byte_index    => frame_byte_index,
            byte_out      => frame_byte,
            frame_ready   => frame_ready
        );

    u_uart_tx : entity work.uart_tx
        generic map (
            G_CLOCK_FREQ_HZ => G_CLOCK_FREQ_HZ,
            G_BAUD_RATE     => G_BAUD_RATE
        )
        port map (
            clk     => clk,
            rst     => rst,
            data_in => uart_data,
            start   => uart_start,
            tx      => uart_tx_o,
            busy    => uart_busy
        );

    process (clk)
        variable display_temp_v : integer range C_DISPLAY_TEMP_MIN_C to C_DISPLAY_TEMP_MAX_C;
        variable display_abs_v  : integer range 0 to 9999;
    begin
        if rising_edge(clk) then
            if rst = '1' then
                pending_sample         <= (others => '0');
                pending_range_ok       <= '0';
                pending_display_number <= 0;
                pending_display_negative <= '0';
                pending_sample_ready   <= '0';
                latched_sample         <= (others => '0');
                latched_range_ok     <= '0';
                latched_sensor_state <= C_SENSOR_STATE_INVALID;
                latched_display_number <= 0;
                latched_display_negative <= '0';
                frame_load           <= '0';
                frame_byte_index     <= (others => '0');
                uart_data            <= (others => '0');
                uart_start           <= '0';
                tx_state             <= ST_IDLE;
            else
                frame_load <= '0';
                uart_start <= '0';

                if normalized_sample_valid = '1' then
                    display_temp_v := normalized_temperature_c;
                    display_abs_v := display_temp_v;
                    pending_display_negative <= '0';

                    if display_abs_v > 9999 then
                        pending_display_number <= 9999;
                    else
                        pending_display_number <= display_abs_v;
                    end if;

                    pending_sample       <= raw_sample;
                    pending_range_ok     <= sample_range_ok and (not sample_range_error);
                    pending_sample_ready <= '1';
                end if;

                case tx_state is
                    when ST_IDLE =>
                        frame_byte_index <= (others => '0');

                        if pending_sample_ready = '1' then
                            latched_sample       <= pending_sample;
                            latched_range_ok     <= pending_range_ok;
                            latched_sensor_state <= sensor_state;
                            latched_display_number <= pending_display_number;
                            latched_display_negative <= pending_display_negative;
                            pending_sample_ready <= '0';
                            tx_state             <= ST_LOAD_FRAME;
                        end if;

                    when ST_LOAD_FRAME =>
                        frame_load       <= '1';
                        frame_byte_index <= (others => '0');
                        tx_state         <= ST_WAIT_FRAME_READY;

                    when ST_WAIT_FRAME_READY =>
                        if frame_ready = '1' then
                            tx_state <= ST_START_BYTE;
                        end if;

                    when ST_START_BYTE =>
                        if uart_busy = '0' then
                            -- Present the selected frame byte to uart_tx and
                            -- pulse start for one clock cycle.
                            uart_data  <= frame_byte;
                            uart_start <= '1';
                            tx_state   <= ST_WAIT_UART_BUSY;
                        end if;

                    when ST_WAIT_UART_BUSY =>
                        if uart_busy = '1' then
                            tx_state <= ST_WAIT_UART_DONE;
                        end if;

                    when ST_WAIT_UART_DONE =>
                        if uart_busy = '0' then
                            if to_integer(frame_byte_index) = C_FRAME_BYTE_COUNT - 1 then
                                tx_state <= ST_IDLE;
                            else
                                frame_byte_index <= frame_byte_index + 1;
                                tx_state         <= ST_START_BYTE;
                            end if;
                        end if;
                end case;
            end if;
        end if;
    end process;

    process (clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                display_sequence_index <= 0;
                display_sequence_count <= 0;
            elsif G_TEST_FORCE_SEGMENT_PATTERN_LOOP or G_TEST_FORCE_LOW_DIGIT_SEQUENCE then
                if display_sequence_count = G_TEST_DISPLAY_SEQUENCE_STEP_CLKS - 1 then
                    display_sequence_count <= 0;

                    if (G_TEST_FORCE_SEGMENT_PATTERN_LOOP and (display_sequence_index = C_SEGMENT_PATTERN_VALUES'high))
                        or (G_TEST_FORCE_LOW_DIGIT_SEQUENCE and (display_sequence_index = C_LOW_DIGIT_SEQUENCE_VALUES'high)) then
                        display_sequence_index <= 0;
                    else
                        display_sequence_index <= display_sequence_index + 1;
                    end if;
                else
                    display_sequence_count <= display_sequence_count + 1;
                end if;
            else
                display_sequence_index <= 0;
                display_sequence_count <= 0;
            end if;
        end if;
    end process;

    -- LEDR0 blinks only when the raw sensor code leaves the accepted
    -- 1200..3600 window.
    local_error_active <= '1'
        when latched_sensor_state = C_SENSOR_STATE_ERROR
        else '0';

    -- Outside test modes, the board shows the last sample as a decimal
    -- temperature obtained by dividing the raw code by 100.
    display_number <= to_integer(unsigned(C_LOW_DIGIT_SEQUENCE_VALUES(display_sequence_index)))
        when G_TEST_FORCE_LOW_DIGIT_SEQUENCE
        else G_TEST_FIXED_DISPLAY_VALUE
        when G_TEST_FORCE_FIXED_DISPLAY
        else latched_display_number;

    display_negative <= '0'
        when G_TEST_FORCE_LOW_DIGIT_SEQUENCE or G_TEST_FORCE_FIXED_DISPLAY or G_TEST_FORCE_SEGMENT_PATTERN_LOOP
        else latched_display_negative;

    display_binary <= std_logic_vector(to_unsigned(display_number, display_binary'length));

    process (all)
    begin
        if G_TEST_FORCE_SEGMENT_PATTERN_LOOP then
            -- Drive explicit digit patterns to isolate board segment mapping
            -- from the sensor and decimal-conversion path.
            display_hex4_digit <= C_SEGMENT_PATTERN_VALUES(display_sequence_index)(4);
            display_thousands  <= C_SEGMENT_PATTERN_VALUES(display_sequence_index)(3);
            display_hundreds   <= C_SEGMENT_PATTERN_VALUES(display_sequence_index)(2);
            display_tens       <= C_SEGMENT_PATTERN_VALUES(display_sequence_index)(1);
            display_units      <= C_SEGMENT_PATTERN_VALUES(display_sequence_index)(0);
        else
            display_hex4_digit <= C_BLANK_DIGIT;
            display_thousands <= display_bcd(15 downto 12);
            display_hundreds  <= display_bcd(11 downto 8);
            display_tens      <= display_bcd(7 downto 4);
            display_units     <= display_bcd(3 downto 0);
        end if;
    end process;

    process (clk)
    begin
        if rising_edge(clk) then
            if G_TEST_FORCE_LEDR0_BLINK then
                if rst = '1' then
                    local_error_active_d <= '0';
                    local_error_led_reg  <= '0';
                    error_led_counter    <= 0;
                elsif error_led_counter = C_TEST_LED_TOGGLE_CLKS - 1 then
                    local_error_led_reg <= not local_error_led_reg;
                    error_led_counter   <= 0;
                else
                    error_led_counter <= error_led_counter + 1;
                end if;
            elsif rst = '1' then
                local_error_active_d <= '0';
                local_error_led_reg  <= '0';
                error_led_counter    <= 0;
            elsif local_error_active = '1' then
                if local_error_active_d = '0' then
                    local_error_led_reg <= '1';
                    error_led_counter   <= 0;
                elsif error_led_counter = C_ERROR_LED_TOGGLE_CLKS - 1 then
                    local_error_led_reg <= not local_error_led_reg;
                    error_led_counter   <= 0;
                else
                    error_led_counter <= error_led_counter + 1;
                end if;

                local_error_active_d <= local_error_active;
            else
                local_error_led_reg  <= '0';
                error_led_counter    <= 0;
                local_error_active_d <= local_error_active;
            end if;
        end if;
    end process;

    local_error_led_o <= local_error_led_reg;
    hex5_n_o          <= C_HEX_OFF_N;
    hex4_n_o          <= hex4_digit_n when G_TEST_FORCE_SEGMENT_PATTERN_LOOP
                         else C_SEG_MINUS_N when display_negative = '1'
                         else C_HEX_OFF_N;
    hex3_n_o          <= hex3_digit_n;
    hex2_n_o          <= hex2_digit_n;
    hex1_n_o          <= hex1_digit_n;
    hex0_n_o          <= hex0_digit_n;
end architecture rtl;
