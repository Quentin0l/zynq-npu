# test_mac.py : banc de test cocotb du MAC (exercice 0001).
# Provenance : exercice 0001 du parcours : pilotes et tests résolus fournis, TODO écrits par l'auteur du dépôt.
#
# Un banc cocotb est un fichier Python. Chaque fonction marquée @cocotb.test est
# un test : cocotb démarre la simulation, lui passe `dut` (ton module), et le test
# pilote les broches pendant que Verilator simule le matériel.
#
#   dut.a_i.value = -3              écrire sur une entrée
#   dut.acc_o.value.to_signed()     lire une sortie comme entier signé
#   await RisingEdge(dut.clock_i)   laisser le temps simulé avancer jusqu'au prochain front
#
# `async` / `await` : un test est une coroutine. Chaque `await` rend la main au
# simulateur, qui fait avancer le temps, puis reprend le test là où il s'était arrêté.

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer


# ---------------------------------------------------------------------------
# Modèle de référence (golden model) : ce que le MAC DOIT calculer, écrit dans
# le langage le plus simple possible. Les tests comparent le matériel à lui.
# ---------------------------------------------------------------------------
def dot_ref(a, b):
    return sum(x * y for x, y in zip(a, b))


# ---------------------------------------------------------------------------
# Pilotes : des fonctions réutilisables qui manipulent les broches du MAC.
# ---------------------------------------------------------------------------
async def demarrer(dut):
    """Lance l'horloge (période 10 ns) et applique le reset asynchrone (S1)."""
    Clock(dut.clock_i, 10, "ns").start()
    dut.resetb_i.value = 0
    dut.clear_i.value = 0
    dut.valid_i.value = 0
    dut.a_i.value = 0
    dut.b_i.value = 0
    for _ in range(2):
        await RisingEdge(dut.clock_i)
    dut.resetb_i.value = 1


async def envoyer(dut, a, b):
    """Présente une paire (a[k], b[k]) par cycle, avec valid_i = 1 (S3)."""
    for x, y in zip(a, b):
        dut.a_i.value = x
        dut.b_i.value = y
        dut.valid_i.value = 1
        await RisingEdge(dut.clock_i)  # le MAC échantillonne sur ce front
    dut.valid_i.value = 0


async def effacer(dut):
    """Un cycle avec clear_i = 1 (S2)."""
    dut.clear_i.value = 1
    await RisingEdge(dut.clock_i)
    dut.clear_i.value = 0


async def lire_acc(dut):
    """Lit acc_o comme entier SIGNÉ.

    Pourquoi le Timer : juste après un front, les processus always_ff n'ont pas
    encore tourné. On attend 1 ns pour lire la valeur mise à jour.
    Pourquoi to_signed() : int(dut.acc_o.value) lirait les bits comme un
    nombre NON signé, et -5 deviendrait 4294967291.
    """
    await Timer(1, "ns")
    return dut.acc_o.value.to_signed()


# ---------------------------------------------------------------------------
# Tests résolus : lis-les, ils servent de modèle pour les tiens.
# ---------------------------------------------------------------------------
@cocotb.test
async def test_reset(dut):
    """S1 : après le reset, l'accumulateur vaut 0."""
    await demarrer(dut)
    acc = await lire_acc(dut)
    assert acc == 0, f"après reset, acc_o = {acc}, attendu 0"


@cocotb.test
async def test_petit_produit_scalaire(dut):
    """S3 : [1, 2, 3] . [4, 5, 6] = 32."""
    await demarrer(dut)
    a, b = [1, 2, 3], [4, 5, 6]
    await envoyer(dut, a, b)
    acc = await lire_acc(dut)
    assert acc == dot_ref(a, b), f"acc_o = {acc}, attendu {dot_ref(a, b)}"


@cocotb.test
async def test_maintien_puis_clear(dut):
    """S4 puis S2 : sans valid_i la somme ne bouge pas ; clear_i la remet à 0."""
    await demarrer(dut)
    await envoyer(dut, [2], [3])
    for _ in range(3):  # trois cycles sans valid_i
        await RisingEdge(dut.clock_i)
    acc = await lire_acc(dut)
    assert acc == 6, f"acc_o = {acc} après 3 cycles sans valid_i, attendu 6"
    await effacer(dut)
    acc = await lire_acc(dut)
    assert acc == 0, f"acc_o = {acc} après clear_i, attendu 0"


# ---------------------------------------------------------------------------
# À toi. Pour activer un test : enlève « skip=True », puis écris son corps.
# Chaque test doit passer sur TON mac.sv ET faire échouer au moins un mutant.
# ---------------------------------------------------------------------------
@cocotb.test#(skip=True)
async def test_negatifs(dut):
    """TODO 2 : un produit scalaire avec des opérandes négatifs.

    Les trois tests résolus n'utilisent que des nombres positifs. Choisis des
    valeurs dont certains produits sont négatifs, compare à dot_ref().
    """
    await demarrer(dut)
    a, b = [-1, -2, 3], [4, -5, 6]
    await envoyer(dut, a, b)
    acc = await lire_acc(dut)
    assert acc == dot_ref(a, b), f"acc_o = {acc}, attendu {dot_ref(a, b)}"


@cocotb.test#(skip=True)
async def test_pire_cas(dut):
    """TODO 3 : le pire cas de la leçon, n = 784 produits (-128) x (-128).

    Calcule d'abord à la main la valeur attendue. Construis les listes avec
    [-128] * 784.
    """
    await demarrer(dut)
    a = [-128] *784
    b = [-128] *784
    await envoyer(dut, a, b)
    acc = await lire_acc(dut)
    assert acc == 12845056

@cocotb.test#(skip=True)
async def test_clear_prioritaire(dut):
    """TODO 4 : S2 dit que clear_i l'emporte sur valid_i.

    Accumule une valeur non nulle, puis présente clear_i = 1 ET valid_i = 1
    pendant le même cycle. Qu'attend la spécification ?
    """
    await demarrer(dut)
    await envoyer(dut, [2], [3])
    await RisingEdge(dut.clock_i)

    acc = await lire_acc(dut)
    assert acc == 6, f"acc_o = {acc} après 1 cycle sans valid_i, attendu 6"
    dut.clear_i.value = 1
    dut.valid_i.value = 1
    await RisingEdge(dut.clock_i)
    acc = await lire_acc(dut)
    assert acc == 0, f"acc_o = {acc} après clear_i, attendu 0"
