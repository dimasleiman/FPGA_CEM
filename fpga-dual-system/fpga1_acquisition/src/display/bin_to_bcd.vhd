--Ce bloc bin_to_bcd sert à convertir un nombre binaire en chiffres décimaux BCD pour pouvoir l’afficher sur les afficheurs 7 segments.
--Il sert à prendre error_count en binaire, puis à le transformer en chiffres décimaux pour HEX2, HEX1, HEX0.
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity bin_to_bcd is
    generic (
        G_INPUT_WIDTH : positive := 12;	--Nombre de bits du nombre binaire d’entrée.
        G_DIGIT_COUNT : positive := 4		--Nombre de chiffres décimaux BCD à produire.
    );
    port (
        binary_i : in  std_logic_vector(G_INPUT_WIDTH - 1 downto 0);
        bcd_o    : out std_logic_vector((G_DIGIT_COUNT * 4) - 1 downto 0)
    );
end entity bin_to_bcd;

architecture rtl of bin_to_bcd is
begin
    process (all)
        variable shift_reg  : unsigned((G_DIGIT_COUNT * 4) + G_INPUT_WIDTH - 1 downto 0);
        variable digit_low  : natural;
        variable digit_high : natural;
    begin
        shift_reg := (others => '0');
        shift_reg(G_INPUT_WIDTH - 1 downto 0) := unsigned(binary_i);

        for bit_index in 0 to G_INPUT_WIDTH - 1 loop
            for digit_index in 0 to G_DIGIT_COUNT - 1 loop
                digit_low  := G_INPUT_WIDTH + (digit_index * 4);
                digit_high := digit_low + 3;

                if shift_reg(digit_high downto digit_low) > to_unsigned(4, 4) then
                    shift_reg(digit_high downto digit_low) :=
                        shift_reg(digit_high downto digit_low) + to_unsigned(3, 4);
                end if;
            end loop;

            shift_reg := shift_left(shift_reg, 1);	--C’est la variable principale de l’algorithme. Elle contient à la fois :la partie binaire en cours de traitement etla future partie BCD
        end loop;

        bcd_o <= std_logic_vector(shift_reg(shift_reg'high downto G_INPUT_WIDTH));
    end process;
end architecture rtl;
