# Le DSL de zynq-npu

> **Statut : brouillon (v0).** Ce document se fige en S1 (v1.0). Ensuite, tout changement donne une nouvelle version et une ligne dans l'historique, en bas.

Un programme sépare deux choses : **ce que** l'on calcule (le bloc algorithme) et **comment** on le calcule sur le NPU (le bloc schedule). Changer le schedule ne change jamais le résultat, seulement l'ordre des calculs et les mouvements de données. Ce document fixe la syntaxe (lexique et grammaire) et le sens de chaque construction.

<!--
Mode d'emploi (à effacer une fois le document écrit). Remplace chaque question
par ta réponse. La leçon 5 du parcours compilateurs explique la séparation
algorithme / schedule, et rappelle la notation EBNF.
-->

## 1. Périmètre de la v1

- Types : tenseurs int8 et int32, de quelles formes ?
- Opérations : `matmul`, `requant`, `relu`. Avec quels paramètres ?
- Schedule : tuiles M, N, K, ordre des boucles, projection sur le matériel (les P MAC du moteur), poids résidents, double tampon.
- Hors périmètre de la v1 : ?

## 2. Deux programmes d'exemple

Le même algorithme, sous deux schedules différents.

```text
(à écrire)
```

## 3. Lexique

| Catégorie | Lexèmes | Exemple |
|---|---|---|
| Mots-clés | | |
| Ponctuation | | |
| Nombres | | |
| Identifiants | | |
| Commentaires | | |

## 4. Grammaire

Notation de la leçon 3 du parcours compilateurs : `"x"` entre guillemets est un token ; un nom sans guillemets est une règle ; un espace veut dire « puis » ; `|` veut dire « ou » ; `( … )*` répète le groupe 0, 1 ou plusieurs fois ; `( … )?` le rend facultatif.

```ebnf
programme = ...
```

## 5. Sens

- Les règles de forme : quand deux tenseurs sont-ils compatibles ?
- Ce qu'un schedule a le droit de dire, et ce qui le rend invalide : empreinte des tampons, ordres de boucles interdits (cf. `docs/interface.md`, § 4).
- Les messages d'erreur : que dit le compilateur, et avec quelle position (ligne, colonne) ?

## 6. Ce que produit le compilateur

Pour chaque construction : sa forme dans l'IR en nids de boucles (S2), puis dans le flux de commandes (`docs/interface.md`).

## Historique

| Version | Date | Changement |
|---|---|---|
| 0 | 2026-10-04 | Squelette du document |
