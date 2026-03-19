# FPGA Dual System

Ce depot est une plateforme educative double-FPGA construite autour de deux
cartes Terasic DE10-Lite avec des composants Intel/Altera MAX 10
`10M50DAF484C7G`.

L'objectif du projet n'est plus un simple exemple de communication UART. La
direction retenue est la suivante :

- FPGA1 acquiert ou emule un signal capteur, le valide, le classe, puis
  transmet une trame robuste.
- FPGA2 recoit la trame, verifie son integrite et sa continuite, met a jour des
  statistiques de liaison et genere un tableau de bord VGA simple.
- L'architecture reste modulaire afin que la source capteur factice de la
  phase 1 puisse etre remplacee plus tard par le chemin ADC integre du MAX 10
  sans devoir re-ecrire la chaine de reception.

Etat actuel du depot :

- Phase 1 implementee en RTL et en simulation :
  - source capteur factice sur FPGA1
  - liaison UART inter-FPGA
  - trame robuste a longueur fixe avec en-tete, controle, sequence, charge
    utile, drapeaux, CRC8 et pied de trame
  - verification de trame sur FPGA2, controle de continuite, detection de
    timeout et suivi des statistiques
  - sortie VGA minimale sur FPGA2
- Phase 2 non implementee pour le moment :
  - l'integration ADC reelle MAX 10 / DE10-Lite reste un travail futur manuel
- La synthese et le bring-up Quartus n'ont pas ete re-verifies dans cette mise
  a jour

## Couches de conception

Le depot separe explicitement les couches suivantes :

1. RTL coeur reutilisable
2. Wrappers specifiques a la carte
3. Aides de projet Quartus et contraintes placeholders
4. Testbenches et fichiers de simulation uniquement
5. Documentation

## Organisation du depot

```text
fpga-dual-system/
+-- README.md
+-- docs/
|   +-- system_architecture.md
|   +-- interface_spec.md
|   +-- de10_lite_target.md
|   +-- de10_lite_bringup.md
|   +-- quartus_project_setup.md
|   `-- Transition_to_Quartus.md
+-- shared/
|   +-- protocol/
|   |   `-- frame_format.md
|   `-- rtl/
|       `-- dual_fpga_system_pkg.vhd
+-- board/
|   `-- de10_lite/
|       +-- common/
|       |   `-- reset_sync.vhd
|       +-- fpga1/
|       |   `-- de10_lite_fpga1_wrapper.vhd
|       `-- fpga2/
|           `-- de10_lite_fpga2_wrapper.vhd
+-- fpga1_acquisition/
|   +-- src/
|   |   +-- pkg/
|   |   |   `-- fpga1_pkg.vhd
|   |   +-- processing/
|   |   |   +-- fake_sensor_gen.vhd
|   |   |   +-- sample_normalizer.vhd
|   |   |   +-- sample_validator.vhd
|   |   |   +-- sample_classifier.vhd
|   |   |   `-- threshold_detector.vhd
|   |   +-- link_tx/
|   |   |   +-- frame_builder.vhd
|   |   |   `-- uart_tx.vhd
|   |   `-- top/
|   |       `-- fpga1_top.vhd
|   +-- sim/
|   |   +-- uart_rx_monitor.vhd
|   |   `-- tb_fpga1_top.vhd
|   `-- quartus/
|       +-- add_sources.tcl
|       +-- add_de10_lite_wrapper_sources.tcl
|       `-- de10_lite_placeholder.qsf
+-- fpga2_display/
|   +-- src/
|   |   +-- pkg/
|   |   |   `-- fpga2_pkg.vhd
|   |   +-- link_rx/
|   |   |   +-- uart_rx.vhd
|   |   |   `-- frame_decoder.vhd
|   |   +-- control/
|   |   |   +-- link_statistics.vhd
|   |   |   `-- status_mapper.vhd
|   |   +-- display/
|   |   |   +-- led_driver.vhd
|   |   |   +-- vga_timing.vhd
|   |   |   `-- vga_dashboard.vhd
|   |   `-- top/
|   |       `-- fpga2_top.vhd
|   +-- sim/
|   |   +-- tb_link_statistics.vhd
|   |   `-- tb_fpga2_top.vhd
|   `-- quartus/
|       +-- add_sources.tcl
|       +-- add_de10_lite_wrapper_sources.tcl
|       `-- de10_lite_placeholder.qsf
`-- sim/
    +-- tb_fpga1_fpga2_integration.vhd
    `-- tb_de10_lite_wrappers.vhd
```

## Plan par phases

- Phase 1 : capteur factice, UART, verification/statistiques de reception,
  VGA minimal
- Phase 2 : remplacement du capteur factice par le chemin ADC DE10-Lite /
  MAX 10
- Phase 3 : durcissement de la verification de trame et de l'analyse de
  continuite
- Phase 4 : enrichissement du tableau de bord VGA
- Phase 5 : architecture prete pour une future sortie PC/logger

## Etat de verification

Verifie avec GHDL dans cette mise a jour du depot :

- `tb_fpga1_top`
- `tb_link_statistics`
- `tb_fpga2_top`
- `tb_fpga1_fpga2_integration`
- `tb_de10_lite_wrappers`

Non verifie dans cette mise a jour du depot :

- synthese Quartus
- fitting Quartus
- affectation reelle des broches VGA DE10-Lite
- integration ADC reelle du MAX 10
- bring-up materiel carte-a-carte

## Documents principaux

- `docs/system_architecture.md`
- `shared/protocol/frame_format.md`
- `docs/interface_spec.md`
- `docs/de10_lite_bringup.md`
- `docs/quartus_project_setup.md`
