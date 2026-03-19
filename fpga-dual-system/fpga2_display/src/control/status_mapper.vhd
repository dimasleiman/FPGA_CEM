library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.fpga2_pkg.all;

entity status_mapper is
    port (
        frame_valid  : in  std_logic;
        warning_flag : in  std_logic;
        error_flag   : in  std_logic;
        led_pattern  : out std_logic_vector(3 downto 0)
    );
end entity status_mapper;

architecture rtl of status_mapper is
begin
    process (frame_valid, warning_flag, error_flag)
    begin
        if frame_valid = '0' then
            led_pattern <= C_LED_NO_FRAME;
        elsif error_flag = '1' then
            led_pattern <= C_LED_ERROR;
        elsif warning_flag = '1' then
            led_pattern <= C_LED_WARNING;
        else
            led_pattern <= C_LED_NORMAL;
        end if;
    end process;
end architecture rtl;
