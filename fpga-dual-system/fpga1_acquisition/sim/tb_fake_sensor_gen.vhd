library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.dual_fpga_system_pkg.all;

entity tb_fake_sensor_gen is
end entity tb_fake_sensor_gen;

architecture sim of tb_fake_sensor_gen is
    constant C_CLOCK_PERIOD : time := 1 us;

    signal clk          : std_logic := '0';
    signal rst          : std_logic := '1';
    signal sample_value : t_sample;
    signal sample_valid : std_logic;
    signal tb_done      : std_logic := '0';

    procedure wait_for_valid_sample (
        signal clk_i         : in std_logic;
        signal sample_valid_i : in std_logic
    ) is
    begin
        loop
            wait until rising_edge(clk_i);

            exit when sample_valid_i = '1';
        end loop;
    end procedure wait_for_valid_sample;
begin
    clk <= not clk after C_CLOCK_PERIOD / 2;

    u_dut : entity work.fake_sensor_gen
        generic map (
            G_UPDATE_DIVIDER       => 2,
            G_HOLD_TICKS_PER_VALUE => 1,
            G_STEP_CODE            => 1_200,
            G_RANDOM_SAMPLE_MODE   => false,
            G_MIN_CODE             => 1_200,
            G_MAX_CODE             => 3_900
        )
        port map (
            clk          => clk,
            rst          => rst,
            sample_value => sample_value,
            sample_valid => sample_valid
        );

    stimulus : process
        variable sample_code_v : natural;
    begin
        wait until rising_edge(clk);
        wait until rising_edge(clk);
        rst <= '0';

        wait_for_valid_sample(clk, sample_valid);
        sample_code_v := to_integer(unsigned(sample_value));
        assert sample_code_v = 2_400
            report "The first fake-sensor sample should ramp to 2400."
            severity failure;

        wait_for_valid_sample(clk, sample_valid);
        sample_code_v := to_integer(unsigned(sample_value));
        assert sample_code_v = 3_600
            report "The second fake-sensor sample should ramp to 3600."
            severity failure;

        wait_for_valid_sample(clk, sample_valid);
        sample_code_v := to_integer(unsigned(sample_value));
        assert sample_code_v = 3_900
            report "The fake sensor generator should continue up to 3900."
            severity failure;

        report "tb_fake_sensor_gen completed successfully." severity note;
        tb_done <= '1';
        wait;
    end process;

    timeout_guard : process
    begin
        wait for 1 ms;
        assert tb_done = '1'
            report "Timeout waiting for the fake sensor generator test."
            severity failure;
        wait;
    end process;
end architecture sim;
