# test_systolic_tile.py : banc cocotb de la tuile, tableau + décalages (leçon 8).
# Fourni par le parcours.
#
# Cette fois, le banc ne décale plus rien. À chaque cycle, il présente la tuile
# telle qu'elle est rangée :
#   a_col_i : la colonne k de A, voie r = A[r][k]
#   b_row_i : la ligne k de B,   voie c = B[k][c]
# C'est ton rtl/tableau/skew.sv, instancié deux fois dans rtl/tableau/systolic_tile.sv, qui
# transforme ces mots en entrées décalées pour le tableau.
#
# Les deux tests sont résolus : ils vérifient ton TODO 1, le décalage en matériel.

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer

from modele_tableau import ecart, empaqueter, gemm_ref, matrice_aleatoire


def taille(dut):
    return len(dut.a_col_i) // 8


async def demarrer(dut):
    """Lance l'horloge (10 ns) et applique le reset asynchrone actif bas."""
    Clock(dut.clock_i, 10, "ns").start()
    dut.resetb_i.value = 0
    dut.clear_i.value = 0
    dut.a_col_i.value = 0
    dut.b_row_i.value = 0
    for _ in range(2):
        await RisingEdge(dut.clock_i)
    dut.resetb_i.value = 1


async def pousser_mots(dut, A, B):
    """Présente la colonne k de A et la ligne k de B au cycle k : K cycles, donc K fronts."""
    n, K = taille(dut), len(A[0])
    for k in range(K):
        dut.a_col_i.value = empaqueter([A[r][k] for r in range(n)])
        dut.b_row_i.value = empaqueter([B[k][c] for c in range(n)])
        await RisingEdge(dut.clock_i)
    dut.a_col_i.value = 0
    dut.b_row_i.value = 0


async def attendre(dut, fronts):
    for _ in range(fronts):
        await RisingEdge(dut.clock_i)


async def lire_c(dut):
    """La tuile C (n x n, entiers signés), lue sur c_o : la tranche r*n + c vaut C[r][c]."""
    await Timer(1, "ns")
    n = taille(dut)
    w = len(dut.c_o) // (n * n)
    v = dut.c_o.value.to_unsigned()
    C = []
    for r in range(n):
        ligne = []
        for c in range(n):
            x = (v >> (w * (r * n + c))) & ((1 << w) - 1)
            ligne.append(x - (1 << w) if x >> (w - 1) else x)
        C.append(ligne)
    return C


@cocotb.test
async def test_tuile_sans_decalage(dut):
    """La tuile entre telle qu'elle est rangée, tout int8 : C juste si tes décalages sont justes."""
    await demarrer(dut)
    n, K = taille(dut), 12
    A = matrice_aleatoire(n, K)
    B = matrice_aleatoire(K, n)
    await pousser_mots(dut, A, B)
    await attendre(dut, 3 * n)
    C = await lire_c(dut)
    assert C == gemm_ref(A, B), ecart(C, gemm_ref(A, B))


@cocotb.test
async def test_latence_tuile(dut):
    """Tes décalages ne doivent rien ajouter : C complet après K + 2n - 2 fronts, pas un de moins."""
    await demarrer(dut)
    n, K = taille(dut), 20
    A = matrice_aleatoire(n, K, 1, 7)
    B = matrice_aleatoire(K, n, 1, 7)
    attendu = gemm_ref(A, B)
    await pousser_mots(dut, A, B)                  # K fronts
    await attendre(dut, 2 * n - 3)                 # K + 2n - 3 fronts en tout
    C = await lire_c(dut)
    presque = attendu[n - 1][n - 1] - A[n - 1][K - 1] * B[K - 1][n - 1]
    if C[n - 1][n - 1] == attendu[n - 1][n - 1]:
        indice = "déjà complet : une voie arrive en avance"
    elif C[n - 1][n - 1] < presque:            # produits tous positifs : il en manque plusieurs
        indice = "il manque plus d'un produit : une voie a un retard de trop"
    else:
        indice = "relis le chronogramme de la leçon"
    assert C[n - 1][n - 1] == presque, \
        (f"après K + 2n - 3 fronts, C[{n-1}][{n-1}] = {C[n-1][n-1]}, attendu {presque} "
         f"(tout sauf le dernier produit) : {indice}")
    await attendre(dut, 1)                         # K + 2n - 2 fronts
    C = await lire_c(dut)
    assert C == attendu, f"après K + 2n - 2 fronts : {ecart(C, attendu)}"
