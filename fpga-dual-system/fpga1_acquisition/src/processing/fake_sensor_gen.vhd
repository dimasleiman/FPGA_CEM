library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.dual_fpga_system_pkg.all;
use work.fpga1_pkg.all;

entity fake_sensor_gen is
    generic (
        G_UPDATE_DIVIDER                 : positive := 5_000_000;
        G_HOLD_TICKS_PER_VALUE           : positive := 20;
        G_STEP_CODE                      : positive := C_DEFAULT_FAKE_SENSOR_STEP_CODE;
        G_RANDOM_SAMPLE_MODE             : boolean := true;
        G_MIN_CODE                       : natural := C_DEFAULT_FAKE_SENSOR_MIN_CODE;
        G_MAX_CODE                       : natural := C_DEFAULT_FAKE_SENSOR_MAX_CODE;
        G_FORCE_INVALID_SAMPLE_TEST_MODE : std_logic := '0'
    );
    port (
        clk          : in  std_logic;
        rst          : in  std_logic;
        sample_value : out t_sample;
        sample_valid : out std_logic
    );
end entity fake_sensor_gen;

architecture rtl of fake_sensor_gen is
    constant C_SAMPLE_CODE_MAX : natural := (2 ** C_SAMPLE_WIDTH) - 1;
    constant C_RANDOM_RANGE_SIZE : positive := G_MAX_CODE - G_MIN_CODE + 1;
    constant C_LFSR_RESET_VALUE : std_logic_vector(C_SAMPLE_WIDTH - 1 downto 0) :=
        std_logic_vector(to_unsigned(16#A55#, C_SAMPLE_WIDTH));

    function next_lfsr12(current_value : std_logic_vector(C_SAMPLE_WIDTH - 1 downto 0)) return std_logic_vector is
        variable next_value_v : std_logic_vector(C_SAMPLE_WIDTH - 1 downto 0);
        variable feedback_v   : std_logic;
    begin
        if current_value = (current_value'range => '0') then
            return C_LFSR_RESET_VALUE;
        end if;

        feedback_v := current_value(C_SAMPLE_WIDTH - 1)
                    xor current_value(C_SAMPLE_WIDTH - 2)
                    xor current_value(C_SAMPLE_WIDTH - 3)
                    xor current_value(3);
        next_value_v := current_value(C_SAMPLE_WIDTH - 2 downto 0) & feedback_v;
        return next_value_v;
    end function next_lfsr12;

    signal divider_count       : natural range 0 to G_UPDATE_DIVIDER - 1 := G_UPDATE_DIVIDER - 1;
    signal hold_tick_count     : natural range 0 to G_HOLD_TICKS_PER_VALUE - 1 := G_HOLD_TICKS_PER_VALUE - 1;
    signal sample_code_reg     : natural range 0 to C_SAMPLE_CODE_MAX := G_MIN_CODE;
    signal ramp_up_reg         : std_logic := '1';
    signal sample_valid_reg    : std_logic := '0';
    signal random_state_reg    : std_logic_vector(C_SAMPLE_WIDTH - 1 downto 0) := C_LFSR_RESET_VALUE;
begin
    assert G_MIN_CODE < G_MAX_CODE
        report "fake_sensor_gen requires G_MIN_CODE to be less than G_MAX_CODE."
        severity failure;
    assert G_MAX_CODE <= C_SAMPLE_CODE_MAX
        report "fake_sensor_gen requires G_MAX_CODE to fit inside the 12-bit sample width."
        severity failure;
    assert G_STEP_CODE <= (G_MAX_CODE - G_MIN_CODE)
        report "fake_sensor_gen requires G_STEP_CODE to fit inside the generated code window."
        severity failure;
    assert C_SENSOR_TEST_INVALID_CODE < (2 ** C_SAMPLE_WIDTH)
        report "fake_sensor_gen requires the forced invalid sample code to fit within the sample width."
        severity failure;

    process (clk)
        variable next_random_v   : std_logic_vector(C_SAMPLE_WIDTH - 1 downto 0);
        variable next_sample_v   : natural range 0 to C_SAMPLE_CODE_MAX;
    begin
        if rising_edge(clk) then
            if rst = '1' then
                divider_count       <= G_UPDATE_DIVIDER - 1;
                hold_tick_count     <= G_HOLD_TICKS_PER_VALUE - 1;
                sample_code_reg     <= G_MIN_CODE;
                ramp_up_reg         <= '1';
                sample_valid_reg    <= '0';
                random_state_reg    <= C_LFSR_RESET_VALUE;
            else
                sample_valid_reg <= '0';

                if divider_count = G_UPDATE_DIVIDER - 1 then
                    divider_count <= 0;

                    if hold_tick_count = G_HOLD_TICKS_PER_VALUE - 1 then
                        hold_tick_count <= 0;

                        if G_FORCE_INVALID_SAMPLE_TEST_MODE = '1' then
                            sample_code_reg <= C_SENSOR_TEST_INVALID_CODE;
                        elsif G_RANDOM_SAMPLE_MODE then
                            next_random_v := next_lfsr12(random_state_reg);
                            random_state_reg <= next_random_v;
                            sample_code_reg <= G_MIN_CODE + (to_integer(unsigned(next_random_v)) mod C_RANDOM_RANGE_SIZE);
                        elsif ramp_up_reg = '1' then
                            if sample_code_reg >= G_MAX_CODE - G_STEP_CODE then
                                sample_code_reg <= G_MAX_CODE;
                                ramp_up_reg     <= '0';
                            else
                                sample_code_reg <= sample_code_reg + G_STEP_CODE;
                            end if;
                        else
                            if sample_code_reg <= G_MIN_CODE + G_STEP_CODE then
                                sample_code_reg <= G_MIN_CODE;
                                ramp_up_reg     <= '1';
                            else
                                next_sample_v   := sample_code_reg - G_STEP_CODE;
                                sample_code_reg <= next_sample_v;
                            end if;
                        end if;

                        sample_valid_reg <= '1';
                    else
                        hold_tick_count <= hold_tick_count + 1;
                    end if;
                else
                    divider_count <= divider_count + 1;
                end if;
            end if;
        end if;
    end process;

    sample_value <= std_logic_vector(to_unsigned(sample_code_reg, C_SAMPLE_WIDTH));
    sample_valid <= sample_valid_reg;
end architecture rtl;
