library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package dual_fpga_system_pkg is
    constant C_COUNTER_WIDTH : positive := 8;

    subtype t_uart_byte is std_logic_vector(7 downto 0);
    subtype t_counter is unsigned(C_COUNTER_WIDTH - 1 downto 0);

    constant C_HEX_OFF_N : std_logic_vector(6 downto 0) := (others => '1');

    function next_counter_value(counter_value : t_counter) return t_counter;
end package dual_fpga_system_pkg;

package body dual_fpga_system_pkg is
    function next_counter_value(counter_value : t_counter) return t_counter is
    begin
        return counter_value + 1;
    end function next_counter_value;
end package body dual_fpga_system_pkg;
