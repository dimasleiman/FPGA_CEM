library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package dual_fpga_system_pkg is
    constant C_SAMPLE_WIDTH       : positive := 12;
    constant C_COUNTER_WIDTH      : positive := 32;
    constant C_FRAME_BYTE_COUNT   : positive := 8;
    constant C_FRAME_HEADER       : std_logic_vector(7 downto 0) := x"A5";
    constant C_FRAME_CONTROL      : std_logic_vector(7 downto 0) := x"11";
    constant C_FRAME_FOOTER       : std_logic_vector(7 downto 0) := x"5A";
    constant C_SENSOR_MIN_CODE    : natural := 1200;
    constant C_SENSOR_NORMAL_MAX  : natural := 2500;
    constant C_SENSOR_WARNING_MAX : natural := 3200;
    constant C_SENSOR_MAX_CODE    : natural := 3600;
    constant C_SENSOR_TEST_INVALID_CODE : natural := C_SENSOR_MAX_CODE + 1;
    constant C_TEMPERATURE_MIN_C  : natural := 12;
    constant C_TEMPERATURE_MAX_C  : natural := 36;

    constant C_FLAG_WARNING_BIT   : natural := 0;
    constant C_FLAG_ERROR_BIT     : natural := 1;
    constant C_FLAG_RANGE_OK_BIT  : natural := 2;
    constant C_FLAG_SOURCE_ADC_BIT : natural := 3;

    subtype t_sample is std_logic_vector(C_SAMPLE_WIDTH - 1 downto 0);
    subtype t_uart_byte is std_logic_vector(7 downto 0);
    subtype t_sensor_state is std_logic_vector(1 downto 0);
    subtype t_comm_state is std_logic_vector(1 downto 0);
    subtype t_counter is unsigned(C_COUNTER_WIDTH - 1 downto 0);
    subtype t_sequence_delta is unsigned(7 downto 0);

    type t_uart_byte_array is array (natural range <>) of t_uart_byte;

    constant C_SENSOR_STATE_NORMAL  : t_sensor_state := "00";
    constant C_SENSOR_STATE_WARNING : t_sensor_state := "01";
    constant C_SENSOR_STATE_ERROR   : t_sensor_state := "10";
    constant C_SENSOR_STATE_INVALID : t_sensor_state := "11";

    constant C_COMM_STATE_NO_FRAME : t_comm_state := "00";
    constant C_COMM_STATE_OK       : t_comm_state := "01";
    constant C_COMM_STATE_DEGRADED : t_comm_state := "10";
    constant C_COMM_STATE_TIMEOUT  : t_comm_state := "11";

    function sample_range_ok(sample_value : t_sample) return std_logic;
    function classify_sample(
        sample_value : t_sample;
        range_ok     : std_logic
    ) return t_sensor_state;
    function sensor_state_to_flags(
        sensor_state : t_sensor_state;
        range_ok     : std_logic;
        source_is_adc : std_logic
    ) return t_uart_byte;
    function flags_to_sensor_state(flags : t_uart_byte) return t_sensor_state;
    function calc_crc8(data : t_uart_byte_array) return t_uart_byte;
    function next_sequence(sequence_value : t_uart_byte) return t_uart_byte;
    function missing_frame_count(
        expected_sequence : t_uart_byte;
        received_sequence : t_uart_byte
    ) return t_sequence_delta;
end package dual_fpga_system_pkg;

package body dual_fpga_system_pkg is
    function sample_range_ok(sample_value : t_sample) return std_logic is
        variable sample_integer : natural;
    begin
        sample_integer := to_integer(unsigned(sample_value));

        if (sample_integer >= C_SENSOR_MIN_CODE)
           and (sample_integer <= C_SENSOR_MAX_CODE) then
            return '1';
        end if;

        return '0';
    end function sample_range_ok;

    function classify_sample(
        sample_value : t_sample;
        range_ok     : std_logic
    ) return t_sensor_state is
        variable sample_integer : natural;
    begin
        if range_ok /= '1' then
            return C_SENSOR_STATE_ERROR;
        end if;

        sample_integer := to_integer(unsigned(sample_value));

        if sample_integer > C_SENSOR_WARNING_MAX then
            return C_SENSOR_STATE_ERROR;
        elsif sample_integer > C_SENSOR_NORMAL_MAX then
            return C_SENSOR_STATE_WARNING;
        end if;

        return C_SENSOR_STATE_NORMAL;
    end function classify_sample;

    function sensor_state_to_flags(
        sensor_state : t_sensor_state;
        range_ok     : std_logic;
        source_is_adc : std_logic
    ) return t_uart_byte is
        variable flags_byte : t_uart_byte := (others => '0');
    begin
        if sensor_state = C_SENSOR_STATE_WARNING then
            flags_byte(C_FLAG_WARNING_BIT) := '1';
        elsif sensor_state = C_SENSOR_STATE_ERROR then
            flags_byte(C_FLAG_ERROR_BIT) := '1';
        end if;

        flags_byte(C_FLAG_RANGE_OK_BIT)   := range_ok;
        flags_byte(C_FLAG_SOURCE_ADC_BIT) := source_is_adc;
        return flags_byte;
    end function sensor_state_to_flags;

    function flags_to_sensor_state(flags : t_uart_byte) return t_sensor_state is
    begin
        if flags(C_FLAG_ERROR_BIT) = '1' then
            return C_SENSOR_STATE_ERROR;
        elsif flags(C_FLAG_WARNING_BIT) = '1' then
            return C_SENSOR_STATE_WARNING;
        end if;

        return C_SENSOR_STATE_NORMAL;
    end function flags_to_sensor_state;

    function calc_crc8(data : t_uart_byte_array) return t_uart_byte is
        variable crc_value : unsigned(7 downto 0) := (others => '0');
        variable byte_value : unsigned(7 downto 0);
    begin
        for byte_index in data'range loop
            byte_value := unsigned(data(byte_index));
            crc_value  := crc_value xor byte_value;

            for bit_index in 0 to 7 loop
                if crc_value(7) = '1' then
                    crc_value := shift_left(crc_value, 1) xor to_unsigned(16#07#, 8);
                else
                    crc_value := shift_left(crc_value, 1);
                end if;
            end loop;
        end loop;

        return std_logic_vector(crc_value);
    end function calc_crc8;

    function next_sequence(sequence_value : t_uart_byte) return t_uart_byte is
    begin
        return std_logic_vector(unsigned(sequence_value) + 1);
    end function next_sequence;

    function missing_frame_count(
        expected_sequence : t_uart_byte;
        received_sequence : t_uart_byte
    ) return t_sequence_delta is
        variable expected_value : integer;
        variable received_value : integer;
        variable gap_value      : integer;
    begin
        expected_value := to_integer(unsigned(expected_sequence));
        received_value := to_integer(unsigned(received_sequence));
        gap_value      := received_value - expected_value;

        if gap_value < 0 then
            gap_value := gap_value + 256;
        end if;

        return to_unsigned(gap_value, 8);
    end function missing_frame_count;
end package body dual_fpga_system_pkg;
