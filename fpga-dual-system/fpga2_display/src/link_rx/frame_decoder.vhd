library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.dual_fpga_system_pkg.all;

entity frame_decoder is
    port (
        clk                  : in  std_logic;
        rst                  : in  std_logic;
        data_in              : in  t_uart_byte;
        data_valid           : in  std_logic;
        sequence_value       : out t_uart_byte;
        measured_value       : out t_sample;
        tx_sensor_state      : out t_sensor_state;
        tx_range_ok          : out std_logic;
        frame_activity_pulse : out std_logic;
        frame_valid_pulse    : out std_logic;
        frame_corrupt_pulse  : out std_logic;
        header_error_pulse   : out std_logic;
        footer_error_pulse   : out std_logic;
        crc_error_pulse      : out std_logic
    );
end entity frame_decoder;

architecture rtl of frame_decoder is
    type t_state is (
        ST_WAIT_HEADER,
        ST_CONTROL,
        ST_SEQUENCE,
        ST_SAMPLE_MSB,
        ST_SAMPLE_LSB,
        ST_FLAGS,
        ST_CRC,
        ST_FOOTER
    );

    signal state               : t_state := ST_WAIT_HEADER;
    signal control_reg         : t_uart_byte := (others => '0');
    signal sequence_reg        : t_uart_byte := (others => '0');
    signal sample_msb_reg      : t_uart_byte := (others => '0');
    signal sample_lsb_reg      : t_uart_byte := (others => '0');
    signal flags_reg           : t_uart_byte := (others => '0');
    signal crc_reg             : t_uart_byte := (others => '0');
    signal measured_value_reg  : t_sample := (others => '0');
    signal tx_sensor_state_reg : t_sensor_state := C_SENSOR_STATE_INVALID;
    signal tx_range_ok_reg     : std_logic := '0';
    signal frame_activity_reg  : std_logic := '0';
    signal frame_valid_reg     : std_logic := '0';
    signal frame_corrupt_reg   : std_logic := '0';
    signal header_error_reg    : std_logic := '0';
    signal footer_error_reg    : std_logic := '0';
    signal crc_error_reg       : std_logic := '0';
begin
    process (clk)
        variable assembled_sample : t_sample;
        variable crc_input        : t_uart_byte_array(0 to 4);
        variable crc_ok           : boolean;
        variable format_ok        : boolean;
    begin
        if rising_edge(clk) then
            if rst = '1' then
                state               <= ST_WAIT_HEADER;
                control_reg         <= (others => '0');
                sequence_reg        <= (others => '0');
                sample_msb_reg      <= (others => '0');
                sample_lsb_reg      <= (others => '0');
                flags_reg           <= (others => '0');
                crc_reg             <= (others => '0');
                measured_value_reg  <= (others => '0');
                tx_sensor_state_reg <= C_SENSOR_STATE_INVALID;
                tx_range_ok_reg     <= '0';
                frame_activity_reg  <= '0';
                frame_valid_reg     <= '0';
                frame_corrupt_reg   <= '0';
                header_error_reg    <= '0';
                footer_error_reg    <= '0';
                crc_error_reg       <= '0';
            else
                frame_activity_reg <= '0';
                frame_valid_reg    <= '0';
                frame_corrupt_reg  <= '0';
                header_error_reg   <= '0';
                footer_error_reg   <= '0';
                crc_error_reg      <= '0';

                if data_valid = '1' then
                    case state is
                        when ST_WAIT_HEADER =>
                            if data_in = C_FRAME_HEADER then
                                state <= ST_CONTROL;
                            else
                                header_error_reg <= '1';
                            end if;

                        when ST_CONTROL =>
                            control_reg <= data_in;
                            state       <= ST_SEQUENCE;

                        when ST_SEQUENCE =>
                            sequence_reg <= data_in;
                            state        <= ST_SAMPLE_MSB;

                        when ST_SAMPLE_MSB =>
                            sample_msb_reg <= data_in;
                            state          <= ST_SAMPLE_LSB;

                        when ST_SAMPLE_LSB =>
                            sample_lsb_reg <= data_in;
                            state          <= ST_FLAGS;

                        when ST_FLAGS =>
                            flags_reg <= data_in;
                            state     <= ST_CRC;

                        when ST_CRC =>
                            crc_reg <= data_in;
                            state     <= ST_FOOTER;

                        when ST_FOOTER =>
                            crc_input(0) := control_reg;
                            crc_input(1) := sequence_reg;
                            crc_input(2) := sample_msb_reg;
                            crc_input(3) := sample_lsb_reg;
                            crc_input(4) := flags_reg;
                            crc_ok := calc_crc8(crc_input) = crc_reg;
                            format_ok := (control_reg = C_FRAME_CONTROL)
                                         and (sample_msb_reg(7 downto 4) = "0000")
                                         and (flags_reg(7 downto 4) = "0000");

                            frame_activity_reg <= '1';

                            if data_in /= C_FRAME_FOOTER then
                                footer_error_reg  <= '1';
                                frame_corrupt_reg <= '1';
                            elsif not crc_ok then
                                crc_error_reg     <= '1';
                                frame_corrupt_reg <= '1';
                            elsif not format_ok then
                                frame_corrupt_reg <= '1';
                            else
                                assembled_sample := sample_msb_reg(3 downto 0) & sample_lsb_reg;
                                measured_value_reg <= assembled_sample;
                                tx_sensor_state_reg <= flags_to_sensor_state(flags_reg);
                                tx_range_ok_reg     <= flags_reg(C_FLAG_RANGE_OK_BIT);
                                frame_valid_reg     <= '1';
                            end if;

                            state <= ST_WAIT_HEADER;
                    end case;
                end if;
            end if;
        end if;
    end process;

    sequence_value       <= sequence_reg;
    measured_value       <= measured_value_reg;
    tx_sensor_state      <= tx_sensor_state_reg;
    tx_range_ok          <= tx_range_ok_reg;
    frame_activity_pulse <= frame_activity_reg;
    frame_valid_pulse    <= frame_valid_reg;
    frame_corrupt_pulse  <= frame_corrupt_reg;
    header_error_pulse   <= header_error_reg;
    footer_error_pulse   <= footer_error_reg;
    crc_error_pulse      <= crc_error_reg;
end architecture rtl;
