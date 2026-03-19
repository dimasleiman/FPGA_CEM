library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.fpga2_pkg.all;

entity frame_decoder is
    port (
        clk            : in  std_logic;
        rst            : in  std_logic;
        data_in        : in  t_uart_byte;
        data_valid     : in  std_logic;
        measured_value : out t_sample;
        warning_flag   : out std_logic;
        error_flag     : out std_logic;
        frame_valid    : out std_logic
    );
end entity frame_decoder;

architecture rtl of frame_decoder is
    type t_state is (
        ST_WAIT_HEADER,
        ST_SAMPLE_MSB,
        ST_SAMPLE_LSB,
        ST_FLAGS,
        ST_FOOTER
    );

    signal state              : t_state := ST_WAIT_HEADER;
    signal sample_msb_reg     : t_uart_byte := (others => '0');
    signal sample_lsb_reg     : t_uart_byte := (others => '0');
    signal flags_reg          : t_uart_byte := (others => '0');
    signal measured_value_reg : t_sample := (others => '0');
    signal warning_reg        : std_logic := '0';
    signal error_reg          : std_logic := '0';
    signal frame_valid_reg    : std_logic := '0';
begin
    process (clk)
        variable assembled_sample : t_sample;
    begin
        if rising_edge(clk) then
            if rst = '1' then
                state              <= ST_WAIT_HEADER;
                sample_msb_reg     <= (others => '0');
                sample_lsb_reg     <= (others => '0');
                flags_reg          <= (others => '0');
                measured_value_reg <= (others => '0');
                warning_reg        <= '0';
                error_reg          <= '0';
                frame_valid_reg    <= '0';
            else
                frame_valid_reg <= '0';

                if data_valid = '1' then
                    case state is
                        when ST_WAIT_HEADER =>
                            if data_in = C_FRAME_HEADER then
                                state <= ST_SAMPLE_MSB;
                            end if;

                        when ST_SAMPLE_MSB =>
                            sample_msb_reg <= data_in;
                            state          <= ST_SAMPLE_LSB;

                        when ST_SAMPLE_LSB =>
                            sample_lsb_reg <= data_in;
                            state          <= ST_FLAGS;

                        when ST_FLAGS =>
                            flags_reg <= data_in;
                            state     <= ST_FOOTER;

                        when ST_FOOTER =>
                            -- Accept the frame only if the footer matches and
                            -- the reserved bits are still zero. Payload bytes
                            -- are allowed to contain the header value x"AA".
                            if (data_in = C_FRAME_FOOTER)
                               and (sample_lsb_reg(7 downto 4) = "0000")
                               and (flags_reg(7 downto 2) = "000000") then
                                assembled_sample := sample_msb_reg & sample_lsb_reg(3 downto 0);
                                measured_value_reg <= assembled_sample;
                                warning_reg        <= flags_reg(0);
                                error_reg          <= flags_reg(1);
                                frame_valid_reg    <= '1';
                                state              <= ST_WAIT_HEADER;
                            else
                                state <= ST_WAIT_HEADER;
                            end if;
                    end case;
                end if;
            end if;
        end if;
    end process;

    measured_value <= measured_value_reg;
    warning_flag   <= warning_reg;
    error_flag     <= error_reg;
    frame_valid    <= frame_valid_reg;
end architecture rtl;
