# test_mac_row.py : banc de test cocotb de la rangée de MAC (exercice 0003).
# Provenance : exercice 0003 du parcours : pilotes et test résolu fournis, TODO écrits par l'auteur du dépôt.
#
# Nouveauté par rapport à l'exercice 0001 : les poids de TOUS les MAC entrent
# par un seul grand vecteur (w_i), et leurs accumulateurs sortent par un autre
# (acc_o). empaqueter() et depaqueter() font la conversion avec des listes
# Python ; tu n'as pas à les modifier.

import random

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer

ACC_BITS = 32  # doit valoir acc_width_g


# ---------------------------------------------------------------------------
# Modèle de référence : un produit matrice-vecteur, une sortie par ligne de W.
# ---------------------------------------------------------------------------
def gemv_ref(W, x):
    return [sum(w * v for w, v in zip(ligne, x)) for ligne in W]


# ---------------------------------------------------------------------------
# Empaquetage : listes Python <-> vecteurs du DUT.
# ---------------------------------------------------------------------------
def empaqueter(octets):
    """[w0, w1, ...] en int8 signés -> un entier : w0 dans les bits 7:0, w1 dans 15:8, etc."""
    v = 0
    for k, b in enumerate(octets):
        v |= (b & 0xFF) << (8 * k)
    return v


def depaqueter(v, nb, bits=ACC_BITS):
    """Découpe l'entier v en nb champs de `bits` bits, lus comme des entiers signés."""
    champs = []
    for k in range(nb):
        c = (v >> (bits * k)) & ((1 << bits) - 1)
        champs.append(c - (1 << bits) if c >> (bits - 1) else c)
    return champs


# ---------------------------------------------------------------------------
# Pilotes.
# ---------------------------------------------------------------------------
def nb_mac(dut):
    """Le nombre de MAC de la rangée, déduit de la largeur de w_i (8 bits par MAC)."""
    return len(dut.w_i) // 8


async def demarrer(dut):
    """Horloge de 10 ns, entrées à zéro, reset asynchrone pendant deux fronts."""
    Clock(dut.clock_i, 10, "ns").start()
    dut.resetb_i.value = 0
    dut.clear_i.value = 0
    dut.valid_i.value = 0
    dut.x_i.value = 0
    dut.w_i.value = 0
    for _ in range(2):
        await RisingEdge(dut.clock_i)
    dut.resetb_i.value = 1


async def passe(dut, W, x):
    """Une passe : à chaque cycle j, x[j] sur x_i et la colonne j de W sur w_i.

    W a une ligne par MAC : W[k] contient les poids du MAC k.
    """
    for j in range(len(x)):
        dut.x_i.value = x[j]
        dut.w_i.value = empaqueter([ligne[j] for ligne in W])
        dut.valid_i.value = 1
        await RisingEdge(dut.clock_i)
    dut.valid_i.value = 0


async def effacer(dut):
    """Un cycle avec clear_i = 1."""
    dut.clear_i.value = 1
    await RisingEdge(dut.clock_i)
    dut.clear_i.value = 0


async def lire_sorties(dut):
    """Les accumulateurs des MAC, du MAC 0 au dernier, en entiers signés."""
    await Timer(1, "ns")
    return depaqueter(dut.acc_o.value.to_unsigned(), nb_mac(dut))


# ---------------------------------------------------------------------------
# Test résolu.
# ---------------------------------------------------------------------------
@cocotb.test
async def test_une_passe(dut):
    """Une passe où tous les MAC ont les mêmes poids : toutes les sorties sont égales."""
    await demarrer(dut)
    P, n = nb_mac(dut), 16
    x = list(range(-8, 8))
    W = [[j - 3 for j in range(n)] for _ in range(P)]
    await passe(dut, W, x)
    y = await lire_sorties(dut)
    assert y == gemv_ref(W, x), f"sorties {y}, attendu {gemv_ref(W, x)}"


# ---------------------------------------------------------------------------
# À toi. Enlève « skip=True », écris le corps, lance ./check.sh.
# ---------------------------------------------------------------------------
@cocotb.test#(skip=True)
async def test_poids_aleatoires(dut):
    """TODO 2 : une passe avec des poids et des entrées tirés au hasard.

    random.randint(-128, 127) pour chaque valeur ; une ligne de n poids par MAC.
    """
    await demarrer(dut)
    P, n = nb_mac(dut), 16
    x = list(range(-8, 8))
    W =[[random.randint(-128, 127)] * n ] * P
    await passe(dut, W, x)
    y = await lire_sorties(dut)
    assert y == gemv_ref(W, x), f"sorties {y}, attendu {gemv_ref(W, x)}"
    

@cocotb.test#(skip=True)
async def test_deux_passes(dut):
    """TODO 3 : une couche de 2 x P sorties, calculée en deux passes.

    Passe 1 avec les P premières lignes de W, puis lecture des sorties.
    Puis effacer(), passe 2 avec les P lignes suivantes, lecture.
    Compare les 2 x P sorties à gemv_ref(W, x).
    """
    await demarrer(dut)
    P, n = nb_mac(dut), 16
    x = list(range(-8, 8))
    W1 =[[random.randint(-128, 127) for i in range(n)] for j in range(P)]
    await passe(dut, W1, x)
    y1 = await lire_sorties(dut)
    #assert y == gemv_ref(W, x), f"sorties {y}, attendu {gemv_ref(W, x)}"

    
    await effacer(dut)
    #await RisingEdge(dut.clock_i)

    W2 =[[random.randint(-128, 127) for i in range(n)] for j in range(P)]
    await passe(dut, W2, x)
    y2 = await lire_sorties(dut)
    assert y1 + y2  == gemv_ref(W1 + W2, x), f"sorties {y2}, attendu {gemv_ref(W1 + W2, x)}"

@cocotb.test#(skip=True)
async def test_bulles(dut):
    """TODO 4 : des cycles sans donnée au milieu d'une passe.

    Envoie la première moitié des colonnes, puis 3 cycles avec valid_i = 0 et
    n'importe quoi sur x_i et w_i (127 partout, par exemple), puis le reste.
    Le résultat ne doit pas changer.
    """
     
    await demarrer(dut)
    P, n = nb_mac(dut), 16
    x = list(range(-8, 8))
    W =[[random.randint(-128, 127) for i in range(n)] for j in range(P)]
    #x1, x2 = x[: int(n/2)] + [0] * int(n/2),  [0] * int(n/2) + x[int(n/2) :]
    W1, W2 = W[: int(n/2)] ,  W[int(n/2) :]
    #print(x1,x2)
    print(W1,W2)
    await passe(dut, W1, x)

    
    dut.valid_i.value = 0
    for i in range(2):
            dut.x_i.value = -128
            dut.w_i.value = empaqueter([1,1,1,1,1,1,1,1])
            await RisingEdge(dut.clock_i)
    
    dut.valid_i.value = 1
    
    await passe(dut, W2, x)
    y = await lire_sorties(dut)
    assert y == gemv_ref(W,x), f"sorties {y}, attendu {gemv_ref(W, x)}"

