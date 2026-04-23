--Quand on travaille en FPGA, un reset externe peut arriver d’une façon qui n’est pas bien alignée avec le clock.
--Ce module sert à faire cela proprement :
-- 1.détecter si le reset externe est actif
-- 2.charger un registre interne avec des 1
-- 3.puis, quand le reset externe est relâché, faire “descendre” progressivement ce reset sur plusieurs cycles d’horloge
-- 4.produire à la fin un reset_out stable
--Donc ce module agit comme un petit pipeline de synchronisation du reset.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity reset_sync is
    generic (
        G_STAGES             : positive := 2;	--Nombre d’étages de synchronisation. Donc le reset passe à travers 2 registres.
        G_INPUT_ACTIVE_LEVEL : std_logic := '0'	--Indique à quel niveau logique le reset d’entrée est actif. ICI, le reset externe est actif à 0.
    );
    port (
        clk        : in  std_logic;
        reset_in   : in  std_logic;	--Reset venant de l’extérieur.
        reset_out  : out std_logic	--Reset synchronisé qui sort du module.
    );
end entity reset_sync;

architecture rtl of reset_sync is
    signal reset_pipe : std_logic_vector(G_STAGES - 1 downto 0) := (others => '1');	--C’est le registre principal du synchroniseur.
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
