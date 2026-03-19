library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity reset_sync is
    generic (
        G_STAGES             : positive := 2;
        G_INPUT_ACTIVE_LEVEL : std_logic := '0'
    );
    port (
        clk        : in  std_logic;
        reset_in   : in  std_logic;
        reset_out  : out std_logic
    );
end entity reset_sync;

architecture rtl of reset_sync is
    signal reset_pipe : std_logic_vector(G_STAGES - 1 downto 0) := (others => '1');
    signal reset_req  : std_logic := '1';
begin
    assert G_STAGES >= 2
        report "reset_sync requires at least two synchronization stages."
        severity failure;

    reset_req <= '1' when reset_in = G_INPUT_ACTIVE_LEVEL else '0';

    process (clk)
    begin
        if rising_edge(clk) then
            if reset_req = '1' then
                reset_pipe <= (others => '1');
            else
                reset_pipe(reset_pipe'high) <= '0';
                reset_pipe(reset_pipe'high - 1 downto 0) <=
                    reset_pipe(reset_pipe'high downto 1);
            end if;
        end if;
    end process;

    reset_out <= reset_pipe(0);
end architecture rtl;
