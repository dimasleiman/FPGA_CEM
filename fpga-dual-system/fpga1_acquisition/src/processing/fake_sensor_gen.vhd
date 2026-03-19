library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.dual_fpga_system_pkg.all;

entity fake_sensor_gen is
    generic (
        G_UPDATE_DIVIDER : positive := 5_000_000;
        G_STEP           : positive := 17
    );
    port (
        clk          : in  std_logic;
        rst          : in  std_logic;
        sample_value : out t_sample;
        sample_valid : out std_logic
    );
end entity fake_sensor_gen;

architecture rtl of fake_sensor_gen is
    signal divider_count    : natural range 0 to G_UPDATE_DIVIDER - 1 := 0;
    signal sample_counter   : unsigned(C_SAMPLE_WIDTH - 1 downto 0) :=
        to_unsigned(C_SENSOR_MIN_CODE, C_SAMPLE_WIDTH);
    signal ramp_up_reg      : std_logic := '1';
    signal sample_valid_reg : std_logic := '0';

    constant C_STEP_VALUE : unsigned(C_SAMPLE_WIDTH - 1 downto 0) :=
        to_unsigned(G_STEP, C_SAMPLE_WIDTH);
    constant C_MIN_TEMP_CODE : unsigned(C_SAMPLE_WIDTH - 1 downto 0) :=
        to_unsigned(C_SENSOR_MIN_CODE, C_SAMPLE_WIDTH);
    constant C_MAX_TEMP_CODE : unsigned(C_SAMPLE_WIDTH - 1 downto 0) :=
        to_unsigned(C_SENSOR_MAX_CODE, C_SAMPLE_WIDTH);
begin
    assert G_STEP < (2 ** C_SAMPLE_WIDTH)
        report "fake_sensor_gen requires G_STEP to fit within the sample width."
        severity failure;
    assert C_SENSOR_MIN_CODE < C_SENSOR_MAX_CODE
        report "fake_sensor_gen requires the minimum temperature code to be less than the maximum code."
        severity failure;
    assert C_SENSOR_MAX_CODE < (2 ** C_SAMPLE_WIDTH)
        report "fake_sensor_gen requires the temperature range to fit within the sample width."
        severity failure;

    process (clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                divider_count    <= 0;
                sample_counter   <= C_MIN_TEMP_CODE;
                ramp_up_reg      <= '1';
                sample_valid_reg <= '0';
            else
                sample_valid_reg <= '0';

                -- Emulate a slowly changing temperature sensor by moving
                -- between cold and hot sample codes, then reversing direction
                -- instead of wrapping abruptly back to zero.
                if divider_count = G_UPDATE_DIVIDER - 1 then
                    divider_count <= 0;

                    if ramp_up_reg = '1' then
                        if sample_counter >= C_MAX_TEMP_CODE - C_STEP_VALUE then
                            sample_counter <= C_MAX_TEMP_CODE;
                            ramp_up_reg    <= '0';
                        else
                            sample_counter <= sample_counter + C_STEP_VALUE;
                        end if;
                    else
                        if sample_counter <= C_MIN_TEMP_CODE + C_STEP_VALUE then
                            sample_counter <= C_MIN_TEMP_CODE;
                            ramp_up_reg    <= '1';
                        else
                            sample_counter <= sample_counter - C_STEP_VALUE;
                        end if;
                    end if;

                    sample_valid_reg <= '1';
                else
                    divider_count <= divider_count + 1;
                end if;
            end if;
        end if;
    end process;

    sample_value <= std_logic_vector(sample_counter);
    sample_valid <= sample_valid_reg;
end architecture rtl;
