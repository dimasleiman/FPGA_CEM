library ieee;
use ieee.std_logic_1164.all;

entity digit_to_7seg_decimal_n is
    port (
        digit_i : in  std_logic_vector(3 downto 0);
        seg_n_o : out std_logic_vector(6 downto 0)
    );
end entity digit_to_7seg_decimal_n;

architecture rtl of digit_to_7seg_decimal_n is
begin
    process (all)
    begin
        -- Board pins map signal index 0..6 to segments a..g. Because this
        -- vector is declared (6 downto 0), the string literals below are
        -- written in gfedcba order.
        if digit_i = "0000" then
            seg_n_o <= "1000000";  -- 0
        elsif digit_i = "0001" then
            seg_n_o <= "1111001";  -- 1
        elsif digit_i = "0010" then
            seg_n_o <= "0100100";  -- 2
        elsif digit_i = "0011" then
            seg_n_o <= "0110000";  -- 3
        elsif digit_i = "0100" then
            seg_n_o <= "0011001";  -- 4
        elsif digit_i = "0101" then
            seg_n_o <= "0010010";  -- 5
        elsif digit_i = "0110" then
            seg_n_o <= "0000010";  -- 6
        elsif digit_i = "0111" then
            seg_n_o <= "1111000";  -- 7
        elsif digit_i = "1000" then
            seg_n_o <= "0000000";  -- 8
        elsif digit_i = "1001" then
            seg_n_o <= "0010000";  -- 9
        else
            seg_n_o <= "1111111";
        end if;
    end process;
end architecture rtl;
