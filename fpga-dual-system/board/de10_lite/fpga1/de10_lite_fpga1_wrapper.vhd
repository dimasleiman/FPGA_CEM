library ieee;
use ieee.std_logic_1164.all;

entity de10_lite_fpga1_wrapper is
    generic (
        G_CLOCK_FREQ_HZ          : positive := 50_000_000;
        G_BAUD_RATE              : positive := 115_200;
        G_RESET_ACTIVE_LEVEL     : std_logic := '0';
        G_START_BUTTON_ACTIVE_LEVEL : std_logic := '0'
    );
    port (
        clock_50_i     : in  std_logic;
        reset_source_i : in  std_logic;
        start_button_i : in  std_logic;
        ledr_o         : out std_logic_vector(9 downto 0);
        hex5_n_o       : out std_logic_vector(6 downto 0);
        hex4_n_o       : out std_logic_vector(6 downto 0);
        hex3_n_o       : out std_logic_vector(6 downto 0);
        hex2_n_o       : out std_logic_vector(6 downto 0);
        hex1_n_o       : out std_logic_vector(6 downto 0);
        hex0_n_o       : out std_logic_vector(6 downto 0);
        uart_tx_o      : out std_logic
    );
end entity de10_lite_fpga1_wrapper;

architecture rtl of de10_lite_fpga1_wrapper is
    signal core_rst              : std_logic := '1';
    signal start_button_meta     : std_logic := '1';
    signal start_button_sync     : std_logic := '1';
    signal start_button_prev     : std_logic := '0';
    signal start_button_pressed  : std_logic := '0';
    signal start_pulse           : std_logic := '0';
begin
    u_reset_sync : entity work.reset_sync
        generic map (
            G_STAGES             => 2,
            G_INPUT_ACTIVE_LEVEL => G_RESET_ACTIVE_LEVEL
        )
        port map (
            clk       => clock_50_i,
            reset_in  => reset_source_i,
            reset_out => core_rst
        );

    start_button_pressed <= '1' when start_button_sync = G_START_BUTTON_ACTIVE_LEVEL else '0';

    process (clock_50_i)
    begin
        if rising_edge(clock_50_i) then
            if core_rst = '1' then
                start_button_meta <= not G_START_BUTTON_ACTIVE_LEVEL;
                start_button_sync <= not G_START_BUTTON_ACTIVE_LEVEL;
                start_button_prev <= '0';
                start_pulse       <= '0';
            else
                start_button_meta <= start_button_i;
                start_button_sync <= start_button_meta;
                start_button_prev <= start_button_pressed;
                start_pulse       <= '0';

                if start_button_pressed = '1' and start_button_prev = '0' then
                    start_pulse <= '1';
                end if;
            end if;
        end if;
    end process;

    u_core : entity work.fpga1_top
        generic map (
            G_CLOCK_FREQ_HZ => G_CLOCK_FREQ_HZ,
            G_BAUD_RATE     => G_BAUD_RATE
        )
        port map (
            clk       => clock_50_i,
            rst       => core_rst,
            start_i   => start_pulse,
            ledr_o    => ledr_o,
            hex5_n_o  => hex5_n_o,
            hex4_n_o  => hex4_n_o,
            hex3_n_o  => hex3_n_o,
            hex2_n_o  => hex2_n_o,
            hex1_n_o  => hex1_n_o,
            hex0_n_o  => hex0_n_o,
            uart_tx_o => uart_tx_o
        );
end architecture rtl;
