# Format de Trame UART

La liaison UART inter-FPGA transporte maintenant une trame fixe de 8 octets par
echantillon transmis. Le format reste accessible a un niveau etudiant tout en
etant suffisamment robuste pour de futures experiences de test d'immunite.

## Organisation des octets

| Index octet | Nom          | Signification |
|-------------|--------------|---------------|
| 0           | Header       | Valeur fixe `x"A5"` |
| 1           | Control      | Valeur fixe `x"11"` pour la version 1 du protocole / trame capteur |
| 2           | Sequence     | Compteur de sequence sur 8 bits |
| 3           | Payload High | Bits `[3:0]` = bits echantillon `[11:8]`, bits `[7:4]` reserves a `0` |
| 4           | Payload Low  | Bits echantillon `[7:0]` |
| 5           | Flags        | Drapeaux warning / error / validite plage / source ADC |
| 6           | CRC8         | CRC8 calcule sur les octets 1 a 5 |
| 7           | Footer       | Valeur fixe `x"5A"` |

## Reconstruction de l'echantillon

La charge utile transporte actuellement une valeur capteur sur 12 bits :

```text
sample_value = byte3(3 downto 0) & byte4
```

## Drapeaux

`byte5` utilise actuellement :

- bit 0 : etat warning
- bit 1 : etat error
- bit 2 : validite de la plage de mesure
- bit 3 : source echantillon = ADC reel
- bits 7 downto 4 : reserves, doivent rester a `0`

En phase 1, le bit source reste a `0` car le depot utilise encore le
generateur de capteur factice.

## Controle d'integrite

Le CRC8 utilise le polynome `x^8 + x^2 + x + 1` (`0x07`) avec une valeur
initiale `0x00`.

Le recepteur considere une trame comme structurellement valide uniquement si
tous les points suivants sont corrects :

- header
- octet de controle
- bits reserves de la charge utile
- bits reserves des drapeaux
- CRC8
- footer

## Objectifs de detection cote recepteur

Le RTL cote recepteur est concu pour detecter :

- les trames corrompues
- les trames manquantes via les sauts de sequence
- les headers invalides pendant la recherche de debut de trame
- les footers invalides
- les CRC8 invalides
- les conditions de timeout / absence de trame
