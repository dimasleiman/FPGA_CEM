library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package fpga2_pkg is
    constant C_SAMPLE_WIDTH     : positive := 12;
    constant C_FRAME_BYTE_COUNT : positive := 5;

    constant C_FRAME_HEADER : std_logic_vector(7 downto 0) := x"AA";
    constant C_FRAME_FOOTER : std_logic_vector(7 downto 0) := x"55";

    constant C_LED_NORMAL   : std_logic_vector(3 downto 0) := "0001";
    constant C_LED_WARNING  : std_logic_vector(3 downto 0) := "0010";
    constant C_LED_ERROR    : std_logic_vector(3 downto 0) := "0100";
    constant C_LED_NO_FRAME : std_logic_vector(3 downto 0) := "1000";

    subtype t_sample is std_logic_vector(C_SAMPLE_WIDTH - 1 downto 0);
    subtype t_uart_byte is std_logic_vector(7 downto 0);
end package fpga2_pkg;

package body fpga2_pkg is
end package body fpga2_pkg;
