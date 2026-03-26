# Architecture Systeme

## Coherence du flux cible

Le flux demande est coherent pour une plateforme double DE10-Lite :

1. FPGA1 acquiert un echantillon capteur.
2. FPGA1 normalise, valide et classe cet echantillon.
3. FPGA1 transmet a FPGA2 une trame UART structuree.
4. FPGA2 verifie la structure de la trame, le CRC et la continuite de
   sequence.
5. FPGA2 met a jour ses statistiques et l'etat de son tableau de bord.
6. FPGA2 genere une sortie VGA simple.

La separation pratique par phases est la suivante :

- phase 1 : capteur factice + UART + traitement cote reception + VGA
- phase 2 : acquisition ADC reelle MAX 10 sur FPGA1

## Chaine de traitement FPGA1

Chaine coeur reutilisable actuelle :

`sample_source -> sample_normalizer -> sample_validator -> sample_classifier -> frame_builder -> uart_tx`

Selection actuelle du `sample_source` au niveau wrapper FPGA1 :

- `fake_sensor_gen` pour un capteur factice analogique/temperature
- une source de test fixe pour les simulations de bring-up
- `max10_adc_frontend` pour l'acquisition ADC MAX 10 reelle

Le coeur `fpga1_top` reste source-agnostique et consomme seulement
`sample_value_i` / `sample_valid_i`.

## Chaine de traitement FPGA2

Chaine reutilisable actuelle :

`uart_rx -> frame_decoder -> link_statistics -> status_mapper -> led_driver`

Chaine d'affichage :

`link_statistics -> vga_timing -> vga_dashboard`

## Strategie VGA de phase 1

La premiere implementation VGA reste volontairement simple :

- chiffres hexadecimaux de style 7 segments pour :
  - la valeur courante du capteur
  - le nombre de trames valides
  - le nombre de trames corrompues
  - le nombre de trames manquantes
  - le nombre de timeouts
- un indicateur a trois cases pour l'etat capteur
- une case d'etat de communication
- une jauge verticale du capteur

Cette approche evite d'introduire immediatement un moteur de texte complet tout
en gardant une architecture extensible vers un tableau de bord plus riche.

## Perimetre de verification

Verifie :

- le chemin RTL de phase 1 via simulation GHDL
- la gestion des trames corrompues, manquantes et des timeouts en simulation
- l'activite de timing VGA et la production de pixels non noirs en simulation

Suppose :

- l'affectation finale des broches VGA DE10-Lite
- le choix final de la polarite de reset
- les futurs details d'IP/wrapper ADC MAX 10

Travail Quartus manuel restant :

- affectations de broches reelles
- affectations des standards d'E/S
- configuration finale des generiques wrappers
- generation de l'IP ADC et integration associee
- bring-up carte et validation sur moniteur
