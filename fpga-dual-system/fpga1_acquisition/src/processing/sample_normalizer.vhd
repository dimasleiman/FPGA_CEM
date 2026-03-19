library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.dual_fpga_system_pkg.all;

entity sample_normalizer is
    port (
        sample_in      : in  t_sample;
        sample_valid_i : in  std_logic;
        sample_out     : out t_sample;
        sample_valid_o : out std_logic
    );
end entity sample_normalizer;

architecture rtl of sample_normalizer is
begin
    -- Phase 1 keeps the fake sensor path in raw 12-bit sample codes while
    -- preserving a dedicated stage where real ADC scaling can be inserted later.
    sample_out     <= sample_in;
    sample_valid_o <= sample_valid_i;
end architecture rtl;
