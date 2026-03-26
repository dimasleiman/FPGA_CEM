# FPGA2 Display

## But

Ce dossier contient le sous-systeme de reception, de supervision de liaison et
d'affichage cote FPGA2. Son role est de recevoir le flux UART venant de FPGA1,
de decoder et verifier chaque trame, de suivre l'etat de la communication, et
d'afficher l'etat courant du systeme sur les sorties locales.

## Structure du dossier

### `src/`

RTL synthesizable utilise par la chaine de reception et d'affichage FPGA2.

### `src/pkg/`

- `fpga2_pkg.vhd` : constantes propres a FPGA2, surtout les motifs LED utilises
  par le chemin LED optionnel.

### `src/link_rx/`

- `uart_rx.vhd` : recepteur UART orientee octets qui echantillonne la ligne
  serie entrante et produit des octets avec un pulse de validite.
- `frame_decoder.vhd` : reassemble la trame fixe de 8 octets, verifie le
  header, le champ control, le footer et le CRC, puis produit les donnees
  decodees ainsi que les pulses de trame valide/corrompue/active.
- `internal_uart_frame_gen.vhd` : generateur UART interne optionnel pour
  l'auto-test ou la simulation quand FPGA2 doit fonctionner sans emetteur
  FPGA1 reel.

### `src/control/`

- `link_statistics.vhd` : suit le nombre total de trames, les trames valides,
  corrompues, manquantes, les timeouts, la derniere valeur capteur valide, le
  dernier etat capteur valide et l'etat global de communication.
- `status_mapper.vhd` : convertit l'etat capteur et l'etat de communication en
  motif LED 4 bits. C'est un bloc support utile pour un affichage par LEDs.

### `src/display/`

- `led_driver.vhd` : registre et maintient proprement le motif LED courant.
- `vga_timing.vhd` : genere le `pixel_ce`, la zone video active, les
  coordonnees pixel et les syncs horizontale/verticale pour le pipeline VGA.
- `vga_dashboard.vhd` : dessine le tableau de bord VGA avec la valeur courante
  du capteur, les compteurs de liaison, l'etat de communication, les
  indicateurs d'etat capteur et la jauge verticale.

### `src/top/`

- `fpga2_top.vhd` : coeur reutilisable principal de FPGA2. Il choisit la source
  UART, recoit et decode les trames, met a jour les statistiques de liaison,
  pilote la sortie VGA et controle les sorties locales de statut.

### `sim/`

Fichiers et testbenches uniquement pour la simulation.

- `tb_link_statistics.vhd` : testbench de type unitaire centre sur les
  statistiques et la logique de timeout.
- `tb_fpga2_top.vhd` : testbench principal du top FPGA2 avec un stimulus UART
  externe.
- `tb_fpga2_internal_source.vhd` : testbench FPGA2 qui active le generateur UART
  interne et verifie le mode auto-test sans FPGA1.

### `quartus/`

Fichiers de configuration utilises pour construire FPGA2 sous Quartus.

- `add_sources.tcl` : ajoute les sources reutilisables FPGA2 a un projet
  Quartus.
- `add_de10_lite_wrapper_sources.tcl` : ajoute les sources FPGA2 plus les
  fichiers specifiques au wrapper carte.
- `de10_lite_placeholder.qsf` : squelette minimal de configuration Quartus.
- `de10_lite_fpga2_wrapper.qpf` : fichier projet Quartus pour la cible wrapper
  FPGA2 DE10-Lite.
- `de10_lite_fpga2_wrapper.qsf` : fichier d'assignations listant les sources et
  reglages du wrapper FPGA2.
- `de10_lite_fpga2_wrapper.sdc` : contraintes temporelles du projet wrapper
  FPGA2.
- `db/` : base de donnees de compilation generee par Quartus.
- `incremental_db/` : donnees de compilation incrementale generees par Quartus.
- `output_files/` : rapports et sorties de build generes par Quartus.

## Workflow

1. `fpga2_top.vhd` choisit la source UART :
   soit l'entree reelle de la carte, soit `internal_uart_frame_gen.vhd`.
2. `uart_rx.vhd` convertit le flux serie entrant en octets.
3. `frame_decoder.vhd` reconstruit la trame UART fixe et verifie sa structure
   ainsi que son CRC.
4. `link_statistics.vhd` accumule les compteurs de communication et conserve la
   derniere valeur capteur valide, le dernier etat capteur valide et l'etat
   courant de la liaison.
5. `vga_timing.vhd` genere le timing et les coordonnees pixels pour le raster
   VGA.
6. `vga_dashboard.vhd` transforme les statistiques et les donnees capteur en un
   tableau de bord VGA vivant.
7. `fpga2_top.vhd` mappe aussi l'etat de communication vers l'afficheur local a
   sept segments pour montrer des etats comme `GOOD`, `NONE` ou `ERROR`.

## Notes sur les blocs support

- `status_mapper.vhd` et `led_driver.vhd` restent utiles pour un chemin
  d'affichage dedie aux LEDs.
- Dans l'arbre actuel, le top FPGA2 force les LEDs de la carte a l'etat inactif
  et utilise principalement l'afficheur sept segments et la sortie VGA.

## Utilisation pratique

- Utiliser `src/` pour modifier le comportement synthesizable de FPGA2.
- Utiliser `sim/` pour valider en simulation les changements de reception et
  d'affichage.
- Utiliser `quartus/` pour preparer ou reconstruire le projet FPGA2 sur
  DE10-Lite.
- Considerer `quartus/db/`, `quartus/incremental_db/` et
  `quartus/output_files/` comme de l'etat de build genere, pas comme de la
  source a maintenir a la main.
