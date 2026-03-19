# Transition vers Quartus

Ce depot est structure de facon a permettre a Quartus de consommer le design au
niveau wrapper sans melanger les choix specifiques a la carte avec le coeur
reutilisable.

## Ce qu'il faut utiliser

Utiliser les entrees versionnees suivantes :

- le RTL reutilisable dans `fpga1_acquisition/src/` et `fpga2_display/src/`
- le RTL partage dans `shared/rtl/`
- les wrappers DE10-Lite dans `board/de10_lite/`
- les scripts Tcl dans chaque dossier `quartus/`
- les fichiers `.qsf` placeholders
- les fichiers `.sdc` deja stockes dans les dossiers Quartus

Ne pas considerer les fichiers generes par Quartus dans `db/`, `output_files/`
ou `.qws` comme source principale de verite.

## Choix du top-level

Tops Quartus recommandes :

- FPGA1 : `de10_lite_fpga1_wrapper`
- FPGA2 : `de10_lite_fpga2_wrapper`

Cela permet de garder :

- la gestion du reset dans le wrapper
- le mapping de broches dans les `.qsf`
- la logique reutilisable dans la hierarchie coeur

## Etat actuel de verification

Verifie sous GHDL :

- generation de trame
- verification de trame
- suivi des statistiques
- activite du tableau de bord VGA
- testbenches au niveau coeur et wrapper

Non verifie ici :

- analyse / synthese / fitter Quartus
- programmation materielle
- validation sur moniteur reel DE10-Lite
- integration ADC MAX 10

## Flow Quartus pratique

Pour chaque FPGA :

1. Ouvrir ou creer le projet Quartus dans le dossier `quartus/` correspondant.
2. Confirmer que le composant cible est `10M50DAF484C7G`.
3. Selectionner le wrapper comme top-level.
4. Executer `source add_de10_lite_wrapper_sources.tcl`.
5. Integrer le contenu du `.qsf` placeholder.
6. Renseigner les broches carte et standards d'E/S reels.
7. Compiler.

## Decisions manuelles encore necessaires

- polarite finale du reset
- choix des broches UART entre les cartes
- mapping du connecteur VGA
- utilisation ou non des LED pour le bring-up
- future integration de l'IP ADC et du chemin analogique
