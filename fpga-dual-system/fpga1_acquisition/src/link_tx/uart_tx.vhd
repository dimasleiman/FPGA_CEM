--Ce module uart_tx sert à envoyer un octet sur une ligne UART.
--Quand start = 1 :
	--il mémorise data_in
	--il envoie un bit de start à 0
	--il envoie ensuite les 8 bits de la donnée
	--il termine par un bit de stop à 1
--puis il revient au repos

--Pendant tout l’envoi :busy = 1
--Quand il a fini :busy = 0

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.dual_fpga_system_pkg.all;

entity uart_tx is
    generic (
        G_CLOCK_FREQ_HZ : positive := 50_000_000;
        G_BAUD_RATE     : positive := 115_200
    );
    port (
        clk     : in  std_logic;
        rst     : in  std_logic;
        data_in : in  t_uart_byte;	--Octet à transmettre
        start   : in  std_logic;
        tx      : out std_logic;
        busy    : out std_logic
    );
end entity uart_tx;

architecture rtl of uart_tx is
    constant C_BIT_TICKS : natural := G_CLOCK_FREQ_HZ / G_BAUD_RATE;

    type t_state is (ST_IDLE, ST_START, ST_DATA, ST_STOP);
	 --ST_IDLE : État repos. La ligne UART vaut 1 au repos.
	 --ST_START : Envoi du bit de start.
	 --ST_DATA : Envoi des 8 bits de données.
	 --ST_STOP : Envoi du bit de stop.

    signal state      : t_state := ST_IDLE;
    signal baud_count : natural range 0 to C_BIT_TICKS - 1 := 0;	--Compteur de temps pour tenir un bit pendant la bonne durée.Quand il arrive à la fin, on passe au bit suivant ou à l’état suivant.
    signal bit_index  : natural range 0 to 7 := 0;
    signal shift_reg  : t_uart_byte := (others => '0');				--Registre qui mémorise l’octet à transmettre.
    signal tx_reg     : std_logic := '1';
    signal busy_reg   : std_logic := '0';
begin
    assert C_BIT_TICKS > 0
        report "uart_tx requires G_CLOCK_FREQ_HZ / G_BAUD_RATE to be at least 1."
        severity failure;

	 --C’est un process synchrone, exécuté à chaque front montant.
    process (clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                state      <= ST_IDLE;
                baud_count <=  0 ;
                bit_index  <=  0 ;
                shift_reg  <= (others => '0');
                tx_reg     <= '1';
                busy_reg   <= '0';
            else
                case state is
						  -- 1..
                    when ST_IDLE =>
                        tx_reg     <= '1';
                        busy_reg   <= '0';
                        baud_count <=  0 ;
                        bit_index  <=  0 ;

                        if start = '1' then
                            -- Latch the byte and begin the start bit.
                            shift_reg <= data_in;
                            tx_reg    <= '0';
                            busy_reg  <= '1';
                            state     <= ST_START;
                        end if;
								
						  -- 2.Cet état maintient le bit de start pendant toute sa durée
                    when ST_START =>
                        busy_reg <= '1';

                        if baud_count = C_BIT_TICKS - 1 then
                            baud_count <= 0;
                            bit_index  <= 0;
                            tx_reg     <= shift_reg(0);
                            state      <= ST_DATA;
                        else
                            baud_count <= baud_count + 1;
                        end if;
								
						  -- 3.Dans cet état, le module envoie les 8 bits de données un par un.
                    when ST_DATA =>
                        busy_reg <= '1';

                        if baud_count = C_BIT_TICKS - 1 then
                            baud_count <= 0;

									 --Cas 1 : on vient d’envoyer le dernier bit (bit_index = 7)
                            if bit_index = 7 then
                                tx_reg <= '1';
                                state  <= ST_STOP;
                            else
									 --Cas 2 : il reste encore des bits
                                bit_index <= bit_index + 1;
                                tx_reg    <= shift_reg(bit_index + 1);
                            end if;
                        else 
                            baud_count <= baud_count + 1;
                        end if;

						  -- 4.Ici on maintient le bit de stop à 1.
                    when ST_STOP =>
                        busy_reg <= '1';

                        if baud_count = C_BIT_TICKS - 1 then
                            baud_count <=  0 ;
                            tx_reg     <= '1';
                            busy_reg   <= '0';
                            state      <= ST_IDLE;
                        else
                            baud_count <= baud_count + 1;
                        end if;
                end case;
            end if;
        end if;
    end process;

    tx   <= tx_reg;
    busy <= busy_reg;
end architecture rtl;