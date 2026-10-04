# test_pass_engine.py : banc de test cocotb du moteur de passe (exercice 0004).
# Provenance : exercice 0004 du parcours : pilotes et test résolu fournis, TODO écrits par l'auteur du dépôt.
#
# Nouveauté : les poids ne viennent plus du banc à chaque cycle. On les CHARGE
# d'abord dans le tampon (comme le fera l'ARM), puis une passe n'envoie plus
# que les entrées x. Le moteur va chercher lui-même les poids en mémoire.

import random

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer

ACC_BITS = 32  # doit valoir acc_width_g


# ---------------------------------------------------------------------------
# Modèle de référence et empaquetage (comme à l'exercice 0003).
# ---------------------------------------------------------------------------
def gemv_ref(W, x):
    return [sum(w * v for w, v in zip(ligne, x)) for ligne in W]


def empaqueter(octets):
    v = 0
    for k, b in enumerate(octets):
        v |= (b & 0xFF) << (8 * k)
    return v


def depaqueter(v, nb, bits=ACC_BITS):
    champs = []
    for k in range(nb):
        c = (v >> (bits * k)) & ((1 << bits) - 1)
        champs.append(c - (1 << bits) if c >> (bits - 1) else c)
    return champs


def tuile_en_mots(W):
    """Une tuile de P lignes (une par MAC) et n colonnes -> n mots du tampon.

    Le mot j contient la COLONNE j : W[0][j] dans l'octet 0, W[1][j] dans
    l'octet 1, etc. C'est le rangement de la leçon 4 : un mot par cycle de calcul.
    """
    n = len(W[0])
    return [empaqueter([ligne[j] for ligne in W]) for j in range(n)]


# ---------------------------------------------------------------------------
# Pilotes.
# ---------------------------------------------------------------------------
def nb_mac(dut):
    return len(dut.wdata_i) // 8


async def demarrer(dut):
    Clock(dut.clock_i, 10, "ns").start()
    for sig in (dut.resetb_i, dut.we_i, dut.waddr_i, dut.wdata_i,
                dut.clear_i, dut.base_i, dut.valid_i, dut.x_i):
        sig.value = 0
    for _ in range(2):
        await RisingEdge(dut.clock_i)
    dut.resetb_i.value = 1


async def charger(dut, mots, base):
    """Écrit les mots dans le tampon à partir de l'adresse base, un par cycle (E1)."""
    for k, mot in enumerate(mots):
        dut.we_i.value = 1
        dut.waddr_i.value = base + k
        dut.wdata_i.value = mot
        await RisingEdge(dut.clock_i)
    dut.we_i.value = 0


async def debut_passe(dut, base):
    """Un cycle avec clear_i = 1 : le compteur prend base, la rangée se vide (E2)."""
    dut.clear_i.value = 1
    dut.base_i.value = base
    await RisingEdge(dut.clock_i)
    dut.clear_i.value = 0


async def entrees(dut, x):
    """Présente les entrées x, une par cycle, avec valid_i = 1 (E3)."""
    for v in x:
        dut.x_i.value = v
        dut.valid_i.value = 1
        await RisingEdge(dut.clock_i)
    dut.valid_i.value = 0


async def lire_sorties(dut):
    """Un front de plus qu'à l'exercice 0003 : l'étage de retard (E5) doit se vider."""
    await RisingEdge(dut.clock_i)
    await Timer(1, "ns")
    return depaqueter(dut.acc_o.value.to_unsigned(), nb_mac(dut))


# ---------------------------------------------------------------------------
# Test résolu.
# ---------------------------------------------------------------------------
@cocotb.test
async def test_une_passe(dut):
    """Une tuile chargée à l'adresse 0, puis une passe de 16 entrées."""
    await demarrer(dut)
    P, n = nb_mac(dut), 16
    W = [[random.randint(-128, 127) for _ in range(n)] for _ in range(P)]
    x = [random.randint(-128, 127) for _ in range(n)]
    await charger(dut, tuile_en_mots(W), base=0)
    await debut_passe(dut, base=0)
    await entrees(dut, x)
    y = await lire_sorties(dut)
    assert y == gemv_ref(W, x), f"sorties {y}, attendu {gemv_ref(W, x)}"


# ---------------------------------------------------------------------------
# À toi. Enlève « skip=True », écris le corps, lance ./check.sh.
# ---------------------------------------------------------------------------
@cocotb.test#(skip=True)
async def test_deuxieme_tuile(dut):
    """TODO 2 : une couche de 2 x P sorties, rangée en deux tuiles dans le tampon.

    La tuile 1 (les P premières lignes de W) à l'adresse 0, la tuile 2 juste
    après, à l'adresse n. Puis une passe par tuile, chacune à sa base, avec le
    MÊME x. Compare les 2 x P sorties à gemv_ref(W, x).
    """
    await demarrer(dut)
    P, n = nb_mac(dut), 16

    W = [[random.randint(-128, 127) for _ in range(n)] for _ in range(2*P)]
    x = [random.randint(-128, 127) for _ in range(n)]
    w1 = W[:P]
    await charger(dut, tuile_en_mots(w1), 0)

    w2 = W[P:]
    await charger(dut, tuile_en_mots(w2), n)
    await debut_passe(dut, base=0)
    await entrees(dut, x)
    y = await lire_sorties(dut)

    await debut_passe(dut, base=n)
    await entrees(dut, x)          # le MÊME x : c'est la même couche
    y += await lire_sorties(dut)


    assert y == gemv_ref(W, x), f"sorties {y}, attendu {gemv_ref(W, x)}"




@cocotb.test#(skip=True)
async def test_bulles(dut):
    """TODO 3 : des cycles sans donnée au milieu d'une passe (E4).

    Les poids sont en mémoire : pour couper la passe en deux, il suffit de
    couper x. Entre les deux moitiés, 3 cycles avec valid_i = 0 et n'importe
    quoi sur x_i. Le résultat ne doit pas changer.
    """
    await demarrer(dut)
    P, n = nb_mac(dut), 16
    W = [[random.randint(-128, 127) for _ in range(n)] for _ in range(P)]
    x = [random.randint(-128, 127) for _ in range(n)]

    x1 = x[:n//2]
    x2= x[n//2:]
    await charger(dut, tuile_en_mots(W), 0)
    await debut_passe(dut, base=0)
    await entrees(dut, x1)



    dut.valid_i.value = 0
    for i in range(2):
        dut.x_i.value = -128

        await RisingEdge(dut.clock_i)
        
    dut.valid_i.value = 1
    await entrees(dut, x2)
    y = await lire_sorties(dut)
    assert y == gemv_ref(W, x), f"sorties {y}, attendu {gemv_ref(W, x)}"





@cocotb.test#(skip=True)
async def test_premiere_couche(dut):
    """TODO 4 : une passe de 512 entrées, comme la première couche de ton MLP.

    Même structure que test_une_passe, avec n = 512.
    """
    await demarrer(dut)
    P, n = nb_mac(dut), 512
    W = [[random.randint(-128, 127) for _ in range(n)] for _ in range(P)]
    x = [random.randint(-128, 127) for _ in range(n)]
    await charger(dut, tuile_en_mots(W), base=0)
    await debut_passe(dut, base=0)
    await entrees(dut, x)
    y = await lire_sorties(dut)
    assert y == gemv_ref(W, x), f"sorties {y}, attendu {gemv_ref(W, x)}"