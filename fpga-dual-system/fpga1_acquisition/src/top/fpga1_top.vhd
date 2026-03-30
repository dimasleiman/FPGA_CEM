library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.dual_fpga_system_pkg.all;

entity fpga1_top is
    generic (
        G_CLOCK_FREQ_HZ : positive := 50_000_000;
        G_BAUD_RATE     : positive := 115_200
    );
    port (
        clk       : in  std_logic;
        rst       : in  std_logic;
        start_i   : in  std_logic;
        ledr_o    : out std_logic_vector(9 downto 0);
        hex5_n_o  : out std_logic_vector(6 downto 0);
        hex4_n_o  : out std_logic_vector(6 downto 0);
        hex3_n_o  : out std_logic_vector(6 downto 0);
        hex2_n_o  : out std_logic_vector(6 downto 0);
        hex1_n_o  : out std_logic_vector(6 downto 0);
        hex0_n_o  : out std_logic_vector(6 downto 0);
        uart_tx_o : out std_logic
    );
end entity fpga1_top;

architecture rtl of fpga1_top is
    constant C_BYTE_GAP_CLKS : natural := G_CLOCK_FREQ_HZ / G_BAUD_RATE;
    constant C_COUNTER_MAX   : t_counter := (others => '1');

    type t_state is (ST_IDLE, ST_WAIT_GAP, ST_START_TX, ST_WAIT_TX_BUSY, ST_WAIT_TX_DONE);

    signal state            : t_state := ST_IDLE;
    signal counter_reg      : t_counter := (others => '0');
    signal byte_gap_counter : natural range 0 to C_BYTE_GAP_CLKS - 1 := 0;
    signal uart_data        : t_uart_byte := (others => '0');
    signal uart_start       : std_logic := '0';
    signal uart_busy        : std_logic := '0';
begin
    assert C_BYTE_GAP_CLKS > 0
        report "fpga1_top requires G_CLOCK_FREQ_HZ / G_BAUD_RATE to be at least 1."
        severity failure;

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
    begin
        if rising_edge(clk) then
            if rst = '1' then
                state            <= ST_IDLE;
                counter_reg      <= (others => '0');
                byte_gap_counter <= 0;
                uart_data        <= (others => '0');
                uart_start       <= '0';
            else
                uart_start <= '0';

                case state is
                    when ST_IDLE =>
                        counter_reg      <= (others => '0');
                        byte_gap_counter <= 0;

                        if start_i = '1' then
                            state <= ST_WAIT_GAP;
                        end if;

                    when ST_WAIT_GAP =>
                        if byte_gap_counter = C_BYTE_GAP_CLKS - 1 then
                            byte_gap_counter <= 0;
                            state            <= ST_START_TX;
                        else
                            byte_gap_counter <= byte_gap_counter + 1;
                        end if;

                    when ST_START_TX =>
                        uart_data  <= std_logic_vector(counter_reg);
                        uart_start <= '1';
                        state      <= ST_WAIT_TX_BUSY;

                    when ST_WAIT_TX_BUSY =>
                        if uart_busy = '1' then
                            state <= ST_WAIT_TX_DONE;
                        end if;

                    when ST_WAIT_TX_DONE =>
                        if uart_busy = '0' then
                            if counter_reg = C_COUNTER_MAX then
                                state <= ST_IDLE;
                            else
                                counter_reg      <= next_counter_value(counter_reg);
                                byte_gap_counter <= 0;
                                state            <= ST_WAIT_GAP;
                            end if;
                        end if;
                end case;
            end if;
        end if;
    end process;

    ledr_o(7 downto 0) <= std_logic_vector(counter_reg);
    ledr_o(8)          <= '1' when state /= ST_IDLE else '0';
    ledr_o(9)          <= uart_busy;
    hex5_n_o <= C_HEX_OFF_N;
    hex4_n_o <= C_HEX_OFF_N;
    hex3_n_o <= C_HEX_OFF_N;
    hex2_n_o <= C_HEX_OFF_N;
    hex1_n_o <= C_HEX_OFF_N;
    hex0_n_o <= C_HEX_OFF_N;
end architecture rtl;
