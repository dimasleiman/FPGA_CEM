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

    function at_least_one(value : natural) return positive is
    begin
        if value = 0 then
            return 1;
        end if;

        return value;
    end function at_least_one;

    function in_rect(
        x_value  : natural;
        y_value  : natural;
        left_x   : natural;
        top_y    : natural;
        width_v  : natural;
        height_v : natural
    ) return boolean is
    begin
        return (x_value >= left_x)
           and (x_value < left_x + width_v)
           and (y_value >= top_y)
           and (y_value < top_y + height_v);
    end function in_rect;

    function glyph_row(
        glyph_ch  : character;
        row_index : natural
    ) return std_logic_vector is
    begin
        case glyph_ch is
            when 'A' =>
                case row_index is
                    when 0 => return "01110";
                    when 1 => return "10001";
                    when 2 => return "10001";
                    when 3 => return "11111";
                    when 4 => return "10001";
                    when 5 => return "10001";
                    when others => return "10001";
                end case;

            when 'C' =>
                case row_index is
                    when 0 => return "01111";
                    when 1 => return "10000";
                    when 2 => return "10000";
                    when 3 => return "10000";
                    when 4 => return "10000";
                    when 5 => return "10000";
                    when others => return "01111";
                end case;

            when 'D' =>
                case row_index is
                    when 0 => return "11110";
                    when 1 => return "10001";
                    when 2 => return "10001";
                    when 3 => return "10001";
                    when 4 => return "10001";
                    when 5 => return "10001";
                    when others => return "11110";
                end case;

            when 'E' =>
                case row_index is
                    when 0 => return "11111";
                    when 1 => return "10000";
                    when 2 => return "10000";
                    when 3 => return "11110";
                    when 4 => return "10000";
                    when 5 => return "10000";
                    when others => return "11111";
                end case;

            when 'G' =>
                case row_index is
                    when 0 => return "01111";
                    when 1 => return "10000";
                    when 2 => return "10000";
                    when 3 => return "10011";
                    when 4 => return "10001";
                    when 5 => return "10001";
                    when others => return "01110";
                end case;

            when 'M' =>
                case row_index is
                    when 0 => return "10001";
                    when 1 => return "11011";
                    when 2 => return "10101";
                    when 3 => return "10101";
                    when 4 => return "10001";
                    when 5 => return "10001";
                    when others => return "10001";
                end case;

            when 'N' =>
                case row_index is
                    when 0 => return "10001";
                    when 1 => return "11001";
                    when 2 => return "10101";
                    when 3 => return "10011";
                    when 4 => return "10001";
                    when 5 => return "10001";
                    when others => return "10001";
                end case;

            when 'O' =>
                case row_index is
                    when 0 => return "01110";
                    when 1 => return "10001";
                    when 2 => return "10001";
                    when 3 => return "10001";
                    when 4 => return "10001";
                    when 5 => return "10001";
                    when others => return "01110";
                end case;

            when 'P' =>
                case row_index is
                    when 0 => return "11110";
                    when 1 => return "10001";
                    when 2 => return "10001";
                    when 3 => return "11110";
                    when 4 => return "10000";
                    when 5 => return "10000";
                    when others => return "10000";
                end case;

            when 'R' =>
                case row_index is
                    when 0 => return "11110";
                    when 1 => return "10001";
                    when 2 => return "10001";
                    when 3 => return "11110";
                    when 4 => return "10100";
                    when 5 => return "10010";
                    when others => return "10001";
                end case;

            when 'S' =>
                case row_index is
                    when 0 => return "01111";
                    when 1 => return "10000";
                    when 2 => return "10000";
                    when 3 => return "01110";
                    when 4 => return "00001";
                    when 5 => return "00001";
                    when others => return "11110";
                end case;

            when 'T' =>
                case row_index is
                    when 0 => return "11111";
                    when 1 => return "00100";
                    when 2 => return "00100";
                    when 3 => return "00100";
                    when 4 => return "00100";
                    when 5 => return "00100";
                    when others => return "00100";
                end case;

            when 'U' =>
                case row_index is
                    when 0 => return "10001";
                    when 1 => return "10001";
                    when 2 => return "10001";
                    when 3 => return "10001";
                    when 4 => return "10001";
                    when 5 => return "10001";
                    when others => return "01110";
                end case;

            when '0' =>
                case row_index is
                    when 0 => return "01110";
                    when 1 => return "10001";
                    when 2 => return "10011";
                    when 3 => return "10101";
                    when 4 => return "11001";
                    when 5 => return "10001";
                    when others => return "01110";
                end case;

            when '1' =>
                case row_index is
                    when 0 => return "00100";
                    when 1 => return "01100";
                    when 2 => return "00100";
                    when 3 => return "00100";
                    when 4 => return "00100";
                    when 5 => return "00100";
                    when others => return "01110";
                end case;

            when '2' =>
                case row_index is
                    when 0 => return "01110";
                    when 1 => return "10001";
                    when 2 => return "00001";
                    when 3 => return "00010";
                    when 4 => return "00100";
                    when 5 => return "01000";
                    when others => return "11111";
                end case;

            when '3' =>
                case row_index is
                    when 0 => return "11110";
                    when 1 => return "00001";
                    when 2 => return "00001";
                    when 3 => return "01110";
                    when 4 => return "00001";
                    when 5 => return "00001";
                    when others => return "11110";
                end case;

            when '4' =>
                case row_index is
                    when 0 => return "00010";
                    when 1 => return "00110";
                    when 2 => return "01010";
                    when 3 => return "10010";
                    when 4 => return "11111";
                    when 5 => return "00010";
                    when others => return "00010";
                end case;

            when '5' =>
                case row_index is
                    when 0 => return "11111";
                    when 1 => return "10000";
                    when 2 => return "10000";
                    when 3 => return "11110";
                    when 4 => return "00001";
                    when 5 => return "00001";
                    when others => return "11110";
                end case;

            when '6' =>
                case row_index is
                    when 0 => return "01110";
                    when 1 => return "10000";
                    when 2 => return "10000";
                    when 3 => return "11110";
                    when 4 => return "10001";
                    when 5 => return "10001";
                    when others => return "01110";
                end case;

            when '7' =>
                case row_index is
                    when 0 => return "11111";
                    when 1 => return "00001";
                    when 2 => return "00010";
                    when 3 => return "00100";
                    when 4 => return "01000";
                    when 5 => return "01000";
                    when others => return "01000";
                end case;

            when '8' =>
                case row_index is
                    when 0 => return "01110";
                    when 1 => return "10001";
                    when 2 => return "10001";
                    when 3 => return "01110";
                    when 4 => return "10001";
                    when 5 => return "10001";
                    when others => return "01110";
                end case;

            when '9' =>
                case row_index is
                    when 0 => return "01110";
                    when 1 => return "10001";
                    when 2 => return "10001";
                    when 3 => return "01111";
                    when 4 => return "00001";
                    when 5 => return "00001";
                    when others => return "01110";
                end case;

            when '-' =>
                case row_index is
                    when 3 => return "11111";
                    when others => return "00000";
                end case;

            when others =>
                return "00000";
        end case;
    end function glyph_row;

    function glyph_pixel_on(
        glyph_ch : character;
        local_x  : natural;
        local_y  : natural;
        scale_v  : positive
    ) return boolean is
        variable row_index_v : natural;
        variable col_index_v : natural;
        variable row_bits_v  : std_logic_vector(4 downto 0);
    begin
        if local_x >= 5 * scale_v then
            return false;
        end if;

        if local_y >= 7 * scale_v then
            return false;
        end if;

        row_index_v := local_y / scale_v;
        col_index_v := local_x / scale_v;
        row_bits_v  := glyph_row(glyph_ch, row_index_v);
        return row_bits_v(4 - col_index_v) = '1';
    end function glyph_pixel_on;

    function text_pixel_on(
        x_value    : natural;
        y_value    : natural;
        left_x     : natural;
        top_y      : natural;
        text_value : string;
        scale_v    : positive
    ) return boolean is
        constant C_CHAR_WIDTH   : natural := 5 * scale_v;
        constant C_CHAR_HEIGHT  : natural := 7 * scale_v;
        constant C_CHAR_SPACING : natural := scale_v;
        variable text_width_v   : natural;
        variable char_left_v    : natural;
    begin
        text_width_v := (text_value'length * C_CHAR_WIDTH)
                      + ((text_value'length - 1) * C_CHAR_SPACING);

        if not in_rect(x_value, y_value, left_x, top_y, text_width_v, C_CHAR_HEIGHT) then
            return false;
        end if;

        for char_offset in 0 to text_value'length - 1 loop
            char_left_v := left_x + (char_offset * (C_CHAR_WIDTH + C_CHAR_SPACING));

            if in_rect(x_value, y_value, char_left_v, top_y, C_CHAR_WIDTH, C_CHAR_HEIGHT) then
                return glyph_pixel_on(
                    text_value(text_value'low + char_offset),
                    x_value - char_left_v,
                    y_value - top_y,
                    scale_v
                );
            end if;
        end loop;

        return false;
    end function text_pixel_on;

    function temperature_text(sample_value : t_sample) return string is
        variable result_v     : string(1 to 4) := (others => ' ');
        variable temp_value_v : natural;
    begin
        temp_value_v := to_integer(unsigned(sample_value)) / 100;

        if temp_value_v > 99 then
            temp_value_v := 99;
        end if;

        if temp_value_v >= 10 then
            result_v(1) := character'val(character'pos('0') + (temp_value_v / 10));
        else
            result_v(1) := ' ';
        end if;

        result_v(2) := character'val(character'pos('0') + (temp_value_v mod 10));
        result_v(3) := ' ';
        result_v(4) := 'C';
        return result_v;
    end function temperature_text;

    function status_text(comm_state_value : t_comm_state) return string is
        variable result_v : string(1 to 5) := (others => ' ');
    begin
        if comm_state_value = C_COMM_STATE_OK then
            result_v := "GOOD ";
        elsif comm_state_value = C_COMM_STATE_NO_FRAME then
            result_v := "NONE ";
        else
            result_v := "ERROR";
        end if;

        return result_v;
    end function status_text;

    constant C_WHITE             : std_logic_vector(3 downto 0) := (others => '1');
    constant C_BLACK             : std_logic_vector(3 downto 0) := (others => '0');
    constant C_LABEL_SCALE       : positive := max_positive(1, at_least_one(G_ACTIVE_HEIGHT / 160));
    constant C_VALUE_SCALE       : positive := max_positive(2, at_least_one(G_ACTIVE_HEIGHT / 96));
    constant C_LEFT_X            : natural  := max_natural(8, G_ACTIVE_WIDTH / 10);
    constant C_TEMP_LABEL_Y      : natural  := max_natural(8, G_ACTIVE_HEIGHT / 10);
    constant C_TEMP_VALUE_Y      : natural  := C_TEMP_LABEL_Y + (7 * C_LABEL_SCALE) + (4 * C_LABEL_SCALE);
    constant C_STATUS_LABEL_Y    : natural  := C_TEMP_VALUE_Y + (7 * C_VALUE_SCALE) + (8 * C_LABEL_SCALE);
    constant C_STATUS_VALUE_Y    : natural  := C_STATUS_LABEL_Y + (7 * C_LABEL_SCALE) + (4 * C_LABEL_SCALE);

begin
    process (all)
        variable x_value_v      : natural;
        variable y_value_v      : natural;
        variable temp_text_v    : string(1 to 4);
        variable status_text_v  : string(1 to 5);
        variable text_active_v  : boolean;
        variable red_v          : std_logic_vector(3 downto 0);
        variable green_v        : std_logic_vector(3 downto 0);
        variable blue_v         : std_logic_vector(3 downto 0);
    begin
        red_v        := C_BLACK;
        green_v      := C_BLACK;
        blue_v       := C_BLACK;
        text_active_v := false;

        if (rst = '0') and (active_video = '1') then
            x_value_v     := to_integer(pixel_x);
            y_value_v     := to_integer(pixel_y);
            temp_text_v   := temperature_text(current_sensor_value);
            status_text_v := status_text(comm_state);

            if text_pixel_on(x_value_v, y_value_v, C_LEFT_X, C_TEMP_LABEL_Y, "TEMP", C_LABEL_SCALE) then
                text_active_v := true;
            elsif text_pixel_on(x_value_v, y_value_v, C_LEFT_X, C_TEMP_VALUE_Y, temp_text_v, C_VALUE_SCALE) then
                text_active_v := true;
            elsif text_pixel_on(x_value_v, y_value_v, C_LEFT_X, C_STATUS_LABEL_Y, "STATUS", C_LABEL_SCALE) then
                text_active_v := true;
            elsif text_pixel_on(x_value_v, y_value_v, C_LEFT_X, C_STATUS_VALUE_Y, status_text_v, C_VALUE_SCALE) then
                text_active_v := true;
            end if;

            if text_active_v then
                red_v   := C_WHITE;
                green_v := C_WHITE;
                blue_v  := C_WHITE;
            end if;
        end if;

        vga_r_o <= red_v;
        vga_g_o <= green_v;
        vga_b_o <= blue_v;
    end process;
end architecture rtl;
