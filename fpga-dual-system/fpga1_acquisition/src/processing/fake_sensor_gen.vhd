library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.fpga1_pkg.all;

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
    signal sample_counter   : unsigned(C_SAMPLE_WIDTH - 1 downto 0) := (others => '0');
    signal sample_valid_reg : std_logic := '0';

    constant C_STEP_VALUE : unsigned(C_SAMPLE_WIDTH - 1 downto 0) :=
        to_unsigned(G_STEP, C_SAMPLE_WIDTH);
begin
    assert G_STEP < (2 ** C_SAMPLE_WIDTH)
        report "fake_sensor_gen requires G_STEP to fit within the sample width."
        severity failure;

    process (clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                divider_count    <= 0;
                sample_counter   <= (others => '0');
                sample_valid_reg <= '0';
            else
                sample_valid_reg <= '0';

                -- Create a slow sawtooth-style test signal by stepping the
                -- sample value after a programmable number of clock cycles.
                if divider_count = G_UPDATE_DIVIDER - 1 then
                    divider_count    <= 0;
                    sample_counter   <= sample_counter + C_STEP_VALUE;
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
