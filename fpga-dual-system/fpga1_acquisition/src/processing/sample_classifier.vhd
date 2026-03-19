library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.dual_fpga_system_pkg.all;

entity sample_classifier is
    port (
        sample_value  : in  t_sample;
        sample_valid  : in  std_logic;
        range_ok      : in  std_logic;
        sensor_state  : out t_sensor_state
    );
end entity sample_classifier;

architecture rtl of sample_classifier is
begin
    process (sample_value, sample_valid, range_ok)
    begin
        if sample_valid = '1' then
            sensor_state <= classify_sample(sample_value, range_ok);
        else
            sensor_state <= C_SENSOR_STATE_INVALID;
        end if;
    end process;
end architecture rtl;
