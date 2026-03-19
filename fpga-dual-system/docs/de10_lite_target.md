# Remarques sur la Cible DE10-Lite

Ce depot cible la carte Terasic DE10-Lite avec le composant
`10M50DAF484C7G`.

Ressources carte pertinentes pour la direction actuelle du projet :

- horloge embarquee `50 MHz`
- LED utilisateur
- interrupteurs / boutons poussoirs pour le choix du reset
- sortie VGA
- chemin ADC integre du MAX 10 accessible via le chemin analogique de la carte

Utilisation actuelle dans le depot :

- FPGA1 : horloge, reset, emission UART
- FPGA2 : horloge, reset, reception UART, resume LED, sortie VGA

Utilisation prevue plus tard :

- acquisition ADC MAX 10 sur FPGA1 en phase 2

Regles du depot pour cette cible :

- ne pas coder en dur les positions de broches dans le RTL reutilisable
- ne pas inventer les noms finaux des signaux carte
- garder les affectations Quartus exactes manuelles jusqu'au choix final
- ne pas supposer la polarite finale du reset
- ne pas supposer la presence d'un ADC externe

Etat important :

- le RTL cote VGA est present et verifie en simulation
- l'integration RTL / IP ADC n'est pas encore presente
- la compilation Quartus n'a pas ete relancee dans cette mise a jour du depot
