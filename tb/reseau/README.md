# Le réseau réel : données du test de recette

`tb/test_reseau.py` fait tourner le vrai réseau de l'auteur sur le NPU v1, de bout en bout, et compare ses sorties à celles d'AIfES, au bit près. Ce dossier contient ses données.

| Fichier | Contenu | Provenance |
|---|---|---|
| `mnist_q7_params.bin` | La mémoire de paramètres d'AIfES, octet pour octet (578 044 octets) : poids int8, biais int32 et paramètres de quantification des 5 couches. Le format est décodé par `tb/aifes_q7.py`. | Le MLP Keras de l'auteur, 784 → 512 → 256 → 128 → 64 → 10, entraîné sur MNIST avec le prétraitement p/255 − 0,5, puis quantifié en Q7 par [AIfES-Converter](https://github.com/Fraunhofer-IMS/AIfES-Converter) (`aifes_q7_weights.h`). |
| `mnist_test_images.bin` | Les 4 premières images du jeu de test de MNIST, 784 octets chacune (pixels de 0 à 255). | [MNIST](http://yann.lecun.com/exdb/mnist/), © 1998 Yann LeCun et Corinna Cortes, sous licence [CC BY-SA 3.0](https://creativecommons.org/licenses/by-sa/3.0/). Ces images restent sous cette licence. |
| `mnist_test_labels.bin` | Leurs étiquettes, un octet par image. | Idem. |
| `aifes_logits.txt` | Les 10 logits int8 de chaque image (la couche dense 5, avant le softmax), calculés par le vrai AIfES en C. | `aifes_logits.c`, compilé avec les sources d'[AIfES for Arduino](https://github.com/Fraunhofer-IMS/AIfES_for_Arduino). |

## Régénérer

Après un nouvel entraînement, ou pour tester d'autres images :

```bash
cd tb/reseau
python3 extraire.py CHEMIN/aifes_q7_weights.h ~/.keras/datasets/mnist.npz 4
```

Puis compile et lance `aifes_logits.c`, comme l'indique son en-tête, pour récrire `aifes_logits.txt`. Enfin, `tb/check.sh reseau` vérifie le NPU sur les nouvelles données.

## Comment le NPU reproduit AIfES

- **Les poids sont symétriques** (point zéro nul), comme le NPU le suppose, et les biais sont des int32.
- **Les échelles d'AIfES sont des puissances de deux** : M = 2^−k, avec k = 12, 7, 8, 8 et 8. Le NPU les fait avec m0 = 2^30 et shift = k − 1.
- **Le NPU décale sans arrondir**, comme AIfES, depuis le 13 novembre 2026. Avec l'ancien arrondi, la précision montait à 98,07 % au lieu de 97,85 % sur les 10 000 images de test, mais aucune image ne donnait les mêmes logits qu'AIfES.
- **Le point zéro de l'entrée** des couches 2 à 5 (16, 31, 11, −3) est replié hors ligne dans le biais : b′ = b − z_entrée · ΣW.
- **La saturation du NPU** et le repli d'AIfES, qui convertit en int8 sans saturer, ne diffèrent qu'en cas de débordement. Il n'y en a aucun sur les 10 000 images de test.
- **La couche 1** (401 408 poids) ne tient pas dans les BRAM : ses poids arrivent en flux, les couches 2 à 5 restent dans le tampon de poids.
