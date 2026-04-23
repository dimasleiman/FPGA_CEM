--fpga_1 son rôle:
--Attendre un signal start_i
--Puis envoyer des données sur l’UART
--Ces données correspondent à une valeur de compteur
--Il envoie une valeur, attend la fin de transmission, passe à la suivante, puis recommence
--Quand il arrive a la valeur maximale, il remet le compteur a zero et recommence

--Ce module est une machine d’états qui envoie une suite de valeurs de compteur sur l’UART après un signal de démarrage.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.dual_fpga_system_pkg.all;

entity fpga1_top is
    generic (
        G_CLOCK_FREQ_HZ      : positive := 50_000_000;
        G_BAUD_RATE          : positive := 115_200;
        G_RESTART_PULSE_CLKS : positive := 4;
        G_RESTART_DELAY_CLKS : positive := 50_000
    );
    port (
        clk       : in  std_logic;
        rst       : in  std_logic;
        start_i   : in  std_logic;
        ledr_o    : out std_logic_vector(9 downto 0);
        busy_o    : out std_logic;
        restart_o : out std_logic;
        hex5_n_o  : out std_logic_vector(6 downto 0);
        hex4_n_o  : out std_logic_vector(6 downto 0);
        hex3_n_o  : out std_logic_vector(6 downto 0);
        hex2_n_o  : out std_logic_vector(6 downto 0);
        hex1_n_o  : out std_logic_vector(6 downto 0);
        hex0_n_o  : out std_logic_vector(6 downto 0);
        uart_tx_o : out std_logic
    );
end entity fpga1_top;

architecture rtl of fpga1_top is
    constant C_BYTE_GAP_CLKS : natural := G_CLOCK_FREQ_HZ / G_BAUD_RATE;	--Cette constante donne le nombre de cycles d’horloge à attendre entre deux octets.
    --Vaut environ 434 cycles
	 constant C_COUNTER_MAX   : t_counter := (others => '1');

	 --FSM
    type t_state is (ST_IDLE, ST_WAIT_GAP, ST_START_TX, ST_WAIT_TX_BUSY, ST_WAIT_TX_DONE,
                     ST_RESTART_PULSE, ST_RESTART_DELAY);
	 -- ST_IDLE 		  : État repos.
	 -- ST_WAIT_GAP 	  : Le module attend un petit délai avant de lancer la transmission du prochain octet.
	 -- ST_START_TX 	  : Le module charge les données dans l’UART et déclenche la transmission.
	 -- ST_WAIT_TX_BUSY : Le module attend que l’émetteur UART confirme qu’il a bien commencé à transmettre.
	 -- ST_WAIT_TX_DONE : Le module attend que la transmission soit terminée.

    signal state            : t_state := ST_IDLE;
    signal counter_reg      : t_counter := (others => '0');	-- Il contient la valeur qui sera envoyée sur l’UART. Au début il vaut 0.
    signal byte_gap_counter : natural range 0 to C_BYTE_GAP_CLKS - 1 := 0; -- Compteur utilisé pour attendre entre deux transmissions.
    signal uart_data        : t_uart_byte := (others => '0');	-- C’est la donnée à transmettre
    signal uart_start       : std_logic := '0';	-- Signal de commande pour dire au bloc UART :“commence à transmettre maintenant”
    signal uart_busy        : std_logic := '0';	-- Signal venant du bloc UART.
    signal restart_pulse_counter : natural range 0 to G_RESTART_PULSE_CLKS - 1 := 0;
    signal restart_delay_counter : natural range 0 to G_RESTART_DELAY_CLKS - 1 := 0;
    signal restart_o_reg         : std_logic := '0';
begin
    assert C_BYTE_GAP_CLKS > 0
        report "fpga1_top requires G_CLOCK_FREQ_HZ / G_BAUD_RATE to be at least 1."
        severity failure;

    u_uart_tx : entity work.uart_tx		
        generic map (
            G_CLOCK_FREQ_HZ => G_CLOCK_FREQ_HZ,
            G_BAUD_RATE     => G_BAUD_RATE
        )
        port map (
            clk     => clk,
            rst     => rst,
            data_in => uart_data,
            start   => uart_start,
            tx      => uart_tx_o,	--tx : la ligne série physique
            busy    => uart_busy
        );

    process (clk)
    begin
        if rising_edge(clk) then	 --C’est un process synchrone. Tout change sur front montant d’horloge.
            if rst = '1' then
                state            <= ST_IDLE;
                counter_reg      <= (others => '0');
                byte_gap_counter <= 0;
                uart_data        <= (others => '0');
                uart_start       <= '0';
                restart_pulse_counter <=  0 ;
                restart_delay_counter <=  0 ;
                restart_o_reg         <= '0';
            else
                uart_start <= '0';
                restart_o_reg <= '0';

                case state is
					     -- 1.Quand on reçoit l’ordre de démarrage, on ne transmet pas immédiatement. On commence d’abord par attendre un petit délai.
                    when ST_IDLE =>
                        counter_reg      <= (others => '0');
                        byte_gap_counter <= 0;

                        if start_i = '1' then
                            state <= ST_WAIT_GAP;
                        end if;

						  -- 2.Cet état sert de temporisation entre les transmissions.
                    when ST_WAIT_GAP =>
                        if byte_gap_counter = C_BYTE_GAP_CLKS - 1 then
                            byte_gap_counter <= 0;
                            state            <= ST_START_TX;
                        else
                            byte_gap_counter <= byte_gap_counter + 1;
                        end if;
						  -- 3.C’est l’état où la transmission commence.
                    when ST_START_TX =>
                        uart_data  <= std_logic_vector(counter_reg); --On prend la valeur du compteur et on la place dans uart_data. Donc l’octet à envoyer est la valeur de counter_reg.
                        uart_start <= '1';									--On donne l’ordre au bloc UART de commencer la transmission
                        state      <= ST_WAIT_TX_BUSY;					--on passe à l’état suivant pour attendre la confirmation que l’UART est bien occupé.
						  -- 4.Le contrôleur attend que uart_tx réagisse au signal start
                    when ST_WAIT_TX_BUSY =>
                        if uart_busy = '1' then			--L’UART a bien pris la demande et a commencé à transmettre
                            state <= ST_WAIT_TX_DONE;
                        end if;
						  -- 5.Cet état attend la fin complète de la transmission
                    when ST_WAIT_TX_DONE =>
                        if uart_busy = '0' then							--La transmission est terminée.
								
									 --Cas 1 : le compteur a atteint sa valeur maximale
                            if counter_reg = C_COUNTER_MAX then
                                -- Reset local de la sequence avant la prochaine boucle.
                                counter_reg           <= (others => '0');
                                byte_gap_counter      <= 0;
                                restart_pulse_counter <= 0;
                                restart_delay_counter <= 0;
                                state                 <= ST_RESTART_PULSE;
                            else 
                                counter_reg      <= next_counter_value(counter_reg);
                                byte_gap_counter <= 0;
                                state            <= ST_WAIT_GAP;
                            end if;
                        end if;
                    when ST_RESTART_PULSE =>
                        restart_o_reg <= '1';

                        if restart_pulse_counter = G_RESTART_PULSE_CLKS - 1 then
                            restart_pulse_counter <= 0;
                            state                 <= ST_RESTART_DELAY;
                        else
                            restart_pulse_counter <= restart_pulse_counter + 1;
                        end if;

                    when ST_RESTART_DELAY =>
                        if restart_delay_counter = G_RESTART_DELAY_CLKS - 1 then
                            restart_delay_counter <= 0;
                            byte_gap_counter      <= 0;
                            state                 <= ST_WAIT_GAP;
                        else
                            restart_delay_counter <= restart_delay_counter + 1;
                        end if;
                end case;
            end if;
        end if;
    end process;

    ledr_o <= (others => '0');
    busy_o <= '1' when state /= ST_IDLE else '0';
    restart_o <= restart_o_reg;
    hex5_n_o <= C_HEX_OFF_N;
    hex4_n_o <= C_HEX_OFF_N;
    hex3_n_o <= C_HEX_OFF_N;
    hex2_n_o <= C_HEX_OFF_N;
    hex1_n_o <= C_HEX_OFF_N;
    hex0_n_o <= C_HEX_OFF_N;
end architecture rtl;
