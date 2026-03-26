library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.dual_fpga_system_pkg.all;

entity fpga2_top is
    generic (
        G_CLOCK_FREQ_HZ        : positive := 50_000_000;
        G_BAUD_RATE            : positive := 115_200;
        G_FRAME_TIMEOUT_CLKS   : positive := 25_000_000;
        G_FAST_SIMULATION_VGA  : boolean  := false;
        G_USE_INTERNAL_UART_TEST_SOURCE : boolean := false;
        G_INTERNAL_UART_FRAME_GAP_CLKS : positive := 5_000_000;
        G_INTERNAL_UART_SAMPLE_HOLD_FRAMES : positive := 20;
        G_INTERNAL_UART_SAMPLE_STEP : positive := 100;
        G_INTERNAL_UART_CORRUPT_FRAME_TEST : boolean := false;
        G_INTERNAL_UART_CORRUPT_FRAME_PERIOD : positive := 8
    );
    port (
        clk         : in  std_logic;
        rst         : in  std_logic;
        uart_rx_i   : in  std_logic;
        leds_o      : out std_logic_vector(3 downto 0);
        hex5_n_o    : out std_logic_vector(6 downto 0);
        hex4_n_o    : out std_logic_vector(6 downto 0);
        hex3_n_o    : out std_logic_vector(6 downto 0);
        hex2_n_o    : out std_logic_vector(6 downto 0);
        hex1_n_o    : out std_logic_vector(6 downto 0);
        hex0_n_o    : out std_logic_vector(6 downto 0);
        vga_hsync_o : out std_logic;
        vga_vsync_o : out std_logic;
        vga_r_o     : out std_logic_vector(3 downto 0);
        vga_g_o     : out std_logic_vector(3 downto 0);
        vga_b_o     : out std_logic_vector(3 downto 0)
    );
end entity fpga2_top;

architecture rtl of fpga2_top is
    function select_positive(
        simulation_mode : boolean;
        simulation_value : positive;
        hardware_value   : positive
    ) return positive is
    begin
        if simulation_mode then
            return simulation_value;
        end if;

        return hardware_value;
    end function select_positive;

    constant C_H_ACTIVE : positive := select_positive(G_FAST_SIMULATION_VGA, 160, 640);
    constant C_H_FRONT  : positive := select_positive(G_FAST_SIMULATION_VGA, 10, 16);
    constant C_H_SYNC   : positive := select_positive(G_FAST_SIMULATION_VGA, 20, 96);
    constant C_H_BACK   : positive := select_positive(G_FAST_SIMULATION_VGA, 10, 48);
    constant C_V_ACTIVE : positive := select_positive(G_FAST_SIMULATION_VGA, 120, 480);
    constant C_V_FRONT  : positive := select_positive(G_FAST_SIMULATION_VGA, 4, 10);
    constant C_V_SYNC   : positive := select_positive(G_FAST_SIMULATION_VGA, 4, 2);
    constant C_V_BACK   : positive := select_positive(G_FAST_SIMULATION_VGA, 12, 33);
    constant C_SEG_BLANK_N : std_logic_vector(6 downto 0) := "1111111";
    -- DE10-Lite segments are active-low and indexed 0..6. Because these
    -- vectors are declared (6 downto 0), the literals are written in gfedcba
    -- order to match the corrected FPGA1 decimal decoder.
    constant C_SEG_G_N     : std_logic_vector(6 downto 0) := "0000010";
    constant C_SEG_E_N     : std_logic_vector(6 downto 0) := "0000110";
    -- Approximate lowercase 'r' with segments e and g; uppercase 'R' is not
    -- representable on a 7-segment display.
    constant C_SEG_R_N     : std_logic_vector(6 downto 0) := "0101111";
    -- Approximate lowercase 'n' with segments c, e and g.
    constant C_SEG_N_N     : std_logic_vector(6 downto 0) := "0101011";
    constant C_SEG_O_N     : std_logic_vector(6 downto 0) := "1000000";
    constant C_SEG_D_N     : std_logic_vector(6 downto 0) := "0100001";

    signal rx_byte              : t_uart_byte := (others => '0');
    signal rx_data_valid        : std_logic := '0';
    signal rx_sequence          : t_uart_byte := (others => '0');
    signal measured_value       : t_sample := (others => '0');
    signal tx_sensor_state      : t_sensor_state := C_SENSOR_STATE_INVALID;
    signal tx_range_ok          : std_logic := '0';
    signal frame_activity_pulse : std_logic := '0';
    signal frame_valid_pulse    : std_logic := '0';
    signal frame_corrupt_pulse  : std_logic := '0';
    signal current_sensor_value : t_sample := (others => '0');
    signal current_sensor_state : t_sensor_state := C_SENSOR_STATE_INVALID;
    signal comm_state           : t_comm_state := C_COMM_STATE_NO_FRAME;
    signal total_frames         : t_counter := (others => '0');
    signal valid_frames         : t_counter := (others => '0');
    signal corrupted_frames     : t_counter := (others => '0');
    signal missing_frames       : t_counter := (others => '0');
    signal timeout_events       : t_counter := (others => '0');
    signal pixel_ce             : std_logic := '0';
    signal active_video         : std_logic := '0';
    signal pixel_x              : unsigned(11 downto 0) := (others => '0');
    signal pixel_y              : unsigned(11 downto 0) := (others => '0');
    signal display_good         : std_logic := '0';
    signal display_none         : std_logic := '0';
    signal selected_uart_rx     : std_logic := '1';
    signal internal_uart_rx     : std_logic := '1';
begin
    selected_uart_rx <= internal_uart_rx when G_USE_INTERNAL_UART_TEST_SOURCE else uart_rx_i;

    gen_internal_uart_test_source : if G_USE_INTERNAL_UART_TEST_SOURCE generate
    begin
        u_internal_uart_frame_gen : entity work.internal_uart_frame_gen
            generic map (
                G_CLOCK_FREQ_HZ            => G_CLOCK_FREQ_HZ,
                G_BAUD_RATE                => G_BAUD_RATE,
                G_FRAME_GAP_CLKS           => G_INTERNAL_UART_FRAME_GAP_CLKS,
                G_SAMPLE_HOLD_FRAMES       => G_INTERNAL_UART_SAMPLE_HOLD_FRAMES,
                G_SAMPLE_STEP              => G_INTERNAL_UART_SAMPLE_STEP,
                G_SOURCE_IS_ADC            => '0',
                G_ENABLE_CORRUPT_FRAME_TEST => G_INTERNAL_UART_CORRUPT_FRAME_TEST,
                G_CORRUPT_FRAME_PERIOD     => G_INTERNAL_UART_CORRUPT_FRAME_PERIOD
            )
            port map (
                clk       => clk,
                rst       => rst,
                uart_tx_o => internal_uart_rx
            );
    end generate;

    u_uart_rx : entity work.uart_rx
        generic map (
            G_CLOCK_FREQ_HZ => G_CLOCK_FREQ_HZ,
            G_BAUD_RATE     => G_BAUD_RATE
        )
        port map (
            clk        => clk,
            rst        => rst,
            rx         => selected_uart_rx,
            data_out   => rx_byte,
            data_valid => rx_data_valid
        );

    u_frame_decoder : entity work.frame_decoder
        port map (
            clk                  => clk,
            rst                  => rst,
            data_in              => rx_byte,
            data_valid           => rx_data_valid,
            sequence_value       => rx_sequence,
            measured_value       => measured_value,
            tx_sensor_state      => tx_sensor_state,
            tx_range_ok          => tx_range_ok,
            frame_activity_pulse => frame_activity_pulse,
            frame_valid_pulse    => frame_valid_pulse,
            frame_corrupt_pulse  => frame_corrupt_pulse,
            header_error_pulse   => open,
            footer_error_pulse   => open,
            crc_error_pulse      => open
        );

    u_link_statistics : entity work.link_statistics
        generic map (
            G_TIMEOUT_CLKS => G_FRAME_TIMEOUT_CLKS
        )
        port map (
            clk                    => clk,
            rst                    => rst,
            frame_activity_pulse   => frame_activity_pulse,
            frame_valid_pulse      => frame_valid_pulse,
            frame_corrupt_pulse    => frame_corrupt_pulse,
            sequence_value         => rx_sequence,
            measured_value         => measured_value,
            tx_sensor_state        => tx_sensor_state,
            tx_range_ok            => tx_range_ok,
            total_frames_o         => total_frames,
            valid_frames_o         => valid_frames,
            corrupted_frames_o     => corrupted_frames,
            missing_frames_o       => missing_frames,
            timeout_events_o       => timeout_events,
            current_sensor_value_o => current_sensor_value,
            current_sensor_state_o => current_sensor_state,
            comm_state_o           => comm_state
        );

    u_vga_timing : entity work.vga_timing
        generic map (
            G_H_ACTIVE      => C_H_ACTIVE,
            G_H_FRONT_PORCH => C_H_FRONT,
            G_H_SYNC        => C_H_SYNC,
            G_H_BACK_PORCH  => C_H_BACK,
            G_V_ACTIVE      => C_V_ACTIVE,
            G_V_FRONT_PORCH => C_V_FRONT,
            G_V_SYNC        => C_V_SYNC,
            G_V_BACK_PORCH  => C_V_BACK
        )
        port map (
            clk            => clk,
            rst            => rst,
            pixel_ce_o     => pixel_ce,
            active_video_o => active_video,
            pixel_x_o      => pixel_x,
            pixel_y_o      => pixel_y,
            hsync_o        => vga_hsync_o,
            vsync_o        => vga_vsync_o
        );

    u_vga_dashboard : entity work.vga_dashboard
        generic map (
            G_ACTIVE_WIDTH  => C_H_ACTIVE,
            G_ACTIVE_HEIGHT => C_V_ACTIVE
        )
        port map (
            clk                  => clk,
            rst                  => rst,
            pixel_ce             => pixel_ce,
            active_video         => active_video,
            pixel_x              => pixel_x,
            pixel_y              => pixel_y,
            current_sensor_value => current_sensor_value,
            current_sensor_state => current_sensor_state,
            comm_state           => comm_state,
            valid_frames         => valid_frames,
            corrupted_frames     => corrupted_frames,
            missing_frames       => missing_frames,
            timeout_events       => timeout_events,
            vga_r_o              => vga_r_o,
            vga_g_o              => vga_g_o,
            vga_b_o              => vga_b_o
        );

    -- FPGA2 uses the seven-segment display as a link-integrity indicator:
    -- GOOD for a clean link, NONE when no frame is available, and ERROR only
    -- when the receive link is degraded.
    display_good <= '1' when comm_state = C_COMM_STATE_OK else '0';
    display_none <= '1'
        when (comm_state = C_COMM_STATE_NO_FRAME) or (comm_state = C_COMM_STATE_TIMEOUT)
        else '0';

    -- Board LEDs stay disabled on FPGA2 in every mode.
    leds_o <= (others => '0');

    hex5_n_o <= C_SEG_BLANK_N;
    hex4_n_o <= C_SEG_BLANK_N when (display_good = '1') or (display_none = '1') else C_SEG_E_N;
    hex3_n_o <= C_SEG_G_N when display_good = '1'
                else C_SEG_N_N when display_none = '1'
                else C_SEG_R_N;
    hex2_n_o <= C_SEG_O_N when (display_good = '1') or (display_none = '1') else C_SEG_R_N;
    hex1_n_o <= C_SEG_O_N when display_good = '1'
                else C_SEG_N_N when display_none = '1'
                else C_SEG_O_N;
    hex0_n_o <= C_SEG_D_N when display_good = '1'
                else C_SEG_E_N when display_none = '1'
                else C_SEG_R_N;
end architecture rtl;
