library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.fpga1_pkg.all;

entity fpga1_top is
    generic (
        G_CLOCK_FREQ_HZ         : positive := 50_000_000;
        G_BAUD_RATE             : positive := 115_200;
        G_SENSOR_UPDATE_DIVIDER : positive := 5_000_000;
        G_SENSOR_STEP           : positive := 17
    );
    port (
        clk       : in  std_logic;
        rst       : in  std_logic;
        uart_tx_o : out std_logic
    );
end entity fpga1_top;

architecture rtl of fpga1_top is
    type t_tx_state is (
        ST_IDLE,
        ST_LOAD_FRAME,
        ST_WAIT_FRAME_READY,
        ST_START_BYTE,
        ST_WAIT_UART_BUSY,
        ST_WAIT_UART_DONE
    );

    signal sensor_sample    : t_sample := (others => '0');
    signal sensor_valid     : std_logic := '0';
    signal warning_flag     : std_logic := '0';
    signal error_flag       : std_logic := '0';

    signal latched_sample   : t_sample := (others => '0');
    signal latched_warning  : std_logic := '0';
    signal latched_error    : std_logic := '0';

    signal frame_load       : std_logic := '0';
    signal frame_ready      : std_logic := '0';
    signal frame_byte_index : unsigned(2 downto 0) := (others => '0');
    signal frame_byte       : t_uart_byte := (others => '0');

    signal uart_data        : t_uart_byte := (others => '0');
    signal uart_start       : std_logic := '0';
    signal uart_busy        : std_logic := '0';

    signal tx_state         : t_tx_state := ST_IDLE;
begin
    u_fake_sensor_gen : entity work.fake_sensor_gen
        generic map (
            G_UPDATE_DIVIDER => G_SENSOR_UPDATE_DIVIDER,
            G_STEP           => G_SENSOR_STEP
        )
        port map (
            clk          => clk,
            rst          => rst,
            sample_value => sensor_sample,
            sample_valid => sensor_valid
        );

    u_threshold_detector : entity work.threshold_detector
        port map (
            sample_value => sensor_sample,
            sample_valid => sensor_valid,
            warning_flag => warning_flag,
            error_flag   => error_flag
        );

    u_frame_builder : entity work.frame_builder
        port map (
            clk          => clk,
            rst          => rst,
            load_frame   => frame_load,
            sample_value => latched_sample,
            warning_flag => latched_warning,
            error_flag   => latched_error,
            byte_index   => frame_byte_index,
            byte_out     => frame_byte,
            frame_ready  => frame_ready
        );

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
            tx      => uart_tx_o,
            busy    => uart_busy
        );

    process (clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                latched_sample   <= (others => '0');
                latched_warning  <= '0';
                latched_error    <= '0';
                frame_load       <= '0';
                frame_byte_index <= (others => '0');
                uart_data        <= (others => '0');
                uart_start       <= '0';
                tx_state         <= ST_IDLE;
            else
                frame_load <= '0';
                uart_start <= '0';

                case tx_state is
                    when ST_IDLE =>
                        frame_byte_index <= (others => '0');

                        if sensor_valid = '1' then
                            -- Capture one complete sample and its status before
                            -- building the outgoing UART frame.
                            latched_sample  <= sensor_sample;
                            latched_warning <= warning_flag;
                            latched_error   <= error_flag;
                            tx_state        <= ST_LOAD_FRAME;
                        end if;

                    when ST_LOAD_FRAME =>
                        frame_load       <= '1';
                        frame_byte_index <= (others => '0');
                        tx_state         <= ST_WAIT_FRAME_READY;

                    when ST_WAIT_FRAME_READY =>
                        if frame_ready = '1' then
                            tx_state <= ST_START_BYTE;
                        end if;

                    when ST_START_BYTE =>
                        if uart_busy = '0' then
                            -- Present the selected frame byte to uart_tx and
                            -- pulse start for one clock cycle.
                            uart_data  <= frame_byte;
                            uart_start <= '1';
                            tx_state   <= ST_WAIT_UART_BUSY;
                        end if;

                    when ST_WAIT_UART_BUSY =>
                        if uart_busy = '1' then
                            tx_state <= ST_WAIT_UART_DONE;
                        end if;

                    when ST_WAIT_UART_DONE =>
                        if uart_busy = '0' then
                            if to_integer(frame_byte_index) = C_FRAME_BYTE_COUNT - 1 then
                                tx_state <= ST_IDLE;
                            else
                                frame_byte_index <= frame_byte_index + 1;
                                tx_state         <= ST_START_BYTE;
                            end if;
                        end if;
                end case;
            end if;
        end if;
    end process;
end architecture rtl;
