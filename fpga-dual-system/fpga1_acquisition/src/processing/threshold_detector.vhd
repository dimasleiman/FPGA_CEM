library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.dual_fpga_system_pkg.all;

entity threshold_detector is
    port (
        sample_value : in  t_sample;
        sample_valid : in  std_logic;
        warning_flag : out std_logic;
        error_flag   : out std_logic
    );
end entity threshold_detector;

architecture rtl of threshold_detector is
begin
    process (sample_value, sample_valid)
        variable sensor_state_v : t_sensor_state;
    begin
        warning_flag <= '0';
        error_flag   <= '0';

        if sample_valid = '1' then
            sensor_state_v := classify_sample(sample_value, sample_range_ok(sample_value));

            if sensor_state_v = C_SENSOR_STATE_ERROR then
                error_flag <= '1';
            elsif sensor_state_v = C_SENSOR_STATE_WARNING then
                warning_flag <= '1';
            end if;
        end if;
    end process;
end architecture rtl;
