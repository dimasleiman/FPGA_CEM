# Configuration des Projets Quartus

Creer deux projets Quartus distincts afin que chaque FPGA puisse etre compile
independamment.

Cible confirmee pour les deux projets :

- Carte : Terasic DE10-Lite
- Composant : `10M50DAF484C7G`
- Horloge de reference : `50 MHz`

Ce qui est versionne dans ce depot :

- le RTL VHDL reutilisable
- les wrappers DE10-Lite
- les scripts Tcl d'ajout de sources
- les fichiers `.qsf` placeholders
- les fichiers `.sdc` deja presents dans les dossiers Quartus

Ce qui reste manuel :

- les affectations reelles de broches
- les standards d'E/S
- le choix final de la polarite de reset
- le mapping VGA reel
- l'integration future ADC/IP

Quartus n'a pas ete lance dans le cadre de cette mise a jour. Ces fichiers
doivent donc etre utilises comme point d'entree de votre propre flow Quartus,
pas comme preuve de compilation reussie.

## Projet FPGA1

- dossier : `fpga1_acquisition/quartus/`
- top coeur : `fpga1_top`
- top wrapper : `de10_lite_fpga1_wrapper`

L'ordre de compilation est gere par :

- `add_sources.tcl`
- `add_de10_lite_wrapper_sources.tcl`

Le jeu de sources FPGA1 inclut maintenant :

- le package partage `shared/rtl/dual_fpga_system_pkg.vhd`
- la source capteur factice
- les etages de normalisation / validation / classification
- le constructeur de trame
- l'emetteur UART

## Projet FPGA2

- dossier : `fpga2_display/quartus/`
- top coeur : `fpga2_top`
- top wrapper : `de10_lite_fpga2_wrapper`

L'ordre de compilation est gere par :

- `add_sources.tcl`
- `add_de10_lite_wrapper_sources.tcl`

Le jeu de sources FPGA2 inclut maintenant :

- le package partage `shared/rtl/dual_fpga_system_pkg.vhd`
- le recepteur UART
- le decodeur de trame
- le bloc de statistiques de liaison
- le mapping d'etat LED
- le timing VGA et le generateur de tableau de bord

## Sequence d'import recommandee

Pour chaque FPGA :

1. Creer ou ouvrir le projet Quartus dans le dossier `quartus/` correspondant.
2. Confirmer le composant `10M50DAF484C7G`.
3. Definir le wrapper comme top-level, pas le coeur.
4. Executer `source add_de10_lite_wrapper_sources.tcl`.
5. Fusionner le contenu du `.qsf` placeholder dans le `.qsf` actif.
6. Renseigner les broches DE10-Lite reelles et les standards d'E/S.
7. Regler les generiques wrappers si necessaire.
8. Compiler.

## Notes sur le mapping carte

Mapping manuel restant pour FPGA1 :

- `clock_50_i`
- `reset_source_i`
- `uart_tx_o`

Mapping manuel restant pour FPGA2 :

- `clock_50_i`
- `reset_source_i`
- `uart_rx_i`
- `leds_o(3 downto 0)`
- `vga_hsync_o`
- `vga_vsync_o`
- `vga_r_o(3 downto 0)`
- `vga_g_o(3 downto 0)`
- `vga_b_o(3 downto 0)`

Le travail ADC de phase 2 reste en dehors du perimetre actuel des placeholders
Quartus.
