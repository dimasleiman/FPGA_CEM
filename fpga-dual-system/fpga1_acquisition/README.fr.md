# FPGA1 Acquisition

## But

Ce dossier contient le sous-systeme d'acquisition et d'emission cote FPGA1.
Son role est de recevoir une source d'echantillon choisie au niveau du wrapper
carte, de preparer cet echantillon pour l'affichage local et l'etat capteur,
de construire une trame UART fixe, puis d'envoyer cette trame vers FPGA2.

## Structure du dossier

### `src/`

RTL synthesizable utilise par la chaine d'acquisition FPGA1.

### `src/pkg/`

- `fpga1_pkg.vhd` : constantes et fonctions utilitaires propres a FPGA1. Ce
  fichier regroupe les parametres par defaut, les valeurs de simulation, les
  valeurs du faux capteur et les conversions utiles pour l'affichage.

### `src/processing/`

- `fake_sensor_gen.vhd` : generateur d'echantillons synthetiques pour la
  simulation, le bring-up et les modes de test du wrapper. Il peut produire une
  rampe, des valeurs pseudo-aleatoires, ou une valeur invalide forcee.
- `sample_classifier.vhd` : transforme les informations de validite/plage en un
  code d'etat capteur utilise ensuite dans la trame.
- `sample_noise_monitor.vhd` : detecteur de bruit base sur une fenetre glissante
  et l'etendue min/max des echantillons. Dans l'arbre actuel, c'est un bloc
  auxiliaire present pour les essais d'integration.
- `sample_normalizer.vhd` : convertit le code brut en une valeur de temperature
  bornee, destinee a l'affichage decimal local.
- `sample_validator.vhd` : verifie qu'un echantillon brut reste dans la plage
  acceptable et produit `range_ok` / `range_error`.
- `threshold_detector.vhd` : helper combinatoire capable de sortir des drapeaux
  warning/error directement a partir d'un echantillon. Il reste utile pour des
  variantes de cablage ou du diagnostic, mais ce n'est pas le chemin principal
  de la trame dans le top actuel.

### `src/display/`

- `bin_to_bcd.vhd` : convertit une valeur binaire en chiffres BCD pour
  l'affichage sur sept segments.
- `digit_to_7seg_decimal_n.vhd` : convertit un chiffre decimal en motif
  sept-segments actif a l'etat bas pour la carte DE10-Lite.

### `src/link_tx/`

- `frame_builder.vhd` : construit la trame UART fixe de 8 octets
  (header/control/sequence/sample/flags/CRC/footer).
- `uart_tx.vhd` : emetteur UART charge d'envoyer les octets vers FPGA2.

### `src/top/`

- `fpga1_top.vhd` : coeur reutilisable principal de FPGA1. Il recoit les
  echantillons depuis le wrapper carte, pilote l'affichage local, construit les
  trames UART et les transmet.

### `sim/`

Helpers et bancs de test uniquement pour la simulation.

- `uart_rx_monitor.vhd` : petit recepteur UART utilise dans les testbenches
  FPGA1 pour observer les octets emis.
- `tb_fake_sensor_gen.vhd` : test unitaire du generateur de faux capteur.
- `tb_fpga1_top.vhd` : testbench principal du top FPGA1. Il applique des
  echantillons, verifie l'affichage et controle la trame UART produite.

### `quartus/`

Fichiers de configuration utilises pour construire FPGA1 sous Quartus.

- `add_sources.tcl` : ajoute les sources reutilisables FPGA1 dans un projet
  Quartus.
- `add_de10_lite_wrapper_sources.tcl` : ajoute les sources FPGA1 plus les
  fichiers specifiques au wrapper et a la carte DE10-Lite.
- `de10_lite_placeholder.qsf` : squelette minimal de configuration Quartus.
- `de10_lite_fpga1_wrapper.qpf` : fichier projet Quartus pour la cible wrapper
  FPGA1 DE10-Lite.
- `de10_lite_fpga1_wrapper.qsf` : fichier d'assignations Quartus listant les
  sources et les reglages du wrapper FPGA1.
- `de10_lite_fpga1_wrapper.sdc` : contraintes temporelles du projet wrapper
  FPGA1.
- `unsaved/unsaved_generation.rpt` : rapport temporaire genere par Quartus.
- `.qsys_edit/` : etat d'editeur genere par Quartus.
- `db/` : base de donnees de compilation generee par Quartus.
- `incremental_db/` : donnees de compilation incrementale generees par Quartus.
- `output_files/` : rapports et sorties de build generes par Quartus.

## Workflow

1. Un wrapper carte situe hors de ce dossier choisit la vraie source de
   l'echantillon : ADC reel, source de test fixe ou `fake_sensor_gen`.
2. Ce wrapper fournit `sample_value_i` et `sample_valid_i` au fichier
   `src/top/fpga1_top.vhd`.
3. `sample_normalizer.vhd` prepare une valeur exploitable par l'affichage
   decimal local.
4. `sample_validator.vhd` controle si le code brut reste dans la plage
   d'utilisation acceptee.
5. `sample_classifier.vhd` produit l'etat capteur qui sera place dans la trame.
6. `fpga1_top.vhd` memorise l'echantillon et son statut, met a jour
   l'affichage local et declenche la construction d'une nouvelle trame.
7. `frame_builder.vhd` assemble la trame UART fixe et calcule le CRC.
8. `uart_tx.vhd` serialize chaque octet sur la liaison UART inter-FPGA.

## Utilisation pratique

- Utiliser `src/` pour modifier le comportement synthesizable de FPGA1.
- Utiliser `sim/` pour valider les changements RTL en simulation.
- Utiliser `quartus/` pour preparer ou reconstruire le projet FPGA1 sur
  DE10-Lite.
- Considerer `quartus/db/`, `quartus/incremental_db/`, `quartus/output_files/`
  et les dossiers similaires comme de l'etat de build, pas comme la source du
  design.
