library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity vga_timing is
    generic (
        G_H_ACTIVE      : positive := 640;
        G_H_FRONT_PORCH : positive := 16;
        G_H_SYNC        : positive := 96;
        G_H_BACK_PORCH  : positive := 48;
        G_V_ACTIVE      : positive := 480;
        G_V_FRONT_PORCH : positive := 10;
        G_V_SYNC        : positive := 2;
        G_V_BACK_PORCH  : positive := 33
    );
    port (
        clk            : in  std_logic;
        rst            : in  std_logic;
        pixel_ce_o     : out std_logic;
        active_video_o : out std_logic;
        pixel_x_o      : out unsigned(11 downto 0);
        pixel_y_o      : out unsigned(11 downto 0);
        hsync_o        : out std_logic;
        vsync_o        : out std_logic
    );
end entity vga_timing;

architecture rtl of vga_timing is
    constant C_H_TOTAL : positive := G_H_ACTIVE + G_H_FRONT_PORCH + G_H_SYNC + G_H_BACK_PORCH;
    constant C_V_TOTAL : positive := G_V_ACTIVE + G_V_FRONT_PORCH + G_V_SYNC + G_V_BACK_PORCH;

    signal pixel_divider_reg : std_logic := '0';
    signal pixel_ce_reg      : std_logic := '0';
    signal h_count_reg       : natural range 0 to C_H_TOTAL - 1 := 0;
    signal v_count_reg       : natural range 0 to C_V_TOTAL - 1 := 0;
begin
    process (clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                pixel_divider_reg <= '0';
                pixel_ce_reg      <= '0';
                h_count_reg       <= 0;
                v_count_reg       <= 0;
            else
                pixel_divider_reg <= not pixel_divider_reg;
                pixel_ce_reg      <= '0';

                if pixel_divider_reg = '1' then
                    pixel_ce_reg <= '1';

                    if h_count_reg = C_H_TOTAL - 1 then
                        h_count_reg <= 0;

                        if v_count_reg = C_V_TOTAL - 1 then
                            v_count_reg <= 0;
                        else
                            v_count_reg <= v_count_reg + 1;
                        end if;
                    else
                        h_count_reg <= h_count_reg + 1;
                    end if;
                end if;
            end if;
        end if;
    end process;

    pixel_ce_o     <= pixel_ce_reg;
    active_video_o <= '1' when (h_count_reg < G_H_ACTIVE) and (v_count_reg < G_V_ACTIVE) else '0';
    pixel_x_o      <= to_unsigned(h_count_reg, pixel_x_o'length);
    pixel_y_o      <= to_unsigned(v_count_reg, pixel_y_o'length);
    hsync_o        <= '0' when (h_count_reg >= G_H_ACTIVE + G_H_FRONT_PORCH)
                               and (h_count_reg < G_H_ACTIVE + G_H_FRONT_PORCH + G_H_SYNC)
                      else '1';
    vsync_o        <= '0' when (v_count_reg >= G_V_ACTIVE + G_V_FRONT_PORCH)
                               and (v_count_reg < G_V_ACTIVE + G_V_FRONT_PORCH + G_V_SYNC)
                      else '1';
end architecture rtl;
