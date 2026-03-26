library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.dual_fpga_system_pkg.all;

entity sample_classifier is
    port (
        sample_valid  : in  std_logic;
        range_ok      : in  std_logic;
        sensor_state  : out t_sensor_state
    );
end entity sample_classifier;

architecture rtl of sample_classifier is
begin
    process (sample_valid, range_ok)
    begin
        if sample_valid = '1' then
            if range_ok /= '1' then
                sensor_state <= C_SENSOR_STATE_ERROR;
            else
                sensor_state <= C_SENSOR_STATE_NORMAL;
            end if;
        else
            sensor_state <= C_SENSOR_STATE_INVALID;
        end if;
    end process;
end architecture rtl;
