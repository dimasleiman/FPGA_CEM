# Specification d'Interface

Carte cible pour l'integration Quartus ulterieure :

- Carte : Terasic DE10-Lite
- Composant FPGA : Intel/Altera MAX 10 `10M50DAF484C7G`
- Horloge carte par defaut : `50 MHz`

Les noms exacts des broches et leurs affectations sont volontairement laisses
ouverts dans ce document.

## Top coeur FPGA1

Fichier : `fpga1_acquisition/src/top/fpga1_top.vhd`

### Generiques

- `G_CLOCK_FREQ_HZ`
- `G_BAUD_RATE`
- `G_SOURCE_IS_ADC`

### Ports

- `clk`
- `rst`
- `sample_value_i`
- `sample_valid_i`
- `local_error_led_o`
- `hex5_n_o`
- `hex4_n_o`
- `hex3_n_o`
- `hex2_n_o`
- `hex1_n_o`
- `hex0_n_o`
- `uart_tx_o`

Remarques :

- le top coeur FPGA1 ne contient plus de source capteur interne
- la selection de source (ADC reel, source fixe de test, ou `fake_sensor_gen`)
  se fait dans le wrapper carte
- `G_SOURCE_IS_ADC` ne sert actuellement qu'a renseigner les drapeaux transmis
- l'integration ADC reelle MAX 10 reste externe au coeur reutilisable

## Top coeur FPGA2

Fichier : `fpga2_display/src/top/fpga2_top.vhd`

### Generiques

- `G_CLOCK_FREQ_HZ`
- `G_BAUD_RATE`
- `G_FRAME_TIMEOUT_CLKS`
- `G_FAST_SIMULATION_VGA`

### Ports

- `clk`
- `rst`
- `uart_rx_i`
- `leds_o(3 downto 0)`
- `vga_hsync_o`
- `vga_vsync_o`
- `vga_r_o(3 downto 0)`
- `vga_g_o(3 downto 0)`
- `vga_b_o(3 downto 0)`

Remarques :

- les signaux VGA sont des sorties video logiques, pas des noms de broches
  fixes de la carte
- le mode VGA accelere ne sert qu'a la simulation

## Tops wrappers DE10-Lite

Fichiers :

- `board/de10_lite/fpga1/de10_lite_fpga1_wrapper.vhd`
- `board/de10_lite/fpga2/de10_lite_fpga2_wrapper.vhd`

Role des wrappers :

- adapter le reset carte vers le reset synchrone actif a l'etat haut du coeur
- garder le mapping de broches Quartus hors du coeur reutilisable
- n'exposer que des ports placeholders cote carte

## Liaison UART

- 8 bits de donnees
- pas de parite
- 1 bit de stop
- ligne au repos a l'etat haut
- trame fixe de 8 octets

Voir `shared/protocol/frame_format.md` pour le format exact de la trame.

## Perimetre actuel de verification

Verifie en simulation :

- generation de trame sur FPGA1
- chemin reception / verification / statistiques / VGA sur FPGA2
- testbenches bout-en-bout du coeur et des wrappers

Non verifie ici :

- mapping reel des broches DE10-Lite
- affichage VGA reel sur moniteur
- integration ADC reelle du MAX 10
- compilation Quartus
