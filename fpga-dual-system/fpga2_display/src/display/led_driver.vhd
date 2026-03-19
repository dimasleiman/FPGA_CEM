library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.fpga2_pkg.all;

entity led_driver is
    port (
        clk    : in  std_logic;
        rst    : in  std_logic;
        load   : in  std_logic;
        led_in : in  std_logic_vector(3 downto 0);
        leds   : out std_logic_vector(3 downto 0)
    );
end entity led_driver;

architecture rtl of led_driver is
    signal leds_reg : std_logic_vector(3 downto 0) := C_LED_NO_FRAME;
begin
    process (clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                leds_reg <= C_LED_NO_FRAME;
            elsif load = '1' then
                -- Register the LED pattern so the outputs change cleanly.
                leds_reg <= led_in;
            end if;
        end if;
    end process;

    leds <= leds_reg;
end architecture rtl;
