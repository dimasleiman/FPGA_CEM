library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.dual_fpga_system_pkg.all;
use work.fpga1_pkg.all;

entity de10_lite_fpga1_wrapper is
    generic (
        G_CLOCK_FREQ_HZ         : positive  := 50_000_000;
        G_BAUD_RATE             : positive  := 115_200;
        G_ADC_CHANNEL_INDEX     : natural   := C_DEFAULT_ADC_CHANNEL_INDEX;
        G_ADC_OUTPUT_PERIOD_CLKS : positive := C_DEFAULT_ADC_OUTPUT_PERIOD_CLKS;
        G_SOURCE_IS_ADC         : std_logic := C_REAL_SENSOR_SOURCE_IS_ADC;
        G_EMI_WINDOW_SIZE       : positive  := C_DEFAULT_EMI_WINDOW_SIZE;
        G_EMI_SPREAD_WARNING_THRESHOLD : positive := C_DEFAULT_EMI_SPREAD_WARNING_THRESHOLD_CODES;
        G_USE_TEST_SAMPLE_SOURCE : boolean := false;
        G_USE_FAKE_SENSOR_GENERATOR : boolean := true;
        G_TEST_SAMPLE_PERIOD_CLKS : positive := C_DEFAULT_SIM_SAMPLE_PERIOD_CLKS;
        G_TEST_SAMPLE_CODE      : natural := C_DEFAULT_SIM_SAMPLE_CODE;
        G_FAKE_SENSOR_UPDATE_DIVIDER : positive := 5_000_000;
        G_FAKE_SENSOR_HOLD_TICKS_PER_VALUE : positive := 20;
        G_FAKE_SENSOR_STEP_CODE : positive := C_DEFAULT_FAKE_SENSOR_STEP_CODE;
        G_FAKE_SENSOR_RANDOM_SAMPLE_MODE : boolean := true;
        G_FAKE_SENSOR_MIN_CODE : natural := C_DEFAULT_FAKE_SENSOR_MIN_CODE;
        G_FAKE_SENSOR_MAX_CODE : natural := C_DEFAULT_FAKE_SENSOR_MAX_CODE;
        G_TEST_FORCE_LEDR0_BLINK : boolean := false;
        G_TEST_FORCE_FIXED_DISPLAY : boolean := false;
        G_TEST_FIXED_DISPLAY_VALUE : natural := 1234;
        G_TEST_FORCE_LOW_DIGIT_SEQUENCE : boolean := false;
        G_TEST_FORCE_SEGMENT_PATTERN_LOOP : boolean := false;
        G_TEST_DISPLAY_SEQUENCE_STEP_CLKS : positive := 50_000_000;
        G_RESET_ACTIVE_LEVEL    : std_logic := '0'
    );
    port (
        -- To be mapped in Quartus to the DE10-Lite 50 MHz clock source.
        clock_50_i     : in  std_logic;
        -- To be mapped in Quartus to a chosen DE10-Lite reset push-button.
        reset_source_i : in  std_logic;
        -- To be mapped in Quartus to DE10-Lite LED0 for local error indication.
        local_error_led_o : out std_logic;
        -- Decimal display of the current FPGA1 temperature value on the DE10-Lite.
        hex5_n_o          : out std_logic_vector(6 downto 0);
        hex4_n_o          : out std_logic_vector(6 downto 0);
        hex3_n_o          : out std_logic_vector(6 downto 0);
        hex2_n_o          : out std_logic_vector(6 downto 0);
        hex1_n_o          : out std_logic_vector(6 downto 0);
        hex0_n_o          : out std_logic_vector(6 downto 0);
        -- Forced inactive so FPGA1 never drives the other DE10-Lite red LEDs.
        ledr1_o        : out std_logic;
        ledr2_o        : out std_logic;
        ledr3_o        : out std_logic;
        ledr4_o        : out std_logic;
        ledr5_o        : out std_logic;
        ledr6_o        : out std_logic;
        ledr7_o        : out std_logic;
        ledr8_o        : out std_logic;
        ledr9_o        : out std_logic;
        -- To be mapped in Quartus to the chosen board-to-board UART output pin.
        uart_tx_o      : out std_logic
    );
end entity de10_lite_fpga1_wrapper;

architecture rtl of de10_lite_fpga1_wrapper is
    function core_source_is_adc_value return std_logic is
    begin
        if G_USE_TEST_SAMPLE_SOURCE or G_USE_FAKE_SENSOR_GENERATOR then
            return '0';
        end if;

        return G_SOURCE_IS_ADC;
    end function core_source_is_adc_value;

    constant C_CORE_SOURCE_IS_ADC : std_logic := core_source_is_adc_value;
    signal core_rst             : std_logic := '1';
    signal core_effective_rst   : std_logic := '1';
    signal core_local_error_led : std_logic := '0';
    signal source_sample_value  : t_sample := (others => '0');
    signal source_sample_valid  : std_logic := '0';
    signal test_sample_counter  : natural range 0 to G_TEST_SAMPLE_PERIOD_CLKS - 1 := 0;
begin
    assert G_TEST_SAMPLE_CODE < (2 ** C_SAMPLE_WIDTH)
        report "de10_lite_fpga1_wrapper requires G_TEST_SAMPLE_CODE to fit within the 12-bit ADC sample width."
        severity failure;
    assert not (G_USE_TEST_SAMPLE_SOURCE and G_USE_FAKE_SENSOR_GENERATOR)
        report "de10_lite_fpga1_wrapper requires at most one synthetic sample source at a time."
        severity failure;

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

    -- Direct LED test must keep the counter running even if the board-facing
    -- reset input is held active.
    core_effective_rst <= '0' when G_TEST_FORCE_LEDR0_BLINK else core_rst;

    gen_test_sample_source : if G_USE_TEST_SAMPLE_SOURCE generate
        source_sample_value <= std_logic_vector(to_unsigned(G_TEST_SAMPLE_CODE, C_SAMPLE_WIDTH));

        process (clock_50_i)
        begin
            if rising_edge(clock_50_i) then
                if core_effective_rst = '1' then
                    test_sample_counter <= 0;
                    source_sample_valid <= '0';
                elsif test_sample_counter = G_TEST_SAMPLE_PERIOD_CLKS - 1 then
                    test_sample_counter <= 0;
                    source_sample_valid <= '1';
                else
                    test_sample_counter <= test_sample_counter + 1;
                    source_sample_valid <= '0';
                end if;
            end if;
        end process;
    end generate gen_test_sample_source;

    gen_fake_sensor_source : if G_USE_FAKE_SENSOR_GENERATOR generate
        u_fake_sensor_gen : entity work.fake_sensor_gen
            generic map (
                G_UPDATE_DIVIDER       => G_FAKE_SENSOR_UPDATE_DIVIDER,
                G_HOLD_TICKS_PER_VALUE => G_FAKE_SENSOR_HOLD_TICKS_PER_VALUE,
                G_STEP_CODE            => G_FAKE_SENSOR_STEP_CODE,
                G_RANDOM_SAMPLE_MODE   => G_FAKE_SENSOR_RANDOM_SAMPLE_MODE,
                G_MIN_CODE             => G_FAKE_SENSOR_MIN_CODE,
                G_MAX_CODE             => G_FAKE_SENSOR_MAX_CODE
            )
            port map (
                clk          => clock_50_i,
                rst          => core_effective_rst,
                sample_value => source_sample_value,
                sample_valid => source_sample_valid
            );
    end generate gen_fake_sensor_source;

    gen_real_adc_source : if (not G_USE_TEST_SAMPLE_SOURCE) and (not G_USE_FAKE_SENSOR_GENERATOR) generate
        u_adc_frontend : entity work.max10_adc_frontend
            generic map (
                G_ADC_CHANNEL_INDEX  => G_ADC_CHANNEL_INDEX,
                G_OUTPUT_PERIOD_CLKS => G_ADC_OUTPUT_PERIOD_CLKS
            )
            port map (
                clk            => clock_50_i,
                rst            => core_effective_rst,
                sample_value_o => source_sample_value,
                sample_valid_o => source_sample_valid
            );
    end generate gen_real_adc_source;

    u_core : entity work.fpga1_top
        generic map (
            G_CLOCK_FREQ_HZ         => G_CLOCK_FREQ_HZ,
            G_BAUD_RATE             => G_BAUD_RATE,
            G_SOURCE_IS_ADC         => C_CORE_SOURCE_IS_ADC,
            G_EMI_WINDOW_SIZE       => G_EMI_WINDOW_SIZE,
            G_EMI_SPREAD_WARNING_THRESHOLD => G_EMI_SPREAD_WARNING_THRESHOLD,
            G_TEST_FORCE_LEDR0_BLINK => G_TEST_FORCE_LEDR0_BLINK,
            G_TEST_FORCE_FIXED_DISPLAY => G_TEST_FORCE_FIXED_DISPLAY,
            G_TEST_FIXED_DISPLAY_VALUE => G_TEST_FIXED_DISPLAY_VALUE,
            G_TEST_FORCE_LOW_DIGIT_SEQUENCE => G_TEST_FORCE_LOW_DIGIT_SEQUENCE,
            G_TEST_FORCE_SEGMENT_PATTERN_LOOP => G_TEST_FORCE_SEGMENT_PATTERN_LOOP,
            G_TEST_DISPLAY_SEQUENCE_STEP_CLKS => G_TEST_DISPLAY_SEQUENCE_STEP_CLKS
        )
        port map (
            clk               => clock_50_i,
            rst               => core_effective_rst,
            sample_value_i    => source_sample_value,
            sample_valid_i    => source_sample_valid,
            local_error_led_o => core_local_error_led,
            hex5_n_o          => hex5_n_o,
            hex4_n_o          => hex4_n_o,
            hex3_n_o          => hex3_n_o,
            hex2_n_o          => hex2_n_o,
            hex1_n_o          => hex1_n_o,
            hex0_n_o          => hex0_n_o,
            uart_tx_o         => uart_tx_o
        );

    local_error_led_o <= core_local_error_led;
    ledr1_o           <= '0';
    ledr2_o           <= '0';
    ledr3_o           <= '0';
    ledr4_o           <= '0';
    ledr5_o           <= '0';
    ledr6_o           <= '0';
    ledr7_o           <= '0';
    ledr8_o           <= '0';
    ledr9_o           <= '0';
end architecture rtl;
