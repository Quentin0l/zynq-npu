"""modele.py : le modèle de référence du NPU, en Python, exact au bit près.

Fourni par le parcours, à enrichir au fil des semaines.

Partagé par tous les bancs de tb/. Un banc compare toujours le RTL à ce modèle,
jamais à une valeur recopiée d'une simulation.

Conventions :
  - une matrice est une liste de lignes : A[i][k] ;
  - un mot de n voies range la voie r aux bits r*w + w-1 .. r*w (voie 0 en bas),
    comme les ports a_row_i, b_col_i et data_i du RTL.
"""

import random


# ---------------------------------------------------------------------------
# Mots de plusieurs voies.
# ---------------------------------------------------------------------------
def empaqueter(valeurs, largeur=8):
    """Liste d'entiers signés -> un entier, la voie r aux bits r*largeur et suivants."""
    masque = (1 << largeur) - 1
    v = 0
    for r, x in enumerate(valeurs):
        v |= (x & masque) << (largeur * r)
    return v


def depaqueter(v, nb, largeur=8, signe=True):
    """Un entier -> nb voies de `largeur` bits, signées par défaut."""
    masque = (1 << largeur) - 1
    voies = []
    for r in range(nb):
        x = (v >> (largeur * r)) & masque
        if signe and x >> (largeur - 1):
            x -= 1 << largeur
        voies.append(x)
    return voies


# ---------------------------------------------------------------------------
# Matrices.
# ---------------------------------------------------------------------------
def matrice_aleatoire(lignes, colonnes, bas=-128, haut=127):
    """Une matrice d'entiers tirés dans [bas, haut], chaque case tirée séparément."""
    return [[random.randint(bas, haut) for _ in range(colonnes)] for _ in range(lignes)]


def gemm_ref(A, B):
    """C = A x B, en entiers exacts (Python ne déborde jamais) : la référence dorée."""
    K = len(B)
    assert all(len(ligne) == K for ligne in A), "A doit avoir autant de colonnes que B de lignes"
    return [[sum(A[i][k] * B[k][j] for k in range(K)) for j in range(len(B[0]))]
            for i in range(len(A))]


def ecart(C, attendu):
    """Message lisible pour un assert : la première case fausse, et combien le sont."""
    fausses = [(i, j) for i in range(len(attendu)) for j in range(len(attendu[0]))
               if C[i][j] != attendu[i][j]]
    if not fausses:
        return "aucun écart"
    i, j = fausses[0]
    return (f"C[{i}][{j}] = {C[i][j]}, attendu {attendu[i][j]} "
            f"({len(fausses)} case(s) fausse(s) sur {len(attendu) * len(attendu[0])})")
