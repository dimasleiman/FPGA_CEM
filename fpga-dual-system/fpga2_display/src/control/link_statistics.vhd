library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.dual_fpga_system_pkg.all;

entity link_statistics is
    generic (
        G_TIMEOUT_CLKS : positive := 25_000_000
    );
    port (
        clk                  : in  std_logic;
        rst                  : in  std_logic;
        frame_activity_pulse : in  std_logic;
        frame_valid_pulse    : in  std_logic;
        frame_corrupt_pulse  : in  std_logic;
        sequence_value       : in  t_uart_byte;
        measured_value       : in  t_sample;
        tx_sensor_state      : in  t_sensor_state;
        tx_range_ok          : in  std_logic;
        total_frames_o       : out t_counter;
        valid_frames_o       : out t_counter;
        corrupted_frames_o   : out t_counter;
        missing_frames_o     : out t_counter;
        timeout_events_o     : out t_counter;
        current_sensor_value_o : out t_sample;
        current_sensor_state_o : out t_sensor_state;
        comm_state_o         : out t_comm_state
    );
end entity link_statistics;

architecture rtl of link_statistics is
    signal total_frames_reg         : t_counter := (others => '0');
    signal valid_frames_reg         : t_counter := (others => '0');
    signal corrupted_frames_reg     : t_counter := (others => '0');
    signal missing_frames_reg       : t_counter := (others => '0');
    signal timeout_events_reg       : t_counter := (others => '0');
    signal current_sensor_value_reg : t_sample := (others => '0');
    signal current_sensor_state_reg : t_sensor_state := C_SENSOR_STATE_INVALID;
    signal comm_state_reg           : t_comm_state := C_COMM_STATE_NO_FRAME;
    signal expected_sequence_reg    : t_uart_byte := (others => '0');
    signal sequence_seen_reg        : std_logic := '0';
    signal link_started_reg         : std_logic := '0';
    signal timeout_latched_reg      : std_logic := '0';
    signal inactivity_counter       : natural range 0 to G_TIMEOUT_CLKS - 1 := 0;
begin
    process (clk)
        variable missing_count  : unsigned(7 downto 0);
    begin
        if rising_edge(clk) then
            if rst = '1' then
                total_frames_reg         <= (others => '0');
                valid_frames_reg         <= (others => '0');
                corrupted_frames_reg     <= (others => '0');
                missing_frames_reg       <= (others => '0');
                timeout_events_reg       <= (others => '0');
                current_sensor_value_reg <= (others => '0');
                current_sensor_state_reg <= C_SENSOR_STATE_INVALID;
                comm_state_reg           <= C_COMM_STATE_NO_FRAME;
                expected_sequence_reg    <= (others => '0');
                sequence_seen_reg        <= '0';
                link_started_reg         <= '0';
                timeout_latched_reg      <= '0';
                inactivity_counter       <= 0;
            else
                if frame_activity_pulse = '1' then
                    total_frames_reg    <= total_frames_reg + 1;
                    link_started_reg    <= '1';
                    timeout_latched_reg <= '0';
                    inactivity_counter  <= 0;
                elsif link_started_reg = '1' then
                    if inactivity_counter = G_TIMEOUT_CLKS - 1 then
                        if timeout_latched_reg = '0' then
                            timeout_events_reg  <= timeout_events_reg + 1;
                            comm_state_reg      <= C_COMM_STATE_TIMEOUT;
                            timeout_latched_reg <= '1';
                        end if;
                    else
                        inactivity_counter <= inactivity_counter + 1;
                    end if;
                end if;

                if frame_corrupt_pulse = '1' then
                    corrupted_frames_reg <= corrupted_frames_reg + 1;
                    comm_state_reg       <= C_COMM_STATE_DEGRADED;
                elsif frame_valid_pulse = '1' then
                    valid_frames_reg         <= valid_frames_reg + 1;
                    current_sensor_value_reg <= measured_value;
                    current_sensor_state_reg <= tx_sensor_state;

                    if sequence_seen_reg = '1' then
                        missing_count := missing_frame_count(expected_sequence_reg, sequence_value);

                        if missing_count /= 0 then
                            missing_frames_reg <= missing_frames_reg + resize(missing_count, C_COUNTER_WIDTH);
                            comm_state_reg     <= C_COMM_STATE_DEGRADED;
                        else
                            comm_state_reg <= C_COMM_STATE_OK;
                        end if;
                    else
                        sequence_seen_reg <= '1';
                        comm_state_reg    <= C_COMM_STATE_OK;
                    end if;

                    expected_sequence_reg <= next_sequence(sequence_value);
                end if;
            end if;
        end if;
    end process;

    total_frames_o         <= total_frames_reg;
    valid_frames_o         <= valid_frames_reg;
    corrupted_frames_o     <= corrupted_frames_reg;
    missing_frames_o       <= missing_frames_reg;
    timeout_events_o       <= timeout_events_reg;
    current_sensor_value_o <= current_sensor_value_reg;
    current_sensor_state_o <= current_sensor_state_reg;
    comm_state_o           <= comm_state_reg;
end architecture rtl;
