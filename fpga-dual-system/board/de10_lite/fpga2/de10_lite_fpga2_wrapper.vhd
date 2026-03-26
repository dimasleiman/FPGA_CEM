library ieee;
use ieee.std_logic_1164.all;

entity de10_lite_fpga2_wrapper is
    generic (
        G_CLOCK_FREQ_HZ       : positive  := 50_000_000;
        G_BAUD_RATE           : positive  := 115_200;
        G_FRAME_TIMEOUT_CLKS  : positive  := 25_000_000;
        G_FAST_SIMULATION_VGA : boolean   := false;
        G_USE_INTERNAL_UART_TEST_SOURCE : boolean := false;
        G_INTERNAL_UART_FRAME_GAP_CLKS : positive := 5_000_000;
        G_INTERNAL_UART_SAMPLE_HOLD_FRAMES : positive := 20;
        G_INTERNAL_UART_SAMPLE_STEP : positive := 100;
        G_INTERNAL_UART_CORRUPT_FRAME_TEST : boolean := false;
        G_INTERNAL_UART_CORRUPT_FRAME_PERIOD : positive := 8;
        G_RESET_ACTIVE_LEVEL  : std_logic := '0'
    );
    port (
        -- To be mapped in Quartus to the DE10-Lite 50 MHz clock source.
        clock_50_i     : in  std_logic;
        -- To be mapped in Quartus to a chosen DE10-Lite button or switch.
        reset_source_i : in  std_logic;
        -- To be mapped in Quartus to the chosen board-to-board UART input pin.
        uart_rx_i      : in  std_logic;
        -- Force all DE10-Lite red LEDs inactive on FPGA2.
        ledr0_o        : out std_logic;
        ledr1_o        : out std_logic;
        ledr2_o        : out std_logic;
        ledr3_o        : out std_logic;
        ledr4_o        : out std_logic;
        ledr5_o        : out std_logic;
        ledr6_o        : out std_logic;
        ledr7_o        : out std_logic;
        ledr8_o        : out std_logic;
        ledr9_o        : out std_logic;
        -- To be mapped in Quartus to the six active-low DE10-Lite seven-segment displays.
        hex5_n_o       : out std_logic_vector(6 downto 0);
        hex4_n_o       : out std_logic_vector(6 downto 0);
        hex3_n_o       : out std_logic_vector(6 downto 0);
        hex2_n_o       : out std_logic_vector(6 downto 0);
        hex1_n_o       : out std_logic_vector(6 downto 0);
        hex0_n_o       : out std_logic_vector(6 downto 0);
        -- To be mapped in Quartus to the DE10-Lite VGA connector.
        vga_hsync_o    : out std_logic;
        vga_vsync_o    : out std_logic;
        vga_r_o        : out std_logic_vector(3 downto 0);
        vga_g_o        : out std_logic_vector(3 downto 0);
        vga_b_o        : out std_logic_vector(3 downto 0)
    );
end entity de10_lite_fpga2_wrapper;

architecture rtl of de10_lite_fpga2_wrapper is
    signal core_rst : std_logic := '1';
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

    u_core : entity work.fpga2_top
        generic map (
            G_CLOCK_FREQ_HZ       => G_CLOCK_FREQ_HZ,
            G_BAUD_RATE           => G_BAUD_RATE,
            G_FRAME_TIMEOUT_CLKS  => G_FRAME_TIMEOUT_CLKS,
            G_FAST_SIMULATION_VGA => G_FAST_SIMULATION_VGA,
            G_USE_INTERNAL_UART_TEST_SOURCE => G_USE_INTERNAL_UART_TEST_SOURCE,
            G_INTERNAL_UART_FRAME_GAP_CLKS => G_INTERNAL_UART_FRAME_GAP_CLKS,
            G_INTERNAL_UART_SAMPLE_HOLD_FRAMES => G_INTERNAL_UART_SAMPLE_HOLD_FRAMES,
            G_INTERNAL_UART_SAMPLE_STEP => G_INTERNAL_UART_SAMPLE_STEP,
            G_INTERNAL_UART_CORRUPT_FRAME_TEST => G_INTERNAL_UART_CORRUPT_FRAME_TEST,
            G_INTERNAL_UART_CORRUPT_FRAME_PERIOD => G_INTERNAL_UART_CORRUPT_FRAME_PERIOD
        )
        port map (
            clk         => clock_50_i,
            rst         => core_rst,
            uart_rx_i   => uart_rx_i,
            leds_o      => open,
            hex5_n_o    => hex5_n_o,
            hex4_n_o    => hex4_n_o,
            hex3_n_o    => hex3_n_o,
            hex2_n_o    => hex2_n_o,
            hex1_n_o    => hex1_n_o,
            hex0_n_o    => hex0_n_o,
            vga_hsync_o => vga_hsync_o,
            vga_vsync_o => vga_vsync_o,
            vga_r_o     => vga_r_o,
            vga_g_o     => vga_g_o,
            vga_b_o     => vga_b_o
        );

    ledr0_o <= '0';
    ledr1_o <= '0';
    ledr2_o <= '0';
    ledr3_o <= '0';
    ledr4_o <= '0';
    ledr5_o <= '0';
    ledr6_o <= '0';
    ledr7_o <= '0';
    ledr8_o <= '0';
    ledr9_o <= '0';
end architecture rtl;
