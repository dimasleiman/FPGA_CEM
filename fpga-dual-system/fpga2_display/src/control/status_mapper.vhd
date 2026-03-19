library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.dual_fpga_system_pkg.all;
use work.fpga2_pkg.all;

entity status_mapper is
    port (
        sensor_state : in  t_sensor_state;
        comm_state   : in  t_comm_state;
        led_pattern  : out std_logic_vector(3 downto 0)
    );
end entity status_mapper;

architecture rtl of status_mapper is
begin
    process (sensor_state, comm_state)
    begin
        if (comm_state = C_COMM_STATE_NO_FRAME)
           or (comm_state = C_COMM_STATE_TIMEOUT) then
            led_pattern <= C_LED_NO_FRAME;
        elsif comm_state = C_COMM_STATE_DEGRADED then
            led_pattern <= C_LED_LINK_WARN;
        elsif sensor_state = C_SENSOR_STATE_ERROR then
            led_pattern <= C_LED_ERROR;
        elsif sensor_state = C_SENSOR_STATE_WARNING then
            led_pattern <= C_LED_WARNING;
        else
            led_pattern <= C_LED_NORMAL;
        end if;
    end process;
end architecture rtl;
