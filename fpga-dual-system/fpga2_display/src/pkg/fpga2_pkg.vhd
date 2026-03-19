library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package fpga2_pkg is
    constant C_LED_NORMAL   : std_logic_vector(3 downto 0) := "0001";
    constant C_LED_WARNING  : std_logic_vector(3 downto 0) := "0010";
    constant C_LED_ERROR    : std_logic_vector(3 downto 0) := "0100";
    constant C_LED_NO_FRAME : std_logic_vector(3 downto 0) := "1000";
    constant C_LED_LINK_WARN : std_logic_vector(3 downto 0) := "1100";
end package fpga2_pkg;

package body fpga2_pkg is
end package body fpga2_pkg;
