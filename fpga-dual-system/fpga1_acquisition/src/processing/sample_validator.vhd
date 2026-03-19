library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.dual_fpga_system_pkg.all;

entity sample_validator is
    port (
        sample_value : in  t_sample;
        sample_valid : in  std_logic;
        range_ok     : out std_logic;
        range_error  : out std_logic
    );
end entity sample_validator;

architecture rtl of sample_validator is
begin
    process (sample_value, sample_valid)
        variable range_ok_v : std_logic;
    begin
        range_ok_v := '0';

        if sample_valid = '1' then
            range_ok_v := sample_range_ok(sample_value);
        end if;

        range_ok    <= range_ok_v;
        range_error <= not range_ok_v;
    end process;
end architecture rtl;
