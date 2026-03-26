library ieee;
use ieee.std_logic_1164.all;

library work;
use work.dual_fpga_system_pkg.all;
use work.fpga1_pkg.all;

entity sample_normalizer is
    port (
        sample_in      : in  t_sample;
        sample_valid_i : in  std_logic;
        temp_c_o       : out integer range C_DISPLAY_TEMP_MIN_C to C_DISPLAY_TEMP_MAX_C;
        sample_valid_o : out std_logic
    );
end entity sample_normalizer;

architecture rtl of sample_normalizer is
begin
    process (all)
        variable temp_value_v : integer range C_DISPLAY_TEMP_MIN_C to C_DISPLAY_TEMP_MAX_C;
        variable temp_raw_v   : integer;
    begin
        temp_value_v := 0;

        if sample_valid_i = '1' then
            temp_raw_v := sample_code_to_display_temp(sample_in);

            if temp_raw_v < C_DISPLAY_TEMP_MIN_C then
                temp_value_v := C_DISPLAY_TEMP_MIN_C;
            elsif temp_raw_v > C_DISPLAY_TEMP_MAX_C then
                temp_value_v := C_DISPLAY_TEMP_MAX_C;
            else
                temp_value_v := temp_raw_v;
            end if;
        end if;

        temp_c_o       <= temp_value_v;
        sample_valid_o <= sample_valid_i;
    end process;
end architecture rtl;
