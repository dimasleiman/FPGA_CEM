--Ce wrapper du FPGA2 détecte proprement l’arrivée du signal de synchronisation venant du FPGA1 et le transforme en une impulsion de redémarrage pour fpga2_top.
-- 1.Synchronise le reset externe
-- 2.Synchronise le signal burst_sync_i venant du FPGA1
-- 3.Détecte quand ce signal passe de 0 à 1
-- 4.Transforme ce front montant en une impulsion restart_pulse
-- 5.Envoie cette impulsion à fpga2_top
--Ensuite fpga2_top utilise cette impulsion pour redémarrer sa logique de réception UART.

library ieee;
use ieee.std_logic_1164.all;

entity de10_lite_fpga2_wrapper is
    generic (
        G_CLOCK_FREQ_HZ             : positive := 50_000_000;
        G_BAUD_RATE                 : positive := 115_200;
        G_RESET_ACTIVE_LEVEL        : std_logic := '0';			--Indique si le reset externe est actif à 0
        G_ERROR_BLINK_TOGGLE_CLKS   : positive := 12_500_000;	--Pour faire clignoter une LED d’erreur
        G_RESET_FLASH_TOGGLE_CLKS   : positive := 2_500_000;	--Utilisé pour faire clignoter une indication pendant une phase de reset
        G_RESET_FLASH_DURATION_CLKS : positive := 50_000_000;	--50 000 000 cycles = 1 s
        G_MANUAL_SYNC_MIN_CLKS      : positive := 8
    );
    port (
        clock_50_i     : in  std_logic;
        reset_source_i : in  std_logic;
        burst_sync_i   : in  std_logic;
        uart_rx_i      : in  std_logic;
        ledr_o         : out std_logic_vector(9 downto 0);
        hex5_n_o       : out std_logic_vector(6 downto 0);
        hex4_n_o       : out std_logic_vector(6 downto 0);
        hex3_n_o       : out std_logic_vector(6 downto 0);
        hex2_n_o       : out std_logic_vector(6 downto 0);
        hex1_n_o       : out std_logic_vector(6 downto 0);
        hex0_n_o       : out std_logic_vector(6 downto 0)
    );
end entity de10_lite_fpga2_wrapper;

architecture rtl of de10_lite_fpga2_wrapper is
    signal core_rst          : std_logic := '1';
    signal burst_sync_meta   : std_logic := '0';	--Premier étage de synchronisation du signal burst_sync_i
    signal burst_sync_sync   : std_logic := '0';	--Deuxième étage de synchronisation.
    signal burst_sync_prev   : std_logic := '0';	--C’est la valeur précédente de burst_sync_sync.Elle sert à détecter le front montant.
    signal restart_pulse     : std_logic := '0';	--C’est une impulsion interne d’un cycle d’horloge.Elle est envoyée à fpga2_top sur l’entrée restart_i.
    signal manual_reset_flash_pulse : std_logic := '0';
    signal burst_sync_high_clks     : natural range 0 to G_MANUAL_SYNC_MIN_CLKS := 0;
begin
    u_reset_sync : entity work.reset_sync
        generic map (
            G_STAGES             => 2,
            G_INPUT_ACTIVE_LEVEL => G_RESET_ACTIVE_LEVEL
        )
        port map (
            clk       => clock_50_i,
            reset_in  => reset_source_i,
            reset_out => core_rst
        );

	 --C’est un process synchrone, donc tout se met à jour au front montant.
    process (clock_50_i)
    begin
        if rising_edge(clock_50_i) then
            if core_rst = '1' then			--Le reset est actif
                burst_sync_meta <= '0';	--les deux étages de synchronisation sont remis à 0
                burst_sync_sync <= '0';
                burst_sync_prev <= '0';	--La mémoire de l’état précédent est remise à 0
                restart_pulse   <= '0';
                manual_reset_flash_pulse <= '0';
                burst_sync_high_clks     <= 0;
            else
                burst_sync_meta <= burst_sync_i;		--On échantillonne le signal brut venant de l’extérieur.
                burst_sync_sync <= burst_sync_meta;	--On resynchronise encore une fois pour stabiliser le signal.
                burst_sync_prev <= burst_sync_sync;	--On mémorise l’état précédent du signal synchronisé.
                restart_pulse   <= '0';					--Impulsion remise à zéro
                manual_reset_flash_pulse <= '0';

					 --maintenant le signal synchronisé vaut 1,au cycle précédent il valait 0. Donc on vient de détecter un front montant.
                if burst_sync_sync = '1' and burst_sync_prev = '0' then
                    restart_pulse <= '1';
                    burst_sync_high_clks <= 1;
                elsif burst_sync_sync = '1' then
                    if burst_sync_high_clks < G_MANUAL_SYNC_MIN_CLKS then
                        burst_sync_high_clks <= burst_sync_high_clks + 1;
                    end if;
                elsif burst_sync_prev = '1' then
                    if burst_sync_high_clks = G_MANUAL_SYNC_MIN_CLKS then
                        manual_reset_flash_pulse <= '1';
                    end if;

                    burst_sync_high_clks <= 0;
                else
                    burst_sync_high_clks <= 0;
                end if;
					 
            end if;
        end if;
    end process;

    u_core : entity work.fpga2_top
        generic map (
            G_CLOCK_FREQ_HZ             => G_CLOCK_FREQ_HZ,
            G_BAUD_RATE                 => G_BAUD_RATE,
            G_ERROR_BLINK_TOGGLE_CLKS   => G_ERROR_BLINK_TOGGLE_CLKS,
            G_RESET_FLASH_TOGGLE_CLKS   => G_RESET_FLASH_TOGGLE_CLKS,
            G_RESET_FLASH_DURATION_CLKS => G_RESET_FLASH_DURATION_CLKS
        )
        port map (
            clk       => clock_50_i,
            rst       => core_rst,
            restart_i => restart_pulse,
            manual_reset_flash_i => manual_reset_flash_pulse,
            uart_rx_i => uart_rx_i,
            ledr_o    => ledr_o,
            hex5_n_o  => hex5_n_o,
            hex4_n_o  => hex4_n_o,
            hex3_n_o  => hex3_n_o,
            hex2_n_o  => hex2_n_o,
            hex1_n_o  => hex1_n_o,
            hex0_n_o  => hex0_n_o
        );
end architecture rtl;
