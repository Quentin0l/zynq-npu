# Contrat d'interface du NPU

> **Statut : brouillon (v0).** Ce document se fige en S1 (v1.0). Ensuite, tout changement donne une nouvelle version et une ligne dans l'historique, en bas.

Ce document est le contrat entre quatre implémentations qui ne doivent jamais diverger : le RTL (`rtl/`), le compilateur (`compiler/`), le simulateur doré (`sim/`, S3) et le runtime du Cortex-A9 (`runtime/`, S2 et S4). Chacune se construit à partir de lui seul.

Il décrit le NPU v1, le moteur de `rtl/moteur/`. Le tableau v2 (`rtl/tableau/`) devra pouvoir se brancher derrière le même contrat : une commande dit quoi calculer et où sont les données, pas comment le matériel s'y prend.

**Le test d'un bon contrat.** Deux personnes qui ne se parlent pas l'implémentent chacune de leur côté. Leurs octets sont identiques, au bit près.

<!--
Mode d'emploi (à effacer une fois le document écrit). Chaque section pose les
questions auxquelles elle doit répondre. Remplace les questions par tes
réponses : des tableaux, des largeurs en bits, des exemples en hexadécimal.
Une réponse du type « à voir » ou « selon les cas » n'en est pas une. La leçon 9
du parcours accélérateurs présente les options et leurs coûts.
-->

## 1. Vue d'ensemble

<!-- Un schéma (ASCII ou mermaid) : le PS (Cortex-A9, DDR), les ports GP et HP,
l'AXI DMA, le NPU (tampons, moteur, contrôle). Pour chaque lien : qui est
maître, qui est esclave ? -->

## 2. Registres de contrôle (AXI4-Lite, port M_AXI_GP0)

| Offset | Nom | Accès | Champs | Valeur au reset |
|---|---|---|---|---|
| 0x00 | | | | |

À trancher ici :
- Comment l'ARM lance-t-il le NPU, et comment sait-il qu'il a fini : scrutation d'un registre, ou interruption ?
- Où lit-il le compteur de cycles du NPU (S4) ?
- Que fait le NPU d'une commande invalide : un bit d'erreur, un code, un arrêt ?
- Comment le runtime vérifie-t-il qu'il parle au bon bitstream (registre de version) ?

## 3. Le flux de commandes

### 3.1 Transport

- Par où les commandes arrivent-elles : registres, AXI-Stream depuis le DMA, mémoire de commandes dans le NPU ?
- Commandes et données partagent-elles le même flux ? Sinon, comment le NPU sait-il quelles données vont avec quelle commande ?

### 3.2 Format binaire

- Taille d'une commande : fixe ou variable ? Un multiple de la largeur du bus ?
- Position et largeur de chaque champ, en bits. Ordre des octets dans un mot.
- Bits réservés : quelle valeur, et le NPU la vérifie-t-il ?

| Bits | Champ | Signification |
|---|---|---|
| | | |

### 3.3 Les commandes

Pour chacune : son code, ses champs, son effet exact sur les tampons et les accumulateurs, ses préconditions, et sa durée en cycles.

### 3.4 Ordre et fin

- Les commandes s'exécutent-elles strictement l'une après l'autre, ou certaines peuvent-elles se recouvrir (chargement pendant un calcul) ?
- Comment le flux se termine-t-il : une commande de fin, TLAST, un nombre de commandes écrit dans un registre ?

## 4. Les tampons locaux

| Tampon | Rôle | Largeur d'un mot | Profondeur | Ce que contient un mot | Double tampon ? |
|---|---|---|---|---|---|
| poids | | | | | |
| activations | | | | | |
| biais | | | | | |

À trancher ici :
- Combien de MAC (P) ? Ce nombre fixe la largeur d'un mot de poids : P octets.
- Dans les commandes, une adresse compte-t-elle des mots ou des octets ?
- Une somme partielle peut-elle quitter les accumulateurs puis y revenir ? Cela décide quels ordres de boucles le compilateur a le droit d'émettre (voir le tableau de trafic de `ref/check.sh`).
- Que sort le NPU : des int32 bruts, ou des int8 requantifiés ? Qui requantifie ?

## 5. Largeurs des bus et chemins de données

| Lien | Protocole | Largeur | Fréquence | Débit théorique |
|---|---|---|---|---|
| ARM → NPU, contrôle | AXI4-Lite, M_AXI_GP0 | | | |
| DDR → NPU, données | AXI DMA (MM2S) → AXI-Stream, S_AXI_HP0 | | | |
| NPU → DDR, résultats | AXI-Stream → AXI DMA (S2MM), S_AXI_HP0 | | | |

## 6. Rangement en mémoire (DDR)

- Comment A, B et C sont-ils rangés en DDR : par lignes, ou déjà découpés en tuiles ? Qui fait le réarrangement : le compilateur, le runtime ou le matériel ?
- Quel alignement pour chaque tableau ?

## 7. Exemple complet

Un GEMM 16 × 16 × 16, requantifié en int8 : la suite exacte des commandes, mot par mot, en hexadécimal, avec un commentaire par ligne.

```text
(à écrire)
```

## 8. Hors contrat (v1)

<!-- Ce que la v1 ne fait volontairement pas. -->

## Historique

| Version | Date | Changement |
|---|---|---|
| 0 | 2026-10-04 | Squelette du document |
