library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.dual_fpga_system_pkg.all;
use work.fpga2_pkg.all;

entity fpga2_top is
    generic (
        G_CLOCK_FREQ_HZ        : positive := 50_000_000;
        G_BAUD_RATE            : positive := 115_200;
        G_FRAME_TIMEOUT_CLKS   : positive := 25_000_000;
        G_FAST_SIMULATION_VGA  : boolean  := false
    );
    port (
        clk         : in  std_logic;
        rst         : in  std_logic;
        uart_rx_i   : in  std_logic;
        leds_o      : out std_logic_vector(3 downto 0);
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
    signal led_pattern          : std_logic_vector(3 downto 0) := C_LED_NO_FRAME;
    signal pixel_ce             : std_logic := '0';
    signal active_video         : std_logic := '0';
    signal pixel_x              : unsigned(11 downto 0) := (others => '0');
    signal pixel_y              : unsigned(11 downto 0) := (others => '0');
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

    u_status_mapper : entity work.status_mapper
        port map (
            sensor_state => current_sensor_state,
            comm_state   => comm_state,
            led_pattern  => led_pattern
        );

    u_led_driver : entity work.led_driver
        port map (
            clk    => clk,
            rst    => rst,
            load   => frame_activity_pulse or frame_valid_pulse or frame_corrupt_pulse,
            led_in => led_pattern,
            leds   => leds_o
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
end architecture rtl;
