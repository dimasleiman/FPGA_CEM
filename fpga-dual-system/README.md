# Projet UART entre deux FPGA

## Objectif

Ce projet implemente une communication UART simple entre deux cartes DE10-Lite :

- FPGA1 envoie en boucle des rafales d'octets de `0` a `255` apres le premier lancement
- FPGA2 recoit cette rafale, verifie chaque octet, compte les erreurs et affiche le resultat jusqu'au prochain reset manuel `KEY1`
- un fil dedie de synchronisation permet a FPGA2 de redemarrer proprement sa logique avant chaque nouvelle rafale

## Vue d'ensemble

### FPGA1

- attend un appui sur `KEY1` pour demarrer
- genere un signal de synchronisation `burst_sync_o` avant chaque rafale
- envoie en boucle des rafales UART `0..255`

### FPGA2

- attend le signal de synchronisation venant de FPGA1
- remet a zero sa logique de reception / verification
- recoit la rafale UART
- compare chaque octet recu avec un compteur attendu local
- incremente un compteur d'erreurs si un octet est incorrect
- affiche le nombre d'erreurs sur `HEX2..HEX0` jusqu'au prochain reset manuel `KEY1`
- fait clignoter les `LEDR[9:2]` a `2 Hz` si au moins une erreur a ete detectee, jusqu'au prochain reset manuel `KEY1`; `LEDR1` s'allume lors de la reception UART

## Protocole

- sequence envoyee : `0, 1, 2, ..., 255`
- une rafale contient `256` trames UART
- quand FPGA1 termine l'octet `255`, il remet son compteur a `0`, renvoie une synchronisation a FPGA2, attend environ `1 ms`, puis recommence
- FPGA2 commence chaque nouvelle rafale avec une valeur attendue egale a `0`
- a chaque octet recu, FPGA2 compare l'octet a la valeur attendue
- apres chaque octet recu, FPGA2 avance quand meme sa valeur attendue, que la comparaison soit correcte ou non

Exemple :

- sequence attendue : `10 11 12 13 14 15`
- sequence recue : `10 11 18 13 14 15`
- une seule erreur est comptee sur l'octet `18`
- les octets suivants restent correctement verifies

## Synchronisation dediee

Un fil supplementaire relie FPGA1 a FPGA2 :

- FPGA1 sort `burst_sync_o`
- FPGA2 recoit `burst_sync_i`

Role de ce fil :

- annoncer le debut d'une nouvelle rafale
- annoncer aussi chaque redemarrage automatique apres `255`
- remettre FPGA2 dans un etat propre avant l'arrivee des octets UART
- le pulse manuel venant de `KEY1` est plus long et fait clignoter `LEDR0`
- le pulse automatique apres `255` est plus court et ne fait pas clignoter `LEDR0`
- eviter un demarrage des deux cartes base uniquement sur un reset manuel

Sur FPGA2, chaque pulse de synchronisation provoque :

- la remise a zero du recepteur UART
- la remise a zero du compteur attendu

Seul le pulse manuel declenche par `KEY1` provoque aussi :

- la remise a zero du compteur d'erreurs
- la remise a zero de l'indication d'erreur
- le flash `LEDR0`

## Fonctionnement detaille

### 1. Etat initial

- FPGA1 est en `IDLE`
- FPGA2 est en `IDLE`
- le compteur attendu de FPGA2 vaut `0`
- le compteur d'erreurs de FPGA2 vaut `0`

### 2. Lancement d'une rafale

- l'utilisateur appuie sur `KEY1` sur FPGA1
- FPGA1 active `burst_sync_o`
- FPGA2 detecte ce signal et redemarre sa logique de verification
- FPGA2 fait clignoter `LEDR0` a `10 Hz` pendant environ `1 s` pour indiquer ce demarrage manuel
- FPGA1 attend environ `1 ms` apres la synchronisation
- FPGA1 commence ensuite l'envoi UART `0..255`

### 3. Verification cote FPGA2

- FPGA2 attend le premier octet UART valide
- le premier octet est compare a `0`
- chaque octet suivant est compare a la valeur attendue courante
- en cas de mismatch, seul le compteur d'erreurs est incremente
- la valeur attendue continue d'avancer normalement

### 4. Fin de rafale et boucle

- quand FPGA2 traite l'octet final attendu `255`, la rafale se termine
- FPGA2 revient en `IDLE`
- FPGA1 detecte la fin de sa rafale et prepare automatiquement la suivante
- FPGA1 reactive `burst_sync_o` pour remettre FPGA2 a zero
- ce redemarrage automatique ne fait pas clignoter `LEDR0`
- ce redemarrage automatique ne remet pas a zero le compteur d'erreurs ni les `LEDR[9:2]`
- FPGA1 attend environ `1 ms`, puis recommence l'envoi a partir de `0`
- l'affichage d'erreurs de FPGA2 est remis a `0` seulement par le reset manuel `KEY1`

## Affichage

### FPGA1

- `LEDR[9:0]` : eteintes

### FPGA2

- sans erreur et hors indication de demarrage manuel, `LEDR0` et `LEDR[9:2]` restent eteintes; `LEDR1` indique la reception UART
- apres la synchro manuelle declenchee par `KEY1`, `LEDR0` clignote a `10 Hz` pendant environ `1 s`
- pendant les redemarrages automatiques apres `255`, `LEDR0` ne clignote pas
- `LEDR1` s'allume pendant l'arrivee des octets UART de FPGA1
- avec au moins une erreur, les `LEDR[9:2]` clignotent ensemble a `2 Hz`; `LEDR0` reste reservee au demarrage manuel
- `HEX2..HEX0` : nombre decimal d'erreurs
- `HEX5..HEX3` : eteints

## Broches importantes

### Boutons

- `KEY0` : `PIN_B8` : reset local
- `KEY1` : `PIN_A7` : lancement de rafale sur FPGA1
- un bouton externe peut aussi etre relie a `PIN_B8` sur les deux cartes pour un reset partage

### Liaison entre les cartes

- UART data :
- FPGA1 `uart_tx_o` : `PIN_V10`
- FPGA2 `uart_rx_i` : `PIN_V10`

- Sync / restart :
- FPGA1 `burst_sync_o` : `PIN_W10`
- FPGA2 `burst_sync_i` : `PIN_W10`

- relier aussi les masses des deux cartes

## Workflow sur carte

1. Programmer FPGA1 avec `fpga1_acquisition/quartus/de10_lite_fpga1_wrapper.qpf`.
2. Programmer FPGA2 avec `fpga2_display/quartus/de10_lite_fpga2_wrapper.qpf`.
3. Relier `PIN_V10` de FPGA1 a `PIN_V10` de FPGA2.
4. Relier `PIN_W10` de FPGA1 a `PIN_W10` de FPGA2.
5. Relier les masses des deux cartes.
6. Si necessaire, appuyer sur `KEY0` (`PIN_B8`) pour un reset local.
7. Appuyer sur `KEY1` sur FPGA1.
8. FPGA1 envoie d'abord la synchro, attend environ `1 ms`, puis envoie la rafale UART `0..255`.
9. Apres `255`, FPGA1 renvoie automatiquement la synchro, attend environ `1 ms`, puis recommence a `0`.
10. Observer FPGA2 :
11. en l'absence d'erreur, `LEDR0` et `LEDR[9:2]` restent eteintes hors flash de demarrage manuel; `LEDR1` s'allume pendant la reception UART.
12. `LEDR1` s'allume quand FPGA2 recoit des donnees UART depuis FPGA1.
13. si une erreur existe dans la rafale courante, les `LEDR[9:2]` clignotent ensemble a `2 Hz`; `LEDR0` reste reservee au demarrage manuel.
14. `HEX2..HEX0` affichent le nombre d'erreurs de la rafale courante.

## Quartus

Projets a ouvrir :

- `fpga1_acquisition/quartus/de10_lite_fpga1_wrapper.qpf`
- `fpga2_display/quartus/de10_lite_fpga2_wrapper.qpf`

Top-levels :

- `de10_lite_fpga1_wrapper`
- `de10_lite_fpga2_wrapper`

## Arborescence

```text
fpga-dual-system/
+-- README.md
+-- shared/
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
|   |   +-- display/
|   |   |   +-- bin_to_bcd.vhd
|   |   |   `-- digit_to_7seg_decimal_n.vhd
|   |   +-- link_tx/
|   |   |   `-- uart_tx.vhd
|   |   `-- top/
|   |       `-- fpga1_top.vhd
|   `-- quartus/
|       +-- add_sources.tcl
|       +-- add_de10_lite_wrapper_sources.tcl
|       +-- de10_lite_fpga1_wrapper.qpf
|       +-- de10_lite_fpga1_wrapper.qsf
|       +-- de10_lite_fpga1_wrapper.sdc
|       `-- de10_lite_placeholder.qsf
+-- fpga2_display/
|   +-- src/
|   |   +-- link_rx/
|   |   |   `-- uart_rx.vhd
|   |   `-- top/
|   |       `-- fpga2_top.vhd
|   `-- quartus/
|       +-- add_sources.tcl
|       +-- add_de10_lite_wrapper_sources.tcl
|       +-- de10_lite_fpga2_wrapper.qpf
|       +-- de10_lite_fpga2_wrapper.qsf
|       +-- de10_lite_fpga2_wrapper.sdc
|       `-- de10_lite_placeholder.qsf
```
