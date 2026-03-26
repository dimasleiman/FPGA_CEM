library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.dual_fpga_system_pkg.all;
use work.fpga1_pkg.all;

entity max10_adc_frontend is
    generic (
        G_ADC_CHANNEL_INDEX  : natural := C_DEFAULT_ADC_CHANNEL_INDEX;
        G_OUTPUT_PERIOD_CLKS : positive := C_DEFAULT_ADC_OUTPUT_PERIOD_CLKS
    );
    port (
        clk            : in  std_logic;
        rst            : in  std_logic;
        sample_value_o : out t_sample;
        sample_valid_o : out std_logic
    );
end entity max10_adc_frontend;

architecture rtl of max10_adc_frontend is
    component altera_up_avalon_adv_adc is
        generic (
            T_SCLK                : natural := 4;
            NUM_CH                : natural := 5;
            BOARD                 : string  := "DE10-Lite";
            BOARD_REV             : string  := "Autodetect";
            MAX10_PLL_MULTIPLY_BY : natural := 1;
            MAX10_PLL_DIVIDE_BY   : natural := 5
        );
        port (
            clock    : in  std_logic;
            reset    : in  std_logic;
            go       : in  std_logic;
            sclk     : out std_logic;
            cs_n     : out std_logic;
            din      : out std_logic;
            dout     : in  std_logic;
            done     : out std_logic;
            reading0 : out std_logic_vector(11 downto 0);
            reading1 : out std_logic_vector(11 downto 0);
            reading2 : out std_logic_vector(11 downto 0);
            reading3 : out std_logic_vector(11 downto 0);
            reading4 : out std_logic_vector(11 downto 0);
            reading5 : out std_logic_vector(11 downto 0);
            reading6 : out std_logic_vector(11 downto 0);
            reading7 : out std_logic_vector(11 downto 0)
        );
    end component;

    signal adc_go               : std_logic := '0';
    signal adc_done             : std_logic := '0';
    signal adc_reading0         : t_sample := (others => '0');
    signal adc_reading1         : t_sample := (others => '0');
    signal adc_reading2         : t_sample := (others => '0');
    signal adc_reading3         : t_sample := (others => '0');
    signal adc_reading4         : t_sample := (others => '0');
    signal adc_reading5         : t_sample := (others => '0');
    signal selected_sample      : t_sample := (others => '0');
    signal latest_sample        : t_sample := (others => '0');
    signal sample_seen          : std_logic := '0';
    signal output_counter       : natural range 0 to G_OUTPUT_PERIOD_CLKS - 1 := 0;
begin
    assert G_ADC_CHANNEL_INDEX <= 5
        report "max10_adc_frontend requires a DE10-Lite analog input channel index in the range 0 to 5."
        severity failure;

    process (all)
    begin
        case G_ADC_CHANNEL_INDEX is
            when 0 =>
                selected_sample <= adc_reading0;
            when 1 =>
                selected_sample <= adc_reading1;
            when 2 =>
                selected_sample <= adc_reading2;
            when 3 =>
                selected_sample <= adc_reading3;
            when 4 =>
                selected_sample <= adc_reading4;
            when others =>
                selected_sample <= adc_reading5;
        end case;
    end process;

    u_adc_reader : altera_up_avalon_adv_adc
        generic map (
            T_SCLK                => 5,
            NUM_CH                => 5,
            BOARD                 => "DE10-Lite",
            BOARD_REV             => "Autodetect",
            MAX10_PLL_MULTIPLY_BY => 1,
            MAX10_PLL_DIVIDE_BY   => 5
        )
        port map (
            clock    => clk,
            reset    => rst,
            go       => adc_go,
            sclk     => open,
            cs_n     => open,
            din      => open,
            dout     => '0',
            done     => adc_done,
            reading0 => adc_reading0,
            reading1 => adc_reading1,
            reading2 => adc_reading2,
            reading3 => adc_reading3,
            reading4 => adc_reading4,
            reading5 => adc_reading5,
            reading6 => open,
            reading7 => open
        );

    process (clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                adc_go         <= '0';
                latest_sample  <= (others => '0');
                sample_seen    <= '0';
                output_counter <= 0;
                sample_value_o <= (others => '0');
                sample_valid_o <= '0';
            else
                sample_valid_o <= '0';

                if adc_done = '1' then
                    adc_go        <= '0';
                    latest_sample <= selected_sample;
                    sample_seen   <= '1';
                else
                    adc_go <= '1';
                end if;

                if output_counter = G_OUTPUT_PERIOD_CLKS - 1 then
                    output_counter <= 0;

                    if sample_seen = '1' then
                        sample_value_o <= latest_sample;
                        sample_valid_o <= '1';
                    end if;
                else
                    output_counter <= output_counter + 1;
                end if;
            end if;
        end if;
    end process;
end architecture rtl;
