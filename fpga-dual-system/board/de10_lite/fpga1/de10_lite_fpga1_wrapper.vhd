--1.Synchroniser le reset
--2.Synchroniser le bouton start
--3.Détecter un appui
--4.Lancer le cœur proprement :
--	 Il génère un petit signal de sync
--	 Il attend un peu
--	 Il envoie un pulse de démarrage
 
library ieee;
use ieee.std_logic_1164.all;

--L’entity décrit ce qui entre et ce qui sort du module.
entity de10_lite_fpga1_wrapper is
    generic (
        G_CLOCK_FREQ_HZ          : positive := 50_000_000;  --Fréquence d’horloge 50MHz
        G_BAUD_RATE              : positive := 115_200;  	--Le débit UART 115200 bauds
        G_RESET_ACTIVE_LEVEL     : std_logic := '0';			--A quel niveau le reset est actif, le reset est actif quand le signal vaut 0
        G_START_BUTTON_ACTIVE_LEVEL : std_logic := '0';		--Bouton actif à l’état bas
        G_SYNC_PULSE_CLKS        : positive := 16;				--Durée de l’impulsion de synchronisation en nombre de cycles d’horloge (16 cycles)
        G_AUTO_RESTART_PULSE_CLKS : positive := 4;
        --Pour 50MHz, 1 période d’horloge = 20 ns. Donc 16 cycles = 320 ns
		  G_START_AFTER_SYNC_DELAY_CLKS : positive := 50_000	--Avec 50 MHz : 50 000 cycles × 20 ns = 1 ms. Donc après le burst sync, on attend 1 ms avant d’envoyer start_pulse.
    );
    port (
	 --Le _i veut souvent dire input, et _o veut dire output.
	 --Le _n dans hexX_n_o suggère souvent que les segments sont actifs à 0.
	 
        clock_50_i     : in  std_logic;							--Horloge 50 MHz
        reset_source_i : in  std_logic;							--Reset venant de l’extérieur, KEY0
        start_button_i : in  std_logic;							--Bouton start externe, KEY1
        ledr_o         : out std_logic_vector(9 downto 0);
        hex5_n_o       : out std_logic_vector(6 downto 0);
        hex4_n_o       : out std_logic_vector(6 downto 0);
        hex3_n_o       : out std_logic_vector(6 downto 0);
        hex2_n_o       : out std_logic_vector(6 downto 0);
        hex1_n_o       : out std_logic_vector(6 downto 0);
        hex0_n_o       : out std_logic_vector(6 downto 0);
        burst_sync_o   : out std_logic;							--Signal de synchronisation
        uart_tx_o      : out std_logic								--Sortie série UART
    );
end entity de10_lite_fpga1_wrapper;
 
--On décrit comment le circuit fonctionne
architecture rtl of de10_lite_fpga1_wrapper is
    signal core_rst             : std_logic := '1';	--Reset interne synchronisé
    signal start_button_meta    : std_logic := '1';	--Premier étage de synchronisation du bouton, meta = première étape
    signal start_button_sync    : std_logic := '1';	--Deuxième étage de synchronisation
    signal start_button_prev    : std_logic := '0';	--Valeur précédente du bouton appuyé / non appuyé. On s’en sert pour détecter un front.
    signal start_button_pressed : std_logic := '0';	--'0' = bouton non appuyé, '1'= bouton appuyé
    signal start_pulse          : std_logic := '0';	--Impulsion d’un cycle envoyée au bloc fpga1_top pour lui dire :“démarre maintenant”
    signal start_pending        : std_logic := '0';	--Le système est en attente de lancer réellement
    signal start_delay_counter  : natural range 0 to G_START_AFTER_SYNC_DELAY_CLKS - 1 := 0; --Compteur pour attendre avant d’envoyer start_pulse
	 --Le type natural veut dire entier positif ou nul. Le range limite la plage autorisée.
    signal sync_pulse_active    : std_logic := '0';	--Dit si l’impulsion de synchronisation est en cours, Quand il vaut '1', le signal burst_sync_o sera actif
    signal sync_pulse_counter   : natural range 0 to G_SYNC_PULSE_CLKS - 1 := 0;		--Compteur de durée de l’impulsion de synchronisation.
    signal core_ledr            : std_logic_vector(9 downto 0) := (others => '0');	--Bus interne pour les LEDs venant du bloc principal.Ensuite on le connecte vers ledr_o
    signal core_busy            : std_logic := '0';	--Signal venant du bloc fpga1_top qui indique si le cœur est occupé.Cela sert à empêcher un nouveau départ pendant qu’il travaille.
    signal core_restart_sync    : std_logic := '0';
begin

    u_reset_sync : entity work.reset_sync
        generic map (
            G_STAGES             => 2,							--2 étages de synchronisation
            G_INPUT_ACTIVE_LEVEL => G_RESET_ACTIVE_LEVEL	--Le module sait si le reset est actif à 0 ou à 1
        )
        port map (
            clk       => clock_50_i,
            reset_in  => reset_source_i,
            reset_out => core_rst
        );
	 --Si start_button_sync est égal au niveau actif du bouton,alors start_button_pressed = '1'sinon start_button_pressed = '0'
    start_button_pressed <= '1' when start_button_sync = G_START_BUTTON_ACTIVE_LEVEL else '0';
	 
	 --Il s’exécute à chaque front montant de l’horloge 50 MHz.
    process (clock_50_i)
    begin
        if rising_edge(clock_50_i) then
		  
            if core_rst = '1' then
					--Au reset on force le bouton à l’état non appuyé
                start_button_meta    <= not G_START_BUTTON_ACTIVE_LEVEL;
                start_button_sync    <= not G_START_BUTTON_ACTIVE_LEVEL;
                start_button_prev    <= '0';
                start_pulse          <= '0';
                start_pending        <= '0';
                start_delay_counter  <=  0 ;
                sync_pulse_active    <= '0';
                sync_pulse_counter   <=  0 ;
            else
					 --A chaque front d’horloge
                start_button_meta <= start_button_i;			--On échantillonne le bouton
                start_button_sync <= start_button_meta;		--On passe dans une deuxième bascule
                start_button_prev <= start_button_pressed;	--On garde la valeur précédente pour détecter un front
                start_pulse       <= '0';							--Cela veut dire que start_pulse est normalement à 0, et il ne sera mis à 1 que dans un cas précis, pendant un cycle

					 --Gestion du pulse de synchronisation
                if sync_pulse_active = '1' then
                    if sync_pulse_counter = G_SYNC_PULSE_CLKS - 1 then
                        sync_pulse_active  <= '0';
                        sync_pulse_counter <=  0 ;
                    else
                        sync_pulse_counter <= sync_pulse_counter + 1;
                    end if;
                end if;

					 --Gestion du délai avant le vrai start
                if start_pending = '1' and sync_pulse_active = '0' then					--Un démarrage a été demandé et la sync est terminée
                    if start_delay_counter = G_START_AFTER_SYNC_DELAY_CLKS - 1 then
                        start_pending       <= '0'; --Attente terminée
                        start_delay_counter <=  0 ;
                        start_pulse         <= '1'; --On envoie le vrai pulse de démarrage au cœur
                    else
                        start_delay_counter <= start_delay_counter + 1;
                    end if;
                end if;

                if start_button_pressed = '1' and start_button_prev = '0' and	--On vient juste de détecter un nouvel appui
                   start_pending = '0' and sync_pulse_active = '0' and core_busy = '0' then
                    start_pending       <= '1';	--Un démarrage est maintenant demandé
                    start_delay_counter <=  0 ;	--On remet le compteur à zéro
                    sync_pulse_active   <= '1';	--On lance le burst de synchronisation
                    sync_pulse_counter  <=  0 ;	--Compteur de sync remis à zéro
                end if;
            end if;
        end if;
    end process;

    burst_sync_o <= sync_pulse_active or core_restart_sync;
    ledr_o       <= core_ledr;			--Les LEDs de sortie reçoivent les valeurs produites par le bloc principal

    u_core : entity work.fpga1_top
        generic map (
            G_CLOCK_FREQ_HZ      => G_CLOCK_FREQ_HZ,
            G_BAUD_RATE          => G_BAUD_RATE,
            G_RESTART_PULSE_CLKS => G_AUTO_RESTART_PULSE_CLKS,
            G_RESTART_DELAY_CLKS => G_START_AFTER_SYNC_DELAY_CLKS
        )
        port map (
            clk       => clock_50_i,
            rst       => core_rst,
            start_i   => start_pulse,
            ledr_o    => core_ledr,
            busy_o    => core_busy,
            restart_o => core_restart_sync,
            hex5_n_o  => hex5_n_o,
            hex4_n_o  => hex4_n_o,
            hex3_n_o  => hex3_n_o,
            hex2_n_o  => hex2_n_o,
            hex1_n_o  => hex1_n_o,
            hex0_n_o  => hex0_n_o,
            uart_tx_o => uart_tx_o
        );
end architecture rtl;

--NOTE: := → je mets une valeur dedans parcontre => → je relie un nom à une valeur/signal
