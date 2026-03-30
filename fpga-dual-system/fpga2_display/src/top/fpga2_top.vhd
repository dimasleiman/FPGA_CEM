library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.dual_fpga_system_pkg.all;

entity fpga2_top is
    generic (
        G_CLOCK_FREQ_HZ : positive := 50_000_000;
        G_BAUD_RATE     : positive := 115_200
    );
    port (
        clk       : in  std_logic;
        rst       : in  std_logic;
        uart_rx_i : in  std_logic;
        ledr_o    : out std_logic_vector(9 downto 0);
        hex5_n_o  : out std_logic_vector(6 downto 0);
        hex4_n_o  : out std_logic_vector(6 downto 0);
        hex3_n_o  : out std_logic_vector(6 downto 0);
        hex2_n_o  : out std_logic_vector(6 downto 0);
        hex1_n_o  : out std_logic_vector(6 downto 0);
        hex0_n_o  : out std_logic_vector(6 downto 0)
    );
end entity fpga2_top;

architecture rtl of fpga2_top is
    signal rx_data          : t_uart_byte := (others => '0');
    signal rx_valid         : std_logic := '0';
    signal last_received    : t_uart_byte := (others => '0');
    signal expected_counter : t_counter := (others => '0');
    signal link_started     : std_logic := '0';
    signal mismatch_latched : std_logic := '0';
    signal activity_led     : std_logic := '0';
    signal ledr_reg         : std_logic_vector(9 downto 0) := (others => '0');
begin
    u_uart_rx : entity work.uart_rx
        generic map (
            G_CLOCK_FREQ_HZ => G_CLOCK_FREQ_HZ,
            G_BAUD_RATE     => G_BAUD_RATE
        )
        port map (
            clk        => clk,
            rst        => rst,
            rx         => uart_rx_i,
            data_out   => rx_data,
            data_valid => rx_valid
        );

    process (clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                last_received    <= (others => '0');
                expected_counter <= (others => '0');
                link_started     <= '0';
                mismatch_latched <= '0';
                activity_led     <= '0';
                ledr_reg         <= (others => '0');
            else
                if rx_valid = '1' then
                    last_received <= rx_data;
                    activity_led  <= not activity_led;

                    if link_started = '0' then
                        expected_counter <= unsigned(rx_data) + 1;
                        link_started     <= '1';
                    elsif unsigned(rx_data) = expected_counter then
                        expected_counter <= next_counter_value(expected_counter);
                    else
                        mismatch_latched <= '1';
                        expected_counter <= unsigned(rx_data) + 1;
                    end if;
                end if;

                ledr_reg(7 downto 0) <= last_received;
                ledr_reg(8)          <= mismatch_latched;
                ledr_reg(9)          <= activity_led;
            end if;
        end if;
    end process;

    ledr_o   <= ledr_reg;
    hex5_n_o <= C_HEX_OFF_N;
    hex4_n_o <= C_HEX_OFF_N;
    hex3_n_o <= C_HEX_OFF_N;
    hex2_n_o <= C_HEX_OFF_N;
    hex1_n_o <= C_HEX_OFF_N;
    hex0_n_o <= C_HEX_OFF_N;
end architecture rtl;
