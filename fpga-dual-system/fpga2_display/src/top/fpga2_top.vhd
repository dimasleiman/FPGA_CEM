--Son rôle est de :
-- 1.Recevoir les octets venant de l’UART
-- 2.Vérifier si les valeurs reçues suivent bien la séquence attendue 0, 1, 2, 3, ...
-- 3.Compter le nombre d’erreurs
-- 4.Afficher ce nombre sur les afficheurs 7 segments
-- 5.Faire clignoter des LEDs si une erreur a déjà été détectée
-- 6.Faire un petit flash après un restart_i
--Donc FPGA2 sert ici surtout de récepteur + vérificateur.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.dual_fpga_system_pkg.all;

entity fpga2_top is
    generic (
        G_CLOCK_FREQ_HZ             : positive := 50_000_000;
        G_BAUD_RATE                 : positive := 115_200;
        G_ERROR_BLINK_TOGGLE_CLKS   : positive := 12_500_000;	--Vitesse de clignotement des LEDs d’erreur
        G_RESET_FLASH_TOGGLE_CLKS   : positive := 2_500_000;	--Vitesse du flash après restart
        G_RESET_FLASH_DURATION_CLKS : positive := 50_000_000	--Durée totale du flash après restart
    );
    port (
        clk       : in  std_logic;
        rst       : in  std_logic;
        restart_i : in  std_logic;
        manual_reset_flash_i : in  std_logic;
        uart_rx_i : in  std_logic;
        ledr_o    : out std_logic_vector(9 downto 0);
        hex5_n_o  : out std_logic_vector(6 downto 0);
        hex4_n_o  : out std_logic_vector(6 downto 0);
        hex3_n_o  : out std_logic_vector(6 downto 0);
        hex2_n_o  : out std_logic_vector(6 downto 0);
        hex1_n_o  : out std_logic_vector(6 downto 0);
        hex0_n_o  : out std_logic_vector(6 downto 0)
    );
end entity fpga2_top;

architecture rtl of fpga2_top is
    constant C_COUNTER_MAX       : t_counter := (others => '1');		--Valeur maximale du compteur attendu.
    constant C_ERROR_COUNT_MAX   : natural := 2 ** C_COUNTER_WIDTH;	--Nombre maximal d’erreurs représentable ici. Peux monter jusqu'a 256 error
    constant C_ERROR_COUNT_WIDTH : positive := C_COUNTER_WIDTH + 1;	--Si le compteur fait 8 bits, le nombre d’erreurs est codé sur 9 bits. C’est logique, car pour représenter 256, 8 bits ne suffisent pas.
    constant C_ERROR_DIGITS      : positive := 3;							--Nombre de chiffres décimaux affichés.
    constant C_RX_ACTIVITY_HOLD_CLKS : positive := 10_000;				--Maintient LEDR1 allumée un court instant après chaque octet reçu.

    type t_state is (ST_IDLE, ST_RECEIVING);
	 --ST_IDLE: Le système attend le début d’une nouvelle séquence.
	 --ST_RECEIVING: Le système est en train de recevoir une séquence d’octets.

    signal state             : t_state := ST_IDLE;
    signal rx_data           : t_uart_byte := (others => '0');
    signal rx_valid          : std_logic := '0';					--Chaque fois que rx_valid = 1, on peut traiter rx_data.
    signal expected_counter  : t_counter := (others => '0');	--Valeur que le FPGA2 s’attend à recevoir
    signal error_count       : natural range 0 to C_ERROR_COUNT_MAX := 0;
    signal any_error_latched : std_logic := '0';					--Indique si au moins une erreur a déjà été vue.
    signal blink_counter     : natural range 0 to G_ERROR_BLINK_TOGGLE_CLKS - 1 := 0;	--Compteur qui détermine quand on change l’état de clignotement des LEDs d’erreur.
    signal blink_led         : std_logic := '0';					--État logique du clignotement des LEDs d’erreur.
    signal reset_flash_active : std_logic := '0';					--Indique si le flash visuel après restart_i est encore actif.
    signal reset_flash_counter : natural range 0 to G_RESET_FLASH_DURATION_CLKS - 1 := 0;	--Compteur de durée totale du flash.
    signal reset_flash_toggle_counter : natural range 0 to G_RESET_FLASH_TOGGLE_CLKS - 1 := 0;	--Compteur de vitesse de clignotement du flash.
    signal reset_flash_led   : std_logic := '0';
    signal error_count_bin   : std_logic_vector(C_ERROR_COUNT_WIDTH - 1 downto 0) := (others => '0');	--Version binaire de error_count sur largeur fixe.
    signal error_count_bcd   : std_logic_vector((C_ERROR_DIGITS * 4) - 1 downto 0) := (others => '0');	--BCD veut dire que chaque chiffre décimal est codé sur 4 bits.
    signal rx_activity_counter : natural range 0 to C_RX_ACTIVITY_HOLD_CLKS := 0;
    signal rx_rst            : std_logic := '1';		--Reset local du récepteur UART.
begin
    rx_rst <= rst or restart_i;

    u_uart_rx : entity work.uart_rx
        generic map (
            G_CLOCK_FREQ_HZ => G_CLOCK_FREQ_HZ,
            G_BAUD_RATE     => G_BAUD_RATE
        )
        port map (
            clk        => clk,
            rst        => rx_rst,
            rx         => uart_rx_i,
            data_out   => rx_data,
            data_valid => rx_valid
        );

    u_error_count_bcd : entity work.bin_to_bcd	--Ce bloc convertit le nombre d’erreurs en BCD.
        generic map (
            G_INPUT_WIDTH => C_ERROR_COUNT_WIDTH,
            G_DIGIT_COUNT => C_ERROR_DIGITS
        )
        port map (
            binary_i => error_count_bin,
            bcd_o    => error_count_bcd
        );

    u_hex2 : entity work.digit_to_7seg_decimal_n
        port map (
            digit_i => error_count_bcd(11 downto 8),
            seg_n_o => hex2_n_o
        );

    u_hex1 : entity work.digit_to_7seg_decimal_n
        port map (
            digit_i => error_count_bcd(7 downto 4),
            seg_n_o => hex1_n_o
        );

    u_hex0 : entity work.digit_to_7seg_decimal_n
        port map (
            digit_i => error_count_bcd(3 downto 0),
            seg_n_o => hex0_n_o
        );

    error_count_bin <= std_logic_vector(to_unsigned(error_count, C_ERROR_COUNT_WIDTH));

	 --C’est la logique séquentielle principale.
	 --Les variables servent à calculer les valeurs du cycle courant proprement avant d’écrire les signaux.
    process (clk)
        variable current_expected : t_counter;
        variable next_error_count : natural range 0 to C_ERROR_COUNT_MAX;
        variable next_any_error   : std_logic;
    begin
        if rising_edge(clk) then
            if rst = '1' then
                state             <= ST_IDLE;
                expected_counter  <= (others => '0');
                error_count       <=  0 ;
                any_error_latched <= '0';
                blink_counter     <=  0 ;
                blink_led         <= '0';		--blink_led est une sorte d’horloge lente visuelle. Ensuite il sera utilisé pour piloter les LEDs d’erreur.
                reset_flash_active <= '0';
                reset_flash_counter <= 0;
                reset_flash_toggle_counter <= 0;
                reset_flash_led   <= '0';
                rx_activity_counter <= 0;
            elsif restart_i = '1' then
                state             <= ST_IDLE;
                expected_counter  <= (others => '0');
                rx_activity_counter <= 0;
            elsif manual_reset_flash_i = '1' then
                state             <= ST_IDLE;
                expected_counter  <= (others => '0');
                error_count       <=  0 ;
                any_error_latched <= '0';
                blink_counter     <= 0;
                blink_led         <= '0';
                reset_flash_active <= '1';
                reset_flash_counter <= 0;
                reset_flash_toggle_counter <= 0;
                reset_flash_led   <= '1';
                rx_activity_counter <= 0;
            else
                if blink_counter = G_ERROR_BLINK_TOGGLE_CLKS - 1 then
                    blink_counter <= 0;
                    blink_led     <= not blink_led;
                else
                    blink_counter <= blink_counter + 1;
                end if;

                if reset_flash_active = '1' then
                    if reset_flash_counter = G_RESET_FLASH_DURATION_CLKS - 1 then
                        reset_flash_active <= '0';
                        reset_flash_counter <= 0;
                        reset_flash_toggle_counter <= 0;
                        reset_flash_led <= '0';
                    else
                        reset_flash_counter <= reset_flash_counter + 1;

                        if reset_flash_toggle_counter = G_RESET_FLASH_TOGGLE_CLKS - 1 then
                            reset_flash_toggle_counter <= 0;
                            reset_flash_led <= not reset_flash_led;
                        else
                            reset_flash_toggle_counter <= reset_flash_toggle_counter + 1;
                        end if;
                    end if;
                end if;

                if rx_valid = '1' then
                    rx_activity_counter <= C_RX_ACTIVITY_HOLD_CLKS;
                elsif rx_activity_counter > 0 then
                    rx_activity_counter <= rx_activity_counter - 1;
                end if;

                if rx_valid = '1' then			--Chaque fois qu’un octet est reçu, ce bloc s’exécute.
                    if state = ST_IDLE then	--Déterminer la valeur attendue et l’état de départ
                        current_expected := (others => '0');
                        next_error_count := error_count;
                        next_any_error   := any_error_latched;
                    else
                        current_expected := expected_counter;
                        next_error_count := error_count;
                        next_any_error   := any_error_latched;
                    end if;

                    if unsigned(rx_data) /= current_expected then		--Vérification de l’octet reçu
                        if next_error_count < C_ERROR_COUNT_MAX then
                            next_error_count := next_error_count + 1;
                        end if;

                        next_any_error   := '1';
                    end if;

						  --Mise à jour des registres d’erreur
                    error_count       <= next_error_count;
                    any_error_latched <= next_any_error;
						  
						  --Réparation de la valeur attendue suivante
                    if current_expected = C_COUNTER_MAX then
                        state            <= ST_IDLE;
                        expected_counter <= (others => '0');
                    else
                        state            <= ST_RECEIVING;
                        expected_counter <= next_counter_value(current_expected);
                    end if;
                end if;
            end if;
        end if;
    end process;

    ledr_o(0)          <= reset_flash_led when reset_flash_active = '1' else '0';
    ledr_o(1)          <= '1' when rx_activity_counter > 0 else '0';
    ledr_o(9 downto 2) <= (others => blink_led) when any_error_latched = '1' else
                           (others => '0');
    hex5_n_o           <= C_HEX_OFF_N;
    hex4_n_o           <= C_HEX_OFF_N; 
    hex3_n_o           <= C_HEX_OFF_N;
end architecture rtl;
