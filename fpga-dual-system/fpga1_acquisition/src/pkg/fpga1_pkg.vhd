library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.dual_fpga_system_pkg.all;

package fpga1_pkg is
    constant C_REAL_SENSOR_SOURCE_IS_ADC                 : std_logic := '1';
    constant C_DEFAULT_EMI_WINDOW_SIZE                  : positive := 8;
    constant C_DEFAULT_EMI_SPREAD_WARNING_THRESHOLD_CODES : positive := 24;
    constant C_DEFAULT_ADC_CHANNEL_INDEX                : natural := 0;
    constant C_DEFAULT_ADC_OUTPUT_PERIOD_CLKS           : positive := 1_000_000;
    constant C_DEFAULT_SIM_SAMPLE_PERIOD_CLKS           : positive := 12_000;
    constant C_DEFAULT_SIM_SAMPLE_CODE                  : natural := 2_025;
    constant C_DEFAULT_FAKE_SENSOR_MIN_CODE             : natural := C_SENSOR_MIN_CODE;
    constant C_DEFAULT_FAKE_SENSOR_MAX_CODE             : natural := 3_900;
    constant C_DEFAULT_FAKE_SENSOR_STEP_CODE            : positive := 100;
    constant C_DISPLAY_SCALE_DIVISOR                    : positive := 100;
    constant C_DISPLAY_TEMP_MIN_C                       : integer := 0;
    constant C_DISPLAY_TEMP_MAX_C                       : integer := 99;

    function sample_code_to_display_temp(sample_code : t_sample) return integer;
end package fpga1_pkg;

package body fpga1_pkg is
    function sample_code_to_display_temp(sample_code : t_sample) return integer is
        variable code_v : natural;
    begin
        code_v := to_integer(unsigned(sample_code));
        return integer(code_v / C_DISPLAY_SCALE_DIVISOR);
    end function sample_code_to_display_temp;
end package body fpga1_pkg;
