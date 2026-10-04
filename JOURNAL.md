# Journal d'avancement

Une section par semaine : l'objectif, les tâches, puis, la semaine finie, ce qui a marché et ce qui a cassé. L'état des tâches vit dans les [issues](https://github.com/Quentin0l/zynq-npu/issues) ; ce journal garde le récit.

## Avant S1 : l'état au 4 octobre 2026

- **NPU v1, le moteur** (`rtl/moteur/`), construit brique par brique dans un parcours d'apprentissage, du 25 septembre au 4 octobre. Il comprend un MAC int8, une rangée de MAC, un tampon de poids en BRAM et son moteur de passe, la requantification int32 → int8 avec ReLU, et un séquenceur qui exécute une couche entière. Les 5 bancs passent, et chacun tue ses 3 mutants. En simulation, le moteur exécute le MLP 512 → 256 → 128 → 64 → 10 de bout en bout.
- **NPU v2, le tableau** (`rtl/tableau/`) : un PE output-stationary et le tableau systolique n × n qui les assemble. En 8 × 8, il passe son premier test cocotb, une tuile 8 × 8 × 8.
- **Compilateur** : un lexeur pour un sous-ensemble de C (`compiler/lexer/`), 84 tokens vérifiés.
- **Décision du 4 octobre.** Le moteur, déjà vérifié, est le NPU des huit semaines (v1). Le tableau 8 × 8 devient la v2, derrière le même contrat d'interface, si le temps le permet. Ce choix sert la S4, la semaine la plus risquée : arriver sur la carte avec un NPU déjà vérifié.

## S1 · 5 au 11 octobre · Figer les deux contrats, finir le NPU

Livrable : deux pages figées, l'interface du NPU et la grammaire du DSL ; un lexeur terminé ; le NPU v1 piloté selon le contrat. [Jalon S1](https://github.com/Quentin0l/zynq-npu/milestone/1).

- [#1](https://github.com/Quentin0l/zynq-npu/issues/1) NPU v1 : le moteur dans le dépôt, puis piloté par commandes
- [#2](https://github.com/Quentin0l/zynq-npu/issues/2) Écrire le contrat d'interface du NPU
- [#3](https://github.com/Quentin0l/zynq-npu/issues/3) Lire Halide : l'introduction et le langage de schedule
- [#4](https://github.com/Quentin0l/zynq-npu/issues/4) Grammaire du DSL et lexeur

**Bilan de la semaine** : à écrire le 11 octobre. Ce qui a marché, ce qui a cassé, ce qui glisse en S2.

## S2 à S8

Les tâches sont dans les jalons [S2](https://github.com/Quentin0l/zynq-npu/milestone/2), [S3](https://github.com/Quentin0l/zynq-npu/milestone/3), [S4](https://github.com/Quentin0l/zynq-npu/milestone/4), [S5](https://github.com/Quentin0l/zynq-npu/milestone/5), [S6](https://github.com/Quentin0l/zynq-npu/milestone/6), [S7](https://github.com/Quentin0l/zynq-npu/milestone/7) et [S8](https://github.com/Quentin0l/zynq-npu/milestone/8). Chaque section s'ouvre ici le lundi de sa semaine. La v2 a son issue à part, sans jalon : [#34](https://github.com/Quentin0l/zynq-npu/issues/34).
