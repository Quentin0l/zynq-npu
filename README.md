# zynq-npu

Un NPU systolique 8 × 8 en SystemVerilog, et le générateur de kernels qui le programme, sur ZedBoard (Zynq-7020).

[![CI](https://github.com/Quentin0l/zynq-npu/actions/workflows/ci.yml/badge.svg)](https://github.com/Quentin0l/zynq-npu/actions/workflows/ci.yml)

Un GEMM INT8 s'écrit dans un petit DSL qui sépare **l'algorithme**, ce que l'on calcule, du **schedule** : comment on le découpe en tuiles, et dans quel ordre. Le compilateur, écrit en C, abaisse le programme en nids de boucles, puis émet un flux de commandes. Le Cortex-A9 l'envoie au NPU par DMA, et le NPU le calcule sur un tableau systolique de 64 MAC, dans la logique programmable. Un simulateur en C sert de référence dorée : le RTL doit lui donner raison au bit près.

```mermaid
flowchart LR
    dsl["Programme DSL<br/>algorithme + schedule"] --> comp["Compilateur (C)<br/>lexeur, AST, nids de boucles"]
    comp --> cmd["Flux de commandes<br/>docs/interface.md"]
    cmd --> sim["Simulateur doré (C)"]
    cmd --> rt["Runtime bare-metal<br/>Cortex-A9"]
    rt -- "AXI DMA (HP)<br/>AXI4-Lite (GP)" --> npu["NPU dans la PL<br/>tableau systolique 8 × 8"]
    sim -. "mêmes octets" .- npu
```

## Où en est le projet

Huit semaines, du 5 octobre au 29 novembre 2026. Chaque semaine est un [jalon](https://github.com/Quentin0l/zynq-npu/milestones) ; le récit est dans le [journal](JOURNAL.md).

| Semaine | Objectif | État |
|---|---|---|
| [S1](https://github.com/Quentin0l/zynq-npu/milestone/1) · 5 au 11 oct. | Figer les deux contrats, finir le NPU | 🚧 |
| [S2](https://github.com/Quentin0l/zynq-npu/milestone/2) · 12 au 18 oct. | Première tuile sur le NPU, premières commandes du compilateur | ⏳ |
| [S3](https://github.com/Quentin0l/zynq-npu/milestone/3) · 19 au 25 oct. | Le simulateur doré et la co-simulation | ⏳ |
| [S4](https://github.com/Quentin0l/zynq-npu/milestone/4) · 26 oct. au 1er nov. | Sur la carte | ⏳ |
| [S5](https://github.com/Quentin0l/zynq-npu/milestone/5) · 2 au 8 nov. | Le schedule devient un paramètre | ⏳ |
| [S6](https://github.com/Quentin0l/zynq-npu/milestone/6) · 9 au 15 nov. | Les chiffres, dont le duel NEON contre NPU | ⏳ |
| [S7](https://github.com/Quentin0l/zynq-npu/milestone/7) · 16 au 22 nov. | Modèle de coût et autotuner | ⏳ |
| [S8](https://github.com/Quentin0l/zynq-npu/milestone/8) · 23 au 29 nov. | Montrer | ⏳ |

## Le dépôt

| Dossier | Contenu |
|---|---|
| `rtl/` | SystemVerilog : PE, tableau systolique, décalages d'entrée |
| `tb/` | Bancs cocotb + Verilator, modèle Python au bit près, mutants |
| `ref/` | GEMM de référence en C : naïf, et parcouru selon un schedule |
| `compiler/` | Le compilateur du DSL, en C (aujourd'hui : le lexeur) |
| `docs/` | Le contrat d'interface, la grammaire du DSL, le journal des bugs, les notes de lecture |

À venir : `sim/`, le simulateur doré (S3) ; `runtime/`, le code du Cortex-A9 (S2, S4) ; `bench/`, les mesures (S6, S7).

## Lancer les tests

Il faut Verilator 5.036 ou plus récent, Python 3 et un compilateur C.

```sh
python3 -m venv .venv && .venv/bin/pip install -r requirements.txt
make test
```

Ou une partie seulement : `tb/check.sh tableau`, `ref/check.sh`, `compiler/lexer/check.sh`.

**Des mutants pour juger les tests.** Chaque banc tourne d'abord sur le RTL, puis sur des copies où un bug a été planté (`tb/mutants/`). Si un mutant survit, il manque un test.

## La cible

ZedBoard, XC7Z020 : 53 200 LUT, 106 400 bascules, 220 DSP48E1, 140 BRAM de 36 Kb ; deux Cortex-A9 à 667 MHz ; quatre ports AXI HP de 64 bits vers 512 Mo de DDR3. Le tableau 8 × 8 occupe 64 DSP. À 100 MHz, il calcule au plus 6,4 GMAC/s.

## Conventions

SystemVerilog aux conventions ISMIN (Mines Saint-Étienne) : suffixes `_i`, `_o`, `_s`, `_g`, reset asynchrone actif bas `resetb_i`, blocs nommés. Code et documentation en français.

## Provenance

Projet personnel, mené avec un parcours d'apprentissage guidé par une IA (Claude, d'Anthropic) : leçons, squelettes d'exercices et outils de vérification. Les fichiers fournis en tout ou en partie par ce parcours le disent dans leur en-tête.
