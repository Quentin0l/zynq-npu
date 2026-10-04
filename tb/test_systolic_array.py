# test_systolic_array.py : banc cocotb du tableau systolique (leçon 8).
# Fourni par le parcours ; les TODO 2 à 4 sont à écrire.
#
# Le tableau attend des entrées DÉJÀ décalées (cf. l'en-tête de rtl/tableau/systolic_array.sv) :
#   voie r de a_row_i : A[r][k] au cycle k + r
#   voie c de b_col_i : B[k][c] au cycle k + c
# Ici, c'est le banc qui fait ce décalage, en Python (decale, pousser). Dans
# test_systolic_tile.py, c'est ton module rtl/tableau/skew.sv qui le fait, en matériel.
#
# Numérotation : le front 0 est celui qui échantillonne A[0][0] et B[0][0].

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer

from modele_tableau import ecart, empaqueter, gemm_ref, matrice_aleatoire


# ---------------------------------------------------------------------------
# Pilotes.
# ---------------------------------------------------------------------------
def taille(dut):
    """n : le nombre de lignes (et de colonnes) du tableau, lu sur la largeur d'un port."""
    return len(dut.a_row_i) // 8


async def demarrer(dut):
    """Lance l'horloge (10 ns) et applique le reset asynchrone actif bas."""
    Clock(dut.clock_i, 10, "ns").start()
    dut.resetb_i.value = 0
    dut.clear_i.value = 0
    dut.a_row_i.value = 0
    dut.b_col_i.value = 0
    for _ in range(2):
        await RisingEdge(dut.clock_i)
    dut.resetb_i.value = 1


def decale(A, B, t, n):
    """Les deux mots du cycle t : voie r = A[r][t - r], voie c = B[t - c][c], 0 hors de la tuile."""
    K = len(A[0])
    a = [A[r][t - r] if 0 <= t - r < K else 0 for r in range(n)]
    b = [B[t - c][c] if 0 <= t - c < K else 0 for c in range(n)]
    return empaqueter(a), empaqueter(b)


async def pousser(dut, A, B):
    """Présente A (n x K) et B (K x n), décalées : K + n - 1 cycles, donc K + n - 1 fronts.

    Après le dernier front, les entrées repassent à 0 : ce sont des zéros qui avancent.
    """
    n, K = taille(dut), len(A[0])
    for t in range(K + n - 1):
        dut.a_row_i.value, dut.b_col_i.value = decale(A, B, t, n)
        await RisingEdge(dut.clock_i)
    dut.a_row_i.value = 0
    dut.b_col_i.value = 0


async def attendre(dut, fronts):
    """Laisse passer `fronts` fronts d'horloge, entrées inchangées."""
    for _ in range(fronts):
        await RisingEdge(dut.clock_i)


async def effacer(dut):
    """Un cycle avec clear_i = 1, entrées nulles : les n x n accumulateurs à 0."""
    dut.clear_i.value = 1
    await RisingEdge(dut.clock_i)
    dut.clear_i.value = 0


async def lire_c(dut):
    """La tuile C (n x n, entiers signés), lue sur c_o : la tranche r*n + c vaut C[r][c]."""
    await Timer(1, "ns")              # après un front, on laisse les bascules se poser
    n = taille(dut)
    w = len(dut.c_o) // (n * n)       # largeur d'un accumulateur (acc_w_g)
    v = dut.c_o.value.to_unsigned()
    C = []
    for r in range(n):
        ligne = []
        for c in range(n):
            x = (v >> (w * (r * n + c))) & ((1 << w) - 1)
            ligne.append(x - (1 << w) if x >> (w - 1) else x)
        C.append(ligne)
    return C


# ---------------------------------------------------------------------------
# Test résolu.
# ---------------------------------------------------------------------------
@cocotb.test
async def test_une_tuile(dut):
    """Une tuile n x n x n, valeurs dans [0, 7] : celles du chronogramme de la leçon."""
    await demarrer(dut)
    n = taille(dut)
    A = matrice_aleatoire(n, n, 0, 7)
    B = matrice_aleatoire(n, n, 0, 7)
    await pousser(dut, A, B)
    await attendre(dut, 2 * n)        # large : ici, on ne mesure pas la latence
    C = await lire_c(dut)
    assert C == gemm_ref(A, B), ecart(C, gemm_ref(A, B))


# ---------------------------------------------------------------------------
# À toi. Enlève « skip=True », écris le corps, lance ./check.sh tableau.
# ---------------------------------------------------------------------------
@cocotb.test(skip=True)
async def test_negatifs(dut):
    """TODO 2 : une tuile dont les valeurs couvrent tout int8, extrêmes compris.

    test_une_tuile ne tire que dans [0, 7] : il ne voit rien du signe. Tire A et
    B dans [-128, 127], puis force A[0][0] = B[0][0] = -128 : le produit
    -128 x -128 = 16 384 doit arriver positif dans C[0][0].
    """


@cocotb.test(skip=True)
async def test_deux_tuiles(dut):
    """TODO 3 : deux tuiles l'une après l'autre, sans reset entre elles.

    Pousse la tuile 1, attends, lis C1. Puis effacer(), pousse la tuile 2,
    attends, lis C2. Les deux doivent être justes : C2 ne garde rien de C1.
    """


@cocotb.test(skip=True)
async def test_latence(dut):
    """TODO 4 : C est complet après exactement K + 2n - 2 fronts, pas un de moins.

    Prends K = 20 (différent de n) et des valeurs dans [1, 7] : aucun produit nul.
    Compte les fronts depuis le front 0 ; pousser() en fait déjà K + n - 1.
    Après K + 2n - 3 fronts, C[n-1][n-1] attend encore son dernier produit,
    A[n-1][K-1] x B[K-1][n-1]. Après K + 2n - 2 fronts, toute la tuile est juste.
    """
