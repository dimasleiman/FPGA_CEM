# Preparation de la Mise en Route DE10-Lite

Ce depot garde le bring-up carte separe du RTL reutilisable :

1. coeur RTL sous `fpga1_acquisition/src/` et `fpga2_display/src/`
2. wrappers carte sous `board/de10_lite/`
3. placeholders Quartus sous le dossier `quartus/` de chaque FPGA

## Perimetre des wrappers

Tops wrappers :

- `de10_lite_fpga1_wrapper`
- `de10_lite_fpga2_wrapper`

Ports wrappers actuellement exposes :

- FPGA1 :
  - `clock_50_i`
  - `reset_source_i`
  - `uart_tx_o`
- FPGA2 :
  - `clock_50_i`
  - `reset_source_i`
  - `uart_rx_i`
  - `leds_o(3 downto 0)`
  - `vga_hsync_o`
  - `vga_vsync_o`
  - `vga_r_o(3 downto 0)`
  - `vga_g_o(3 downto 0)`
  - `vga_b_o(3 downto 0)`

Les signaux carte lies a l'ADC ne sont volontairement pas ajoutes pour le
moment, car l'integration ADC MAX 10 reste une phase future.

## Strategie de reset

Les wrappers convertissent une source de reset cote carte en reset synchrone
actif a l'etat haut utilise par les coeurs reutilisables.

Faits actuels :

- le reset est synchronise par `board/de10_lite/common/reset_sync.vhd`
- aucun debounce n'est inclus
- la polarite finale du reset reste une decision Quartus / carte

## Strategie de premier bring-up materiel

Utiliser la meme strategie simple sur les deux cartes :

- mapper `clock_50_i` sur l'horloge 50 MHz de la carte
- mapper `reset_source_i` sur un interrupteur ou un bouton choisi
- connecter `uart_tx_o` de FPGA1 a `uart_rx_i` de FPGA2
- relier une masse commune entre les deux cartes
- mapper les sorties VGA de FPGA2 vers le connecteur VGA
- optionnellement mapper `leds_o` de FPGA2 vers quatre LED utilisateur pour un
  retour rapide d'etat

Ne pas considerer un choix de broches comme final avant d'avoir rempli les
fichiers placeholder `.qsf`.

## Taches Quartus manuelles

Pour chaque projet, il reste a choisir :

- les positions exactes des broches
- les standards d'E/S exacts
- la polarite du reset
- les broches reelles de la liaison UART carte-a-carte
- les affectations reelles du connecteur VGA

Pour une phase ADC ulterieure, il faudra aussi :

- ajouter l'IP ADC MAX 10 ou un wrapper associe
- mapper correctement le chemin analogique de la carte
- verifier sous Quartus puis sur materiel la validite du timing et de la
  calibration ADC

## Simulation avant bring-up

Testbenches de simulation disponibles :

- `fpga1_acquisition/sim/tb_fpga1_top.vhd`
- `fpga2_display/sim/tb_link_statistics.vhd`
- `fpga2_display/sim/tb_fpga2_top.vhd`
- `sim/tb_fpga1_fpga2_integration.vhd`
- `sim/tb_de10_lite_wrappers.vhd`

Ces simulations ne valident que le flux de phase 1. Elles ne prouvent pas le
mapping de broches, la marge de timing sur moniteur reel ni l'integration ADC.
