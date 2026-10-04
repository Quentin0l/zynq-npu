"""modele_npu.py : le modèle de référence du moteur (NPU v1), en Python, exact au bit près.

Fourni par le parcours.

Partagé par les bancs cocotb à partir de l'exercice 0006. Tu connais déjà presque
tout : l'empaquetage des tuiles vient de l'exercice 0004, la requantification de
l'exercice 0005. Nouveau : couche_en_mots (toutes les tuiles d'une couche) et
couche_ref (une couche entière, int8 -> int8).
"""

import math
import random


# ---------------------------------------------------------------------------
# Le rangement des poids (exercice 0004).
# ---------------------------------------------------------------------------
def empaqueter(octets):
    """Liste d'octets signés -> un entier, l'octet k aux bits 8k+7 .. 8k."""
    v = 0
    for k, b in enumerate(octets):
        v |= (b & 0xFF) << (8 * k)
    return v


def couche_en_mots(W, P):
    """Les poids d'une couche -> les mots du tampon de poids, tuile après tuile.

    W a m lignes (une par sortie, donc une par MAC) et n colonnes (une par entrée).
    La tuile t regroupe les lignes t·P à t·P + P - 1 : les P sorties d'une passe.
    Chaque tuile donne n mots, un par colonne, comme à l'exercice 0004. Dans la
    dernière tuile, les lignes qui manquent sont des zéros.
    """
    m, n = len(W), len(W[0])
    mots = []
    for t in range(math.ceil(m / P)):
        lignes = W[t * P:(t + 1) * P]
        lignes = lignes + [[0] * n for _ in range(P - len(lignes))]
        mots += [empaqueter([ligne[j] for ligne in lignes]) for j in range(n)]
    return mots


# ---------------------------------------------------------------------------
# La requantification (exercice 0005).
# ---------------------------------------------------------------------------
def multiplicateur(M):
    """M réel dans ]0, 1[ -> (m0, n) entiers, avec M ≈ m0 · 2^-(31+n)."""
    n = 0
    while M * 2 ** n < 0.5:
        n += 1
    m0 = round(M * 2 ** n * 2 ** 31)
    if m0 == 2 ** 31:  # l'arrondi a atteint 1 : on renormalise
        m0, n = m0 // 2, n - 1
    return m0, n


def requant_ref(acc, bias, m0, n, zp, relu):
    """La spécification Q1 à Q5 : m0 et n sont les ENTIERS, pas le réel M."""
    s = 31 + n
    r = ((acc + bias) * m0 + (1 << (s - 1))) >> s
    y = r + zp
    plancher = zp if relu else -128
    return max(plancher, min(127, y))


# ---------------------------------------------------------------------------
# Une couche entière.
# ---------------------------------------------------------------------------
def couche_ref(W, b, x, M, zp, relu):
    """Une couche dense, int8 -> int8 : exactement ce que le NPU doit écrire."""
    m0, n = multiplicateur(M)
    return [requant_ref(sum(w * v for w, v in zip(ligne, x)), bk, m0, n, zp, relu)
            for ligne, bk in zip(W, b)]


def couche_aleatoire(n, m):
    """Des poids int8 symétriques, dans [-127, 127] (convention LiteRT), et m biais int32."""
    W = [[random.randint(-127, 127) for _ in range(n)] for _ in range(m)]
    b = [random.randint(-50_000, 50_000) for _ in range(m)]
    return W, b


def echelle_type(n):
    """Un M qui garde la plupart des sorties dans [-128, 127] : 1 / (128·√n).

    Avec des entrées et des poids int8 tirés au hasard, une somme de n produits a
    un écart-type d'environ 5 400·√n. Multipliée par M, il tombe à environ 42 :
    les sorties restent presque toutes dans [-128, 127], sans saturer.
    """
    return 1 / (128 * math.sqrt(n))


# ---------------------------------------------------------------------------
# Une couche et sa place dans les mémoires du NPU (exercices 0006 et suivants).
# ---------------------------------------------------------------------------
from dataclasses import dataclass  # noqa: E402


@dataclass
class Couche:
    """Une couche dense, ses constantes, et sa place dans les mémoires du NPU."""
    W: list          # m lignes de n poids int8
    b: list          # m biais corrigés int32 (le b' de la leçon 5)
    M: float         # le multiplicateur RÉEL ; le pilote en tire les entiers m0 et n
    zp: int          # point zéro de la sortie
    relu: bool
    w_base: int      # adresse de sa première tuile dans le tampon de poids
    bias_base: int   # adresse de son premier biais
    in_base: int     # zone de ses entrées dans le tampon d'activations
    out_base: int    # zone de ses sorties

    @property
    def n(self):
        return len(self.W[0])

    @property
    def m(self):
        return len(self.W)

    def ref(self, x):
        """Ce que la couche doit écrire, d'après le modèle de référence."""
        return couche_ref(self.W, self.b, x, self.M, self.zp, self.relu)


def duree(c, P):
    """Durée d'une couche avec le séquenceur de l'exercice 0006 : T·(n + 2) + m cycles."""
    return math.ceil(c.m / P) * (c.n + 2) + c.m
