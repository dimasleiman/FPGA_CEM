library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.fpga1_pkg.all;

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
        variable sample_integer : natural;
    begin
        warning_flag <= '0';
        error_flag   <= '0';

        if sample_valid = '1' then
            sample_integer := to_integer(unsigned(sample_value));

            if sample_integer > C_WARNING_MAX then
                error_flag <= '1';
            elsif sample_integer > C_NORMAL_MAX then
                warning_flag <= '1';
            end if;
        end if;
    end process;
end architecture rtl;
