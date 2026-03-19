library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.fpga2_pkg.all;

entity uart_rx is
    generic (
        G_CLOCK_FREQ_HZ : positive := 50_000_000;
        G_BAUD_RATE     : positive := 115_200
    );
    port (
        clk        : in  std_logic;
        rst        : in  std_logic;
        rx         : in  std_logic;
        data_out   : out t_uart_byte;
        data_valid : out std_logic
    );
end entity uart_rx;

architecture rtl of uart_rx is
    constant C_BIT_TICKS      : natural := G_CLOCK_FREQ_HZ / G_BAUD_RATE;
    constant C_HALF_BIT_TICKS : natural := C_BIT_TICKS / 2;

    type t_state is (ST_IDLE, ST_START, ST_DATA, ST_STOP);

    signal rx_meta        : std_logic := '1';
    signal rx_sync        : std_logic := '1';
    signal state          : t_state := ST_IDLE;
    signal baud_count     : natural range 0 to C_BIT_TICKS - 1 := 0;
    signal bit_index      : natural range 0 to 7 := 0;
    signal shift_reg      : t_uart_byte := (others => '0');
    signal data_out_reg   : t_uart_byte := (others => '0');
    signal data_valid_reg : std_logic := '0';
begin
    assert C_BIT_TICKS >= 2
        report "uart_rx requires at least two clock ticks per UART bit."
        severity failure;

    process (clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                rx_meta        <= '1';
                rx_sync        <= '1';
                state          <= ST_IDLE;
                baud_count     <= 0;
                bit_index      <= 0;
                shift_reg      <= (others => '0');
                data_out_reg   <= (others => '0');
                data_valid_reg <= '0';
            else
                rx_meta        <= rx;
                rx_sync        <= rx_meta;
                data_valid_reg <= '0';

                case state is
                    when ST_IDLE =>
                        baud_count <= 0;
                        bit_index  <= 0;

                        -- Detect the falling edge that starts a UART word.
                        if rx_sync = '0' then
                            state <= ST_START;
                        end if;

                    when ST_START =>
                        -- Sample the middle of the start bit to reject glitches.
                        if baud_count = C_HALF_BIT_TICKS - 1 then
                            baud_count <= 0;

                            if rx_sync = '0' then
                                bit_index <= 0;
                                state     <= ST_DATA;
                            else
                                state <= ST_IDLE;
                            end if;
                        else
                            baud_count <= baud_count + 1;
                        end if;

                    when ST_DATA =>
                        if baud_count = C_BIT_TICKS - 1 then
                            baud_count           <= 0;
                            -- UART transmits LSB first.
                            shift_reg(bit_index) <= rx_sync;

                            if bit_index = 7 then
                                state <= ST_STOP;
                            else
                                bit_index <= bit_index + 1;
                            end if;
                        else
                            baud_count <= baud_count + 1;
                        end if;

                    when ST_STOP =>
                        if baud_count = C_BIT_TICKS - 1 then
                            baud_count <= 0;
                            state      <= ST_IDLE;

                            -- Only mark the byte valid when the stop bit is high.
                            if rx_sync = '1' then
                                data_out_reg   <= shift_reg;
                                data_valid_reg <= '1';
                            end if;
                        else
                            baud_count <= baud_count + 1;
                        end if;
                end case;
            end if;
        end if;
    end process;

    data_out   <= data_out_reg;
    data_valid <= data_valid_reg;
end architecture rtl;
