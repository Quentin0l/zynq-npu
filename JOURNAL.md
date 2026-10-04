# Journal d'avancement

Une section par semaine : l'objectif, les tâches, puis, la semaine finie, ce qui a marché et ce qui a cassé. L'état des tâches vit dans les [issues](https://github.com/Quentin0l/zynq-npu/issues) ; ce journal garde le récit.

## Avant S1 : l'état au 4 octobre 2026

- **RTL.** Un PE output-stationary (`rtl/pe.sv`) et le tableau systolique paramétrable qui en assemble n × n (`rtl/systolic_array.sv`). En 8 × 8, il passe son premier test cocotb : une tuile 8 × 8 × 8.
- **Compilateur.** Un lexeur pour un sous-ensemble de C (`compiler/lexer/`) : 84 tokens vérifiés.
- **Hors de ce dépôt**, dans un parcours d'apprentissage : un moteur matrice-vecteur complet, vérifié brique par brique avec cocotb et des mutants. Il comprend un MAC int8, une rangée de MAC, un tampon de poids, la requantification int32 → int8, un séquenceur de couche et un esclave AXI4-Lite. La requantification et l'esclave AXI4-Lite reviendront ici quand la feuille de route en aura besoin (S3, S5).

## S1 · 5 au 11 octobre · Figer les deux contrats, finir le NPU

Livrable : deux pages figées, l'interface du NPU et la grammaire du DSL ; un lexeur terminé ; le tableau 8 × 8 vérifié. [Jalon S1](https://github.com/Quentin0l/zynq-npu/milestone/1).

- [#1](https://github.com/Quentin0l/zynq-npu/issues/1) Finir le RTL du tableau 8×8 et de son contrôle
- [#2](https://github.com/Quentin0l/zynq-npu/issues/2) Écrire le contrat d'interface du NPU
- [#3](https://github.com/Quentin0l/zynq-npu/issues/3) Lire Halide : l'introduction et le langage de schedule
- [#4](https://github.com/Quentin0l/zynq-npu/issues/4) Grammaire du DSL et lexeur

**Bilan de la semaine** : à écrire le 11 octobre. Ce qui a marché, ce qui a cassé, ce qui glisse en S2.

## S2 à S8

Les tâches sont dans les jalons [S2](https://github.com/Quentin0l/zynq-npu/milestone/2), [S3](https://github.com/Quentin0l/zynq-npu/milestone/3), [S4](https://github.com/Quentin0l/zynq-npu/milestone/4), [S5](https://github.com/Quentin0l/zynq-npu/milestone/5), [S6](https://github.com/Quentin0l/zynq-npu/milestone/6), [S7](https://github.com/Quentin0l/zynq-npu/milestone/7) et [S8](https://github.com/Quentin0l/zynq-npu/milestone/8). Chaque section s'ouvre ici le lundi de sa semaine.
