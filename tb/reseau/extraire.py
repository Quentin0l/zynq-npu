"""extraire.py : régénère les données du test du réseau réel (tb/test_reseau.py).

Provenance : ajouté le 2026-11-13 par le parcours.

Usage : python3 tb/reseau/extraire.py CHEMIN/aifes_q7_weights.h [CHEMIN/mnist.npz] [NB]
  - mnist_q7_params.bin : la mémoire de paramètres d'AIfES, octet pour octet ;
  - mnist_test_images.bin et mnist_test_labels.bin : les NB premières images du
    jeu de test de MNIST (784 octets chacune, de 0 à 255) et leurs étiquettes,
    lues dans le mnist.npz que tf.keras télécharge (~/.keras/datasets/mnist.npz).
Python pur : zipfile et l'en-tête .npy suffisent, pas besoin de numpy. Ensuite,
aifes_logits.c recalcule les logits de référence avec le vrai AIfES, en C.
"""

import ast
import sys
import zipfile
from pathlib import Path

ICI = Path(__file__).resolve().parent
sys.path.insert(0, str(ICI.parent))
from aifes_q7 import decoder, lire_entete  # noqa: E402


def lire_npy(archive, nom):
    """Un tableau uint8 d'un .npz -> (octets bruts, forme)."""
    data = archive.read(nom)
    assert data[:6] == b"\x93NUMPY", nom
    taille_entete = 2 if data[6] == 1 else 4
    longueur = int.from_bytes(data[8:8 + taille_entete], "little")
    debut = 8 + taille_entete + longueur
    entete = ast.literal_eval(data[8 + taille_entete:debut].decode("latin1"))
    assert entete["descr"] in ("|u1", "<u1") and not entete["fortran_order"], entete
    return data[debut:], entete["shape"]


def main():
    entete_h = sys.argv[1]
    npz = Path(sys.argv[2] if len(sys.argv) > 2 else Path.home() / ".keras/datasets/mnist.npz")
    nb = int(sys.argv[3]) if len(sys.argv) > 3 else 4

    mem = lire_entete(entete_h)
    decoder(mem)                                  # vérifie la disposition avant d'écrire
    (ICI / "mnist_q7_params.bin").write_bytes(mem)

    with zipfile.ZipFile(npz) as z:
        images, forme = lire_npy(z, "x_test.npy")
        etiquettes, _ = lire_npy(z, "y_test.npy")
    assert tuple(forme[1:]) == (28, 28), forme
    (ICI / "mnist_test_images.bin").write_bytes(images[:nb * 784])
    (ICI / "mnist_test_labels.bin").write_bytes(etiquettes[:nb])
    print(f"{len(mem)} octets de paramètres, {nb} images et leurs étiquettes écrits dans {ICI}")


if __name__ == "__main__":
    main()
