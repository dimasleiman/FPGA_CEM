library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.dual_fpga_system_pkg.all;

entity frame_builder is
    port (
        clk           : in  std_logic;
        rst           : in  std_logic;
        load_frame    : in  std_logic;
        sample_value  : in  t_sample;
        sensor_state  : in  t_sensor_state;
        range_ok      : in  std_logic;
        source_is_adc : in  std_logic;
        byte_index    : in  unsigned(2 downto 0);
        byte_out      : out t_uart_byte;
        frame_ready   : out std_logic
    );
end entity frame_builder;

architecture rtl of frame_builder is
    signal frame_bytes     : t_uart_byte_array(0 to C_FRAME_BYTE_COUNT - 1) := (others => (others => '0'));
    signal frame_ready_reg : std_logic := '0';
    signal sequence_reg    : t_uart_byte := (others => '0');
begin
    process (clk)
        variable crc_input  : t_uart_byte_array(0 to 4);
        variable flags_byte : t_uart_byte;
    begin
        if rising_edge(clk) then
            if rst = '1' then
                frame_bytes     <= (others => (others => '0'));
                frame_ready_reg <= '0';
                sequence_reg    <= (others => '0');
            else
                frame_ready_reg <= '0';

                if load_frame = '1' then
                    -- Build a fixed 8-byte frame:
                    -- header, control, sequence, 16-bit payload, flags, CRC8, footer.
                    flags_byte := sensor_state_to_flags(sensor_state, range_ok, source_is_adc);
                    crc_input(0) := C_FRAME_CONTROL;
                    crc_input(1) := sequence_reg;
                    crc_input(2) := "0000" & sample_value(C_SAMPLE_WIDTH - 1 downto 8);
                    crc_input(3) := sample_value(7 downto 0);
                    crc_input(4) := flags_byte;

                    frame_bytes(0) <= C_FRAME_HEADER;
                    frame_bytes(1) <= C_FRAME_CONTROL;
                    frame_bytes(2) <= sequence_reg;
                    frame_bytes(3) <= crc_input(2);
                    frame_bytes(4) <= crc_input(3);
                    frame_bytes(5) <= flags_byte;
                    frame_bytes(6) <= calc_crc8(crc_input);
                    frame_bytes(7) <= C_FRAME_FOOTER;
                    frame_ready_reg <= '1';
                    sequence_reg    <= next_sequence(sequence_reg);
                end if;
            end if;
        end if;
    end process;

    process (frame_ready_reg, frame_bytes, byte_index)
    begin
        byte_out <= (others => '0');

        -- The top-level FSM selects which stored byte to send next.
        if to_integer(byte_index) < C_FRAME_BYTE_COUNT then
            byte_out <= frame_bytes(to_integer(byte_index));
        end if;
    end process;

    frame_ready <= frame_ready_reg;
end architecture rtl;
