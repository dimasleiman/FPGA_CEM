library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.dual_fpga_system_pkg.all;

entity sample_noise_monitor is
    generic (
        G_WINDOW_SIZE              : positive := 8;
        G_SPREAD_WARNING_THRESHOLD : positive := 24
    );
    port (
        clk         : in  std_logic;
        rst         : in  std_logic;
        sample_value : in  t_sample;
        sample_valid : in  std_logic;
        warning_flag : out std_logic
    );
end entity sample_noise_monitor;

architecture rtl of sample_noise_monitor is
    type t_sample_window is array (natural range <>) of unsigned(C_SAMPLE_WIDTH - 1 downto 0);

    signal sample_window : t_sample_window(0 to G_WINDOW_SIZE - 1) := (others => (others => '0'));
    signal write_index   : natural range 0 to G_WINDOW_SIZE - 1 := 0;
    signal sample_count  : natural range 0 to G_WINDOW_SIZE := 0;
    signal warning_reg   : std_logic := '0';
begin
    process (clk)
        variable sample_v          : unsigned(C_SAMPLE_WIDTH - 1 downto 0);
        variable candidate_v       : unsigned(C_SAMPLE_WIDTH - 1 downto 0);
        variable min_v             : unsigned(C_SAMPLE_WIDTH - 1 downto 0);
        variable max_v             : unsigned(C_SAMPLE_WIDTH - 1 downto 0);
        variable effective_count_v : natural range 0 to G_WINDOW_SIZE;
        variable spread_v          : natural;
    begin
        if rising_edge(clk) then
            if rst = '1' then
                sample_window <= (others => (others => '0'));
                write_index   <= 0;
                sample_count  <= 0;
                warning_reg   <= '0';
            elsif sample_valid = '1' then
                sample_v          := unsigned(sample_value);
                min_v             := sample_v;
                max_v             := sample_v;
                effective_count_v := sample_count;

                if effective_count_v < G_WINDOW_SIZE then
                    effective_count_v := effective_count_v + 1;
                end if;

                for window_index in 0 to G_WINDOW_SIZE - 1 loop
                    if (sample_count = G_WINDOW_SIZE) or (window_index < sample_count) then
                        if window_index = write_index then
                            candidate_v := sample_v;
                        else
                            candidate_v := sample_window(window_index);
                        end if;

                        if candidate_v < min_v then
                            min_v := candidate_v;
                        end if;

                        if candidate_v > max_v then
                            max_v := candidate_v;
                        end if;
                    end if;
                end loop;

                sample_window(write_index) <= sample_v;

                if write_index = G_WINDOW_SIZE - 1 then
                    write_index <= 0;
                else
                    write_index <= write_index + 1;
                end if;

                if sample_count < G_WINDOW_SIZE then
                    sample_count <= sample_count + 1;
                end if;

                if effective_count_v = G_WINDOW_SIZE then
                    spread_v := to_integer(max_v) - to_integer(min_v);

                    if spread_v > G_SPREAD_WARNING_THRESHOLD then
                        warning_reg <= '1';
                    else
                        warning_reg <= '0';
                    end if;
                else
                    warning_reg <= '0';
                end if;
            end if;
        end if;
    end process;

    warning_flag <= warning_reg;
end architecture rtl;
