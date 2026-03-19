library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity de10_lite_fpga2_wrapper is
    generic (
        G_CLOCK_FREQ_HZ       : positive  := 50_000_000;
        G_BAUD_RATE           : positive  := 115_200;
        G_FRAME_TIMEOUT_CLKS  : positive  := 25_000_000;
        G_FAST_SIMULATION_VGA : boolean   := false;
        G_RESET_ACTIVE_LEVEL  : std_logic := '0'
    );
    port (
        -- To be mapped in Quartus to the DE10-Lite 50 MHz clock source.
        clock_50_i     : in  std_logic;
        -- To be mapped in Quartus to a chosen DE10-Lite button or switch.
        reset_source_i : in  std_logic;
        -- To be mapped in Quartus to the chosen board-to-board UART input pin.
        uart_rx_i      : in  std_logic;
        -- To be mapped in Quartus to any four DE10-Lite user LEDs.
        leds_o         : out std_logic_vector(3 downto 0);
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
            G_FAST_SIMULATION_VGA => G_FAST_SIMULATION_VGA
        )
        port map (
            clk         => clock_50_i,
            rst         => core_rst,
            uart_rx_i   => uart_rx_i,
            leds_o      => leds_o,
            vga_hsync_o => vga_hsync_o,
            vga_vsync_o => vga_vsync_o,
            vga_r_o     => vga_r_o,
            vga_g_o     => vga_g_o,
            vga_b_o     => vga_b_o
        );
end architecture rtl;
