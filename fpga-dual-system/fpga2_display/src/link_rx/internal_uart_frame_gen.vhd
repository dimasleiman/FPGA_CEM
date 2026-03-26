library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.dual_fpga_system_pkg.all;

entity internal_uart_frame_gen is
    generic (
        G_CLOCK_FREQ_HZ            : positive  := 50_000_000;
        G_BAUD_RATE                : positive  := 115_200;
        G_FRAME_GAP_CLKS           : positive  := 5_000_000;
        G_SAMPLE_HOLD_FRAMES       : positive  := 20;
        G_SAMPLE_STEP              : positive  := 100;
        G_SOURCE_IS_ADC            : std_logic := '0';
        G_ENABLE_CORRUPT_FRAME_TEST : boolean  := false;
        G_CORRUPT_FRAME_PERIOD     : positive  := 8
    );
    port (
        clk        : in  std_logic;
        rst        : in  std_logic;
        uart_tx_o  : out std_logic
    );
end entity internal_uart_frame_gen;

architecture rtl of internal_uart_frame_gen is
    constant C_BIT_TICKS : natural := G_CLOCK_FREQ_HZ / G_BAUD_RATE;
    constant C_MIN_SAMPLE : unsigned(C_SAMPLE_WIDTH - 1 downto 0) :=
        to_unsigned(C_SENSOR_MIN_CODE, C_SAMPLE_WIDTH);
    constant C_MAX_SAMPLE : unsigned(C_SAMPLE_WIDTH - 1 downto 0) :=
        to_unsigned(C_SENSOR_MAX_CODE, C_SAMPLE_WIDTH);
    constant C_STEP_VALUE : unsigned(C_SAMPLE_WIDTH - 1 downto 0) :=
        to_unsigned(G_SAMPLE_STEP, C_SAMPLE_WIDTH);

    type t_uart_state is (
        ST_IDLE,
        ST_START,
        ST_DATA,
        ST_STOP
    );

    signal sample_reg         : unsigned(C_SAMPLE_WIDTH - 1 downto 0) := C_MIN_SAMPLE;
    signal ramp_up_reg        : std_logic := '1';
    signal sequence_reg       : t_uart_byte := (others => '0');
    signal gap_counter        : natural range 0 to G_FRAME_GAP_CLKS - 1 := 0;
    signal sample_hold_count  : natural range 0 to G_SAMPLE_HOLD_FRAMES - 1 := 0;
    signal corrupt_count      : natural range 0 to G_CORRUPT_FRAME_PERIOD - 1 := 0;
    signal frame_pending_reg  : std_logic := '0';
    signal frame_bytes_reg    : t_uart_byte_array(0 to C_FRAME_BYTE_COUNT - 1) := (others => (others => '0'));
    signal byte_index_reg     : natural range 0 to C_FRAME_BYTE_COUNT - 1 := 0;
    signal uart_state         : t_uart_state := ST_IDLE;
    signal baud_count         : natural range 0 to C_BIT_TICKS - 1 := 0;
    signal bit_index          : natural range 0 to 7 := 0;
    signal shift_reg          : t_uart_byte := (others => '0');
    signal tx_reg             : std_logic := '1';
begin
    assert C_BIT_TICKS > 0
        report "internal_uart_frame_gen requires G_CLOCK_FREQ_HZ / G_BAUD_RATE to be at least 1."
        severity failure;
    assert G_SAMPLE_STEP < (2 ** C_SAMPLE_WIDTH)
        report "internal_uart_frame_gen requires G_SAMPLE_STEP to fit within the sample width."
        severity failure;

    process (clk)
        variable sample_value_v : t_sample;
        variable range_ok_v     : std_logic;
        variable sensor_state_v : t_sensor_state;
        variable flags_v        : t_uart_byte;
        variable crc_input_v    : t_uart_byte_array(0 to 4);
        variable crc_value_v    : t_uart_byte;
    begin
        if rising_edge(clk) then
            if rst = '1' then
                sample_reg        <= C_MIN_SAMPLE;
                ramp_up_reg       <= '1';
                sequence_reg      <= (others => '0');
                gap_counter       <= 0;
                sample_hold_count <= 0;
                corrupt_count     <= 0;
                frame_pending_reg <= '0';
                frame_bytes_reg   <= (others => (others => '0'));
                byte_index_reg    <= 0;
                uart_state        <= ST_IDLE;
                baud_count        <= 0;
                bit_index         <= 0;
                shift_reg         <= (others => '0');
                tx_reg            <= '1';
            else
                case uart_state is
                    when ST_IDLE =>
                        tx_reg <= '1';

                        if frame_pending_reg = '1' then
                            shift_reg   <= frame_bytes_reg(byte_index_reg);
                            baud_count  <= 0;
                            bit_index   <= 0;
                            tx_reg      <= '0';
                            uart_state  <= ST_START;
                        elsif gap_counter = G_FRAME_GAP_CLKS - 1 then
                            gap_counter    <= 0;
                            frame_pending_reg <= '1';
                            byte_index_reg <= 0;

                            sample_value_v := std_logic_vector(sample_reg);
                            range_ok_v     := sample_range_ok(sample_value_v);
                            sensor_state_v := classify_sample(sample_value_v, range_ok_v);
                            flags_v        := sensor_state_to_flags(sensor_state_v, range_ok_v, G_SOURCE_IS_ADC);

                            crc_input_v(0) := C_FRAME_CONTROL;
                            crc_input_v(1) := sequence_reg;
                            crc_input_v(2) := "0000" & sample_value_v(C_SAMPLE_WIDTH - 1 downto 8);
                            crc_input_v(3) := sample_value_v(7 downto 0);
                            crc_input_v(4) := flags_v;
                            crc_value_v    := calc_crc8(crc_input_v);

                            frame_bytes_reg(0) <= C_FRAME_HEADER;
                            frame_bytes_reg(1) <= C_FRAME_CONTROL;
                            frame_bytes_reg(2) <= sequence_reg;
                            frame_bytes_reg(3) <= crc_input_v(2);
                            frame_bytes_reg(4) <= crc_input_v(3);
                            frame_bytes_reg(5) <= flags_v;
                            frame_bytes_reg(7) <= C_FRAME_FOOTER;

                            if G_ENABLE_CORRUPT_FRAME_TEST
                               and (corrupt_count = G_CORRUPT_FRAME_PERIOD - 1) then
                                frame_bytes_reg(6) <= not crc_value_v;
                                corrupt_count      <= 0;
                            else
                                frame_bytes_reg(6) <= crc_value_v;

                                if G_ENABLE_CORRUPT_FRAME_TEST then
                                    corrupt_count <= corrupt_count + 1;
                                else
                                    corrupt_count <= 0;
                                end if;
                            end if;

                            sequence_reg <= next_sequence(sequence_reg);

                            -- Keep transmitting frames continuously so FPGA2
                            -- stays in the GOOD state, but only change the
                            -- emulated received sample every few frames.
                            if sample_hold_count = G_SAMPLE_HOLD_FRAMES - 1 then
                                sample_hold_count <= 0;

                                if ramp_up_reg = '1' then
                                    if sample_reg >= C_MAX_SAMPLE - C_STEP_VALUE then
                                        sample_reg  <= C_MAX_SAMPLE;
                                        ramp_up_reg <= '0';
                                    else
                                        sample_reg <= sample_reg + C_STEP_VALUE;
                                    end if;
                                else
                                    if sample_reg <= C_MIN_SAMPLE + C_STEP_VALUE then
                                        sample_reg  <= C_MIN_SAMPLE;
                                        ramp_up_reg <= '1';
                                    else
                                        sample_reg <= sample_reg - C_STEP_VALUE;
                                    end if;
                                end if;
                            else
                                sample_hold_count <= sample_hold_count + 1;
                            end if;
                        else
                            gap_counter <= gap_counter + 1;
                        end if;

                    when ST_START =>
                        if baud_count = C_BIT_TICKS - 1 then
                            baud_count <= 0;
                            bit_index  <= 0;
                            tx_reg     <= shift_reg(0);
                            uart_state <= ST_DATA;
                        else
                            baud_count <= baud_count + 1;
                        end if;

                    when ST_DATA =>
                        if baud_count = C_BIT_TICKS - 1 then
                            baud_count <= 0;

                            if bit_index = 7 then
                                tx_reg     <= '1';
                                uart_state <= ST_STOP;
                            else
                                bit_index <= bit_index + 1;
                                tx_reg    <= shift_reg(bit_index + 1);
                            end if;
                        else
                            baud_count <= baud_count + 1;
                        end if;

                    when ST_STOP =>
                        if baud_count = C_BIT_TICKS - 1 then
                            baud_count <= 0;
                            tx_reg     <= '1';

                            if byte_index_reg = C_FRAME_BYTE_COUNT - 1 then
                                frame_pending_reg <= '0';
                                byte_index_reg    <= 0;
                            else
                                byte_index_reg <= byte_index_reg + 1;
                            end if;

                            uart_state <= ST_IDLE;
                        else
                            baud_count <= baud_count + 1;
                        end if;
                end case;
            end if;
        end if;
    end process;

    uart_tx_o <= tx_reg;
end architecture rtl;
