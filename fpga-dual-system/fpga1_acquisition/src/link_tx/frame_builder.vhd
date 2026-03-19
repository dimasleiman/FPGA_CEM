library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.fpga1_pkg.all;

entity frame_builder is
    port (
        clk          : in  std_logic;
        rst          : in  std_logic;
        load_frame   : in  std_logic;
        sample_value : in  t_sample;
        warning_flag : in  std_logic;
        error_flag   : in  std_logic;
        byte_index   : in  unsigned(2 downto 0);
        byte_out     : out t_uart_byte;
        frame_ready  : out std_logic
    );
end entity frame_builder;

architecture rtl of frame_builder is
    signal frame_bytes     : t_frame_array := (others => (others => '0'));
    signal frame_ready_reg : std_logic := '0';
begin
    process (clk)
        variable flags_byte : t_uart_byte;
    begin
        if rising_edge(clk) then
            if rst = '1' then
                frame_bytes     <= (others => (others => '0'));
                frame_ready_reg <= '0';
            else
                frame_ready_reg <= '0';

                if load_frame = '1' then
                    -- Pack the 12-bit sample and status flags into the fixed
                    -- 5-byte UART frame used by both FPGAs.
                    flags_byte := (others => '0');
                    flags_byte(0) := warning_flag;
                    flags_byte(1) := error_flag;

                    frame_bytes(0) <= C_FRAME_HEADER;
                    frame_bytes(1) <= sample_value(C_SAMPLE_WIDTH - 1 downto 4);
                    frame_bytes(2) <= "0000" & sample_value(3 downto 0);
                    frame_bytes(3) <= flags_byte;
                    frame_bytes(4) <= C_FRAME_FOOTER;
                    frame_ready_reg <= '1';
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
