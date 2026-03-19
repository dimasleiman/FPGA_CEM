library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package fpga1_pkg is
    constant C_SAMPLE_WIDTH     : positive := 12;
    constant C_FRAME_BYTE_COUNT : positive := 5;

    constant C_FRAME_HEADER : std_logic_vector(7 downto 0) := x"AA";
    constant C_FRAME_FOOTER : std_logic_vector(7 downto 0) := x"55";

    constant C_NORMAL_MAX  : natural := 2500;
    constant C_WARNING_MAX : natural := 3200;

    subtype t_sample is std_logic_vector(C_SAMPLE_WIDTH - 1 downto 0);
    subtype t_uart_byte is std_logic_vector(7 downto 0);

    type t_frame_array is array (0 to C_FRAME_BYTE_COUNT - 1) of t_uart_byte;
end package fpga1_pkg;

package body fpga1_pkg is
end package body fpga1_pkg;
