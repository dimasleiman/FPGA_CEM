library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.dual_fpga_system_pkg.all;
use work.fpga1_pkg.all;

entity fpga1_top is
    generic (
        G_CLOCK_FREQ_HZ         : positive := 50_000_000;
        G_BAUD_RATE             : positive := 115_200;
        G_SENSOR_UPDATE_DIVIDER : positive := 5_000_000;
        G_SENSOR_STEP           : positive := 17;
        G_SOURCE_IS_ADC         : std_logic := C_FAKE_SENSOR_SOURCE_IS_ADC
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

    signal raw_sample             : t_sample := (others => '0');
    signal raw_sample_valid       : std_logic := '0';
    signal normalized_sample      : t_sample := (others => '0');
    signal normalized_sample_valid : std_logic := '0';
    signal sample_range_ok        : std_logic := '0';
    signal sample_range_error     : std_logic := '1';
    signal sensor_state           : t_sensor_state := C_SENSOR_STATE_INVALID;

    signal latched_sample         : t_sample := (others => '0');
    signal latched_range_ok       : std_logic := '0';
    signal latched_sensor_state   : t_sensor_state := C_SENSOR_STATE_INVALID;

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
            sample_value => raw_sample,
            sample_valid => raw_sample_valid
        );

    u_sample_normalizer : entity work.sample_normalizer
        port map (
            sample_in      => raw_sample,
            sample_valid_i => raw_sample_valid,
            sample_out     => normalized_sample,
            sample_valid_o => normalized_sample_valid
        );

    u_sample_validator : entity work.sample_validator
        port map (
            sample_value => normalized_sample,
            sample_valid => normalized_sample_valid,
            range_ok     => sample_range_ok,
            range_error  => sample_range_error
        );

    u_sample_classifier : entity work.sample_classifier
        port map (
            sample_value => normalized_sample,
            sample_valid => normalized_sample_valid,
            range_ok     => sample_range_ok,
            sensor_state => sensor_state
        );

    u_frame_builder : entity work.frame_builder
        port map (
            clk           => clk,
            rst           => rst,
            load_frame    => frame_load,
            sample_value  => latched_sample,
            sensor_state  => latched_sensor_state,
            range_ok      => latched_range_ok,
            source_is_adc => G_SOURCE_IS_ADC,
            byte_index    => frame_byte_index,
            byte_out      => frame_byte,
            frame_ready   => frame_ready
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
                latched_sample       <= (others => '0');
                latched_range_ok     <= '0';
                latched_sensor_state <= C_SENSOR_STATE_INVALID;
                frame_load           <= '0';
                frame_byte_index     <= (others => '0');
                uart_data            <= (others => '0');
                uart_start           <= '0';
                tx_state             <= ST_IDLE;
            else
                frame_load <= '0';
                uart_start <= '0';

                case tx_state is
                    when ST_IDLE =>
                        frame_byte_index <= (others => '0');

                        if normalized_sample_valid = '1' then
                            -- Capture one complete sample and its status before
                            -- building the outgoing UART frame.
                            latched_sample       <= normalized_sample;
                            latched_range_ok     <= sample_range_ok and (not sample_range_error);
                            latched_sensor_state <= sensor_state;
                            tx_state             <= ST_LOAD_FRAME;
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
