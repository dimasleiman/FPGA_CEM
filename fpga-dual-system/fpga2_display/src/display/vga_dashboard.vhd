library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.dual_fpga_system_pkg.all;

entity vga_dashboard is
    generic (
        G_ACTIVE_WIDTH  : positive := 640;
        G_ACTIVE_HEIGHT : positive := 480
    );
    port (
        clk                  : in  std_logic;
        rst                  : in  std_logic;
        pixel_ce             : in  std_logic;
        active_video         : in  std_logic;
        pixel_x              : in  unsigned(11 downto 0);
        pixel_y              : in  unsigned(11 downto 0);
        current_sensor_value : in  t_sample;
        current_sensor_state : in  t_sensor_state;
        comm_state           : in  t_comm_state;
        valid_frames         : in  t_counter;
        corrupted_frames     : in  t_counter;
        missing_frames       : in  t_counter;
        timeout_events       : in  t_counter;
        vga_r_o              : out std_logic_vector(3 downto 0);
        vga_g_o              : out std_logic_vector(3 downto 0);
        vga_b_o              : out std_logic_vector(3 downto 0)
    );
end entity vga_dashboard;

architecture rtl of vga_dashboard is
    function max_natural(left_value : natural; right_value : natural) return natural is
    begin
        if left_value > right_value then
            return left_value;
        end if;

        return right_value;
    end function max_natural;

    function max_positive(left_value : positive; right_value : positive) return positive is
    begin
        if left_value > right_value then
            return left_value;
        end if;

        return right_value;
    end function max_positive;

    function hex_segments(nibble : std_logic_vector(3 downto 0)) return std_logic_vector is
    begin
        case nibble is
            when "0000" => return "1111110";
            when "0001" => return "0110000";
            when "0010" => return "1101101";
            when "0011" => return "1111001";
            when "0100" => return "0110011";
            when "0101" => return "1011011";
            when "0110" => return "1011111";
            when "0111" => return "1110000";
            when "1000" => return "1111111";
            when "1001" => return "1111011";
            when "1010" => return "1110111";
            when "1011" => return "0011111";
            when "1100" => return "1001110";
            when "1101" => return "0111101";
            when "1110" => return "1001111";
            when others => return "1000111";
        end case;
    end function hex_segments;

    function in_rect(
        x_value : natural;
        y_value : natural;
        left_x  : natural;
        top_y   : natural;
        width_v : natural;
        height_v : natural
    ) return boolean is
    begin
        return (x_value >= left_x)
           and (x_value < left_x + width_v)
           and (y_value >= top_y)
           and (y_value < top_y + height_v);
    end function in_rect;

    function digit_pixel_on(
        x_value : natural;
        y_value : natural;
        left_x  : natural;
        top_y   : natural;
        nibble  : std_logic_vector(3 downto 0);
        scale_v : positive
    ) return boolean is
        constant C_DIGIT_WIDTH  : natural := 12 * scale_v;
        constant C_DIGIT_HEIGHT : natural := 20 * scale_v;
        constant C_THICKNESS    : natural := max_natural(2, 2 * scale_v);
        constant C_MID_Y        : natural := C_DIGIT_HEIGHT / 2;
        variable local_x        : natural;
        variable local_y        : natural;
        variable segments       : std_logic_vector(6 downto 0);
    begin
        if not in_rect(x_value, y_value, left_x, top_y, C_DIGIT_WIDTH, C_DIGIT_HEIGHT) then
            return false;
        end if;

        local_x  := x_value - left_x;
        local_y  := y_value - top_y;
        segments := hex_segments(nibble);

        if (segments(6) = '1')
           and (local_y < C_THICKNESS)
           and (local_x >= C_THICKNESS)
           and (local_x < C_DIGIT_WIDTH - C_THICKNESS) then
            return true;
        end if;

        if (segments(5) = '1')
           and (local_x >= C_DIGIT_WIDTH - C_THICKNESS)
           and (local_y >= C_THICKNESS)
           and (local_y < C_MID_Y) then
            return true;
        end if;

        if (segments(4) = '1')
           and (local_x >= C_DIGIT_WIDTH - C_THICKNESS)
           and (local_y >= C_MID_Y)
           and (local_y < C_DIGIT_HEIGHT - C_THICKNESS) then
            return true;
        end if;

        if (segments(3) = '1')
           and (local_y >= C_DIGIT_HEIGHT - C_THICKNESS)
           and (local_x >= C_THICKNESS)
           and (local_x < C_DIGIT_WIDTH - C_THICKNESS) then
            return true;
        end if;

        if (segments(2) = '1')
           and (local_x < C_THICKNESS)
           and (local_y >= C_MID_Y)
           and (local_y < C_DIGIT_HEIGHT - C_THICKNESS) then
            return true;
        end if;

        if (segments(1) = '1')
           and (local_x < C_THICKNESS)
           and (local_y >= C_THICKNESS)
           and (local_y < C_MID_Y) then
            return true;
        end if;

        if (segments(0) = '1')
           and (local_y >= C_MID_Y - (C_THICKNESS / 2))
           and (local_y < C_MID_Y + ((C_THICKNESS + 1) / 2))
           and (local_x >= C_THICKNESS)
           and (local_x < C_DIGIT_WIDTH - C_THICKNESS) then
            return true;
        end if;

        return false;
    end function digit_pixel_on;

    function counter_nibble(value : t_counter; digit_index : natural) return std_logic_vector is
        variable shift_value : natural;
        variable temp_value  : unsigned(C_COUNTER_WIDTH - 1 downto 0);
    begin
        shift_value := digit_index * 4;
        temp_value  := shift_right(value, shift_value);
        return std_logic_vector(temp_value(3 downto 0));
    end function counter_nibble;

    function sample_nibble(value : t_sample; digit_index : natural) return std_logic_vector is
        variable temp_value : unsigned(15 downto 0);
        variable shift_value : natural;
    begin
        temp_value  := resize(unsigned(value), 16);
        shift_value := digit_index * 4;
        temp_value  := shift_right(temp_value, shift_value);
        return std_logic_vector(temp_value(3 downto 0));
    end function sample_nibble;

    constant C_SCALE          : positive := max_positive(1, max_natural(1, G_ACTIVE_HEIGHT / 96));
    constant C_DIGIT_WIDTH    : positive := 12 * C_SCALE;
    constant C_DIGIT_HEIGHT   : positive := 20 * C_SCALE;
    constant C_DIGIT_SPACING  : positive := max_positive(2, 2 * C_SCALE);
    constant C_ROW_MARKER_W   : positive := max_positive(4, 3 * C_SCALE);
    constant C_LEFT_X         : natural  := max_natural(6, G_ACTIVE_WIDTH / 24);
    constant C_RIGHT_X        : natural  := max_natural(G_ACTIVE_WIDTH / 2, (G_ACTIVE_WIDTH * 11) / 20);
    constant C_VALUE_Y        : natural  := max_natural(6, G_ACTIVE_HEIGHT / 12);
    constant C_VALID_Y        : natural  := max_natural(C_VALUE_Y + C_DIGIT_HEIGHT + (4 * C_SCALE), (G_ACTIVE_HEIGHT * 3) / 10);
    constant C_CORRUPT_Y      : natural  := max_natural(C_VALID_Y + C_DIGIT_HEIGHT + (4 * C_SCALE), (G_ACTIVE_HEIGHT * 5) / 10);
    constant C_MISSING_Y      : natural  := max_natural(C_CORRUPT_Y + C_DIGIT_HEIGHT + (4 * C_SCALE), (G_ACTIVE_HEIGHT * 7) / 10);
    constant C_TIMEOUT_Y      : natural  := C_VALID_Y;
    constant C_BOX_SIZE       : positive := max_positive(10, 8 * C_SCALE);
    constant C_BOX_GAP        : positive := max_positive(4, 3 * C_SCALE);
    constant C_STATE_BOX_Y    : natural  := C_CORRUPT_Y;
    constant C_COMM_BOX_Y     : natural  := C_MISSING_Y;
    constant C_COMM_BOX_W     : positive := max_positive(20, 10 * C_SCALE);
    constant C_COMM_BOX_H     : positive := max_positive(16, 8 * C_SCALE);
    constant C_GAUGE_X        : natural  := G_ACTIVE_WIDTH - max_natural(18, G_ACTIVE_WIDTH / 12);
    constant C_GAUGE_Y        : natural  := max_natural(20, G_ACTIVE_HEIGHT / 8);
    constant C_GAUGE_W        : positive := max_positive(8, G_ACTIVE_WIDTH / 24);
    constant C_GAUGE_H        : positive := max_positive(24, (G_ACTIVE_HEIGHT * 2) / 3);

    signal red_reg   : std_logic_vector(3 downto 0) := (others => '0');
    signal green_reg : std_logic_vector(3 downto 0) := (others => '0');
    signal blue_reg  : std_logic_vector(3 downto 0) := (others => '0');
begin
    process (clk)
        variable x_value        : natural;
        variable y_value        : natural;
        variable gauge_fill     : natural;
        variable digit_left     : natural;
        variable sensor_color_r : std_logic_vector(3 downto 0);
        variable sensor_color_g : std_logic_vector(3 downto 0);
        variable sensor_color_b : std_logic_vector(3 downto 0);
        variable comm_color_r   : std_logic_vector(3 downto 0);
        variable comm_color_g   : std_logic_vector(3 downto 0);
        variable comm_color_b   : std_logic_vector(3 downto 0);
        variable red_v          : std_logic_vector(3 downto 0);
        variable green_v        : std_logic_vector(3 downto 0);
        variable blue_v         : std_logic_vector(3 downto 0);
    begin
        if rising_edge(clk) then
            if rst = '1' then
                red_reg   <= (others => '0');
                green_reg <= (others => '0');
                blue_reg  <= (others => '0');
            elsif pixel_ce = '1' then
                red_v   := (others => '0');
                green_v := (others => '0');
                blue_v  := (others => '0');

                if active_video = '1' then
                    x_value := to_integer(pixel_x);
                    y_value := to_integer(pixel_y);

                    red_v   := x"1";
                    green_v := x"2";
                    blue_v  := x"3";

                    if current_sensor_state = C_SENSOR_STATE_ERROR then
                        sensor_color_r := x"F";
                        sensor_color_g := x"2";
                        sensor_color_b := x"2";
                    elsif current_sensor_state = C_SENSOR_STATE_WARNING then
                        sensor_color_r := x"F";
                        sensor_color_g := x"C";
                        sensor_color_b := x"2";
                    else
                        sensor_color_r := x"3";
                        sensor_color_g := x"F";
                        sensor_color_b := x"5";
                    end if;

                    if comm_state = C_COMM_STATE_TIMEOUT then
                        comm_color_r := x"F";
                        comm_color_g := x"2";
                        comm_color_b := x"2";
                    elsif comm_state = C_COMM_STATE_DEGRADED then
                        comm_color_r := x"F";
                        comm_color_g := x"A";
                        comm_color_b := x"2";
                    elsif comm_state = C_COMM_STATE_OK then
                        comm_color_r := x"2";
                        comm_color_g := x"E";
                        comm_color_b := x"4";
                    else
                        comm_color_r := x"4";
                        comm_color_g := x"6";
                        comm_color_b := x"C";
                    end if;

                    if in_rect(x_value, y_value, C_LEFT_X, C_VALUE_Y, C_ROW_MARKER_W, C_DIGIT_HEIGHT) then
                        red_v   := x"3";
                        green_v := x"C";
                        blue_v  := x"F";
                    elsif in_rect(x_value, y_value, C_LEFT_X, C_VALID_Y, C_ROW_MARKER_W, C_DIGIT_HEIGHT) then
                        red_v   := x"2";
                        green_v := x"E";
                        blue_v  := x"4";
                    elsif in_rect(x_value, y_value, C_LEFT_X, C_CORRUPT_Y, C_ROW_MARKER_W, C_DIGIT_HEIGHT) then
                        red_v   := x"F";
                        green_v := x"2";
                        blue_v  := x"2";
                    elsif in_rect(x_value, y_value, C_LEFT_X, C_MISSING_Y, C_ROW_MARKER_W, C_DIGIT_HEIGHT) then
                        red_v   := x"F";
                        green_v := x"A";
                        blue_v  := x"2";
                    elsif in_rect(x_value, y_value, C_RIGHT_X - C_ROW_MARKER_W - C_SCALE, C_TIMEOUT_Y, C_ROW_MARKER_W, C_DIGIT_HEIGHT) then
                        red_v   := x"E";
                        green_v := x"4";
                        blue_v  := x"F";
                    end if;

                    for digit_index in 0 to 3 loop
                        digit_left := C_LEFT_X + C_ROW_MARKER_W + (3 * C_SCALE) + ((3 - digit_index) * (C_DIGIT_WIDTH + C_DIGIT_SPACING));

                        if digit_pixel_on(x_value, y_value, digit_left, C_VALUE_Y, sample_nibble(current_sensor_value, digit_index), C_SCALE) then
                            red_v   := x"3";
                            green_v := x"C";
                            blue_v  := x"F";
                        elsif digit_pixel_on(x_value, y_value, digit_left, C_VALID_Y, counter_nibble(valid_frames, digit_index), C_SCALE) then
                            red_v   := x"2";
                            green_v := x"E";
                            blue_v  := x"4";
                        elsif digit_pixel_on(x_value, y_value, digit_left, C_CORRUPT_Y, counter_nibble(corrupted_frames, digit_index), C_SCALE) then
                            red_v   := x"F";
                            green_v := x"2";
                            blue_v  := x"2";
                        elsif digit_pixel_on(x_value, y_value, digit_left, C_MISSING_Y, counter_nibble(missing_frames, digit_index), C_SCALE) then
                            red_v   := x"F";
                            green_v := x"A";
                            blue_v  := x"2";
                        end if;

                        digit_left := C_RIGHT_X + ((3 - digit_index) * (C_DIGIT_WIDTH + C_DIGIT_SPACING));
                        if digit_pixel_on(x_value, y_value, digit_left, C_TIMEOUT_Y, counter_nibble(timeout_events, digit_index), C_SCALE) then
                            red_v   := x"E";
                            green_v := x"4";
                            blue_v  := x"F";
                        end if;
                    end loop;

                    if in_rect(x_value, y_value, C_RIGHT_X, C_STATE_BOX_Y, C_BOX_SIZE, C_BOX_SIZE) then
                        if current_sensor_state = C_SENSOR_STATE_NORMAL then
                            red_v   := x"3";
                            green_v := x"F";
                            blue_v  := x"5";
                        else
                            red_v   := x"1";
                            green_v := x"4";
                            blue_v  := x"1";
                        end if;
                    elsif in_rect(x_value, y_value, C_RIGHT_X + C_BOX_SIZE + C_BOX_GAP, C_STATE_BOX_Y, C_BOX_SIZE, C_BOX_SIZE) then
                        if current_sensor_state = C_SENSOR_STATE_WARNING then
                            red_v   := x"F";
                            green_v := x"C";
                            blue_v  := x"2";
                        else
                            red_v   := x"4";
                            green_v := x"3";
                            blue_v  := x"1";
                        end if;
                    elsif in_rect(x_value, y_value, C_RIGHT_X + (2 * (C_BOX_SIZE + C_BOX_GAP)), C_STATE_BOX_Y, C_BOX_SIZE, C_BOX_SIZE) then
                        if current_sensor_state = C_SENSOR_STATE_ERROR then
                            red_v   := x"F";
                            green_v := x"3";
                            blue_v  := x"3";
                        else
                            red_v   := x"4";
                            green_v := x"1";
                            blue_v  := x"1";
                        end if;
                    end if;

                    if in_rect(x_value, y_value, C_RIGHT_X, C_COMM_BOX_Y, C_COMM_BOX_W, C_COMM_BOX_H) then
                        red_v   := comm_color_r;
                        green_v := comm_color_g;
                        blue_v  := comm_color_b;
                    end if;

                    if in_rect(x_value, y_value, C_GAUGE_X, C_GAUGE_Y, C_GAUGE_W, C_GAUGE_H) then
                        red_v   := x"1";
                        green_v := x"1";
                        blue_v  := x"1";

                        gauge_fill := (to_integer(unsigned(current_sensor_value)) * C_GAUGE_H) / ((2 ** C_SAMPLE_WIDTH) - 1);

                        if y_value >= C_GAUGE_Y + C_GAUGE_H - gauge_fill then
                            red_v   := sensor_color_r;
                            green_v := sensor_color_g;
                            blue_v  := sensor_color_b;
                        end if;
                    end if;
                end if;

                red_reg   <= red_v;
                green_reg <= green_v;
                blue_reg  <= blue_v;
            end if;
        end if;
    end process;

    vga_r_o <= red_reg;
    vga_g_o <= green_reg;
    vga_b_o <= blue_reg;
end architecture rtl;
