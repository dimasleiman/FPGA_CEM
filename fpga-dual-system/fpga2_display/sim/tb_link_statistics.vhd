library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.dual_fpga_system_pkg.all;

entity tb_link_statistics is
end entity tb_link_statistics;

architecture sim of tb_link_statistics is
    constant C_CLOCK_PERIOD       : time     := 1 us;
    constant C_TIMEOUT_CLKS       : positive := 8;

    signal clk                  : std_logic := '0';
    signal rst                  : std_logic := '1';
    signal frame_activity_pulse : std_logic := '0';
    signal frame_valid_pulse    : std_logic := '0';
    signal frame_corrupt_pulse  : std_logic := '0';
    signal sequence_value       : t_uart_byte := (others => '0');
    signal measured_value       : t_sample := (others => '0');
    signal tx_sensor_state      : t_sensor_state := C_SENSOR_STATE_INVALID;
    signal tx_range_ok          : std_logic := '0';
    signal total_frames_o       : t_counter;
    signal valid_frames_o       : t_counter;
    signal corrupted_frames_o   : t_counter;
    signal missing_frames_o     : t_counter;
    signal timeout_events_o     : t_counter;
    signal current_sensor_value_o : t_sample;
    signal current_sensor_state_o : t_sensor_state;
    signal comm_state_o         : t_comm_state;
    signal tb_done              : std_logic := '0';
begin
    clk <= not clk after C_CLOCK_PERIOD / 2;

    u_dut : entity work.link_statistics
        generic map (
            G_TIMEOUT_CLKS => C_TIMEOUT_CLKS
        )
        port map (
            clk                    => clk,
            rst                    => rst,
            frame_activity_pulse   => frame_activity_pulse,
            frame_valid_pulse      => frame_valid_pulse,
            frame_corrupt_pulse    => frame_corrupt_pulse,
            sequence_value         => sequence_value,
            measured_value         => measured_value,
            tx_sensor_state        => tx_sensor_state,
            tx_range_ok            => tx_range_ok,
            total_frames_o         => total_frames_o,
            valid_frames_o         => valid_frames_o,
            corrupted_frames_o     => corrupted_frames_o,
            missing_frames_o       => missing_frames_o,
            timeout_events_o       => timeout_events_o,
            current_sensor_value_o => current_sensor_value_o,
            current_sensor_state_o => current_sensor_state_o,
            comm_state_o           => comm_state_o
        );

    stimulus : process
        procedure drive_valid_frame (
            constant sequence_id : in natural;
            constant sample_code : in natural
        ) is
            variable sample_value : t_sample;
            variable range_ok_v   : std_logic;
        begin
            sample_value := std_logic_vector(to_unsigned(sample_code, C_SAMPLE_WIDTH));
            range_ok_v   := sample_range_ok(sample_value);

            wait until rising_edge(clk);
            sequence_value       <= std_logic_vector(to_unsigned(sequence_id mod 256, 8));
            measured_value       <= sample_value;
            tx_sensor_state      <= classify_sample(sample_value, range_ok_v);
            tx_range_ok          <= range_ok_v;
            frame_activity_pulse <= '1';
            frame_valid_pulse    <= '1';
            frame_corrupt_pulse  <= '0';

            wait until rising_edge(clk);
            frame_activity_pulse <= '0';
            frame_valid_pulse    <= '0';
        end procedure drive_valid_frame;

        procedure drive_corrupt_frame is
        begin
            wait until rising_edge(clk);
            frame_activity_pulse <= '1';
            frame_valid_pulse    <= '0';
            frame_corrupt_pulse  <= '1';

            wait until rising_edge(clk);
            frame_activity_pulse <= '0';
            frame_corrupt_pulse  <= '0';
        end procedure drive_corrupt_frame;
    begin
        wait for 4 * C_CLOCK_PERIOD;
        wait until rising_edge(clk);
        rst <= '0';

        wait until rising_edge(clk);
        assert comm_state_o = C_COMM_STATE_NO_FRAME
            report "link_statistics should start in the no-frame state."
            severity failure;

        drive_valid_frame(0, 2000);
        wait until rising_edge(clk);
        assert to_integer(total_frames_o) = 1
            report "link_statistics should count the first frame."
            severity failure;
        assert to_integer(valid_frames_o) = 1
            report "link_statistics should count the first valid frame."
            severity failure;
        assert comm_state_o = C_COMM_STATE_OK
            report "link_statistics should report OK after the first clean frame."
            severity failure;
        assert current_sensor_state_o = C_SENSOR_STATE_NORMAL
            report "link_statistics should store the current normal sensor state."
            severity failure;

        drive_corrupt_frame;
        wait until rising_edge(clk);
        assert to_integer(total_frames_o) = 2
            report "link_statistics should count corrupted frame activity."
            severity failure;
        assert to_integer(corrupted_frames_o) = 1
            report "link_statistics should count corrupted frames."
            severity failure;
        assert comm_state_o = C_COMM_STATE_DEGRADED
            report "link_statistics should report a degraded link after corruption."
            severity failure;

        drive_valid_frame(3, 3000);
        wait until rising_edge(clk);
        assert to_integer(valid_frames_o) = 2
            report "link_statistics should count a later valid frame."
            severity failure;
        assert to_integer(missing_frames_o) = 2
            report "link_statistics should count the two missing sequence IDs between 1 and 3."
            severity failure;
        assert current_sensor_state_o = C_SENSOR_STATE_WARNING
            report "link_statistics should store the warning sensor state from the latest valid frame."
            severity failure;

        wait for 12 * C_CLOCK_PERIOD;
        wait until rising_edge(clk);
        assert to_integer(timeout_events_o) = 1
            report "link_statistics should count a timeout after inactivity."
            severity failure;
        assert comm_state_o = C_COMM_STATE_TIMEOUT
            report "link_statistics should report timeout after inactivity."
            severity failure;

        drive_valid_frame(4, 3500);
        wait until rising_edge(clk);
        assert to_integer(valid_frames_o) = 3
            report "link_statistics should recover with another valid frame."
            severity failure;
        assert current_sensor_state_o = C_SENSOR_STATE_ERROR
            report "link_statistics should store the error sensor state from the latest valid frame."
            severity failure;
        assert comm_state_o = C_COMM_STATE_OK
            report "link_statistics should return to OK after a clean post-timeout frame."
            severity failure;

        report "tb_link_statistics completed successfully." severity note;
        tb_done <= '1';
        wait;
    end process;

    timeout_guard : process
    begin
        wait for 2 ms;
        assert tb_done = '1'
            report "Timeout waiting for link_statistics behavior."
            severity failure;
        wait;
    end process;
end architecture sim;
