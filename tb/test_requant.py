# test_requant.py : banc de test cocotb de l'unité de requantification (exercice 0005).
# Provenance : exercice 0005 du parcours : pilotes et test résolu fournis, TODO écrits par l'auteur du dépôt.
#
# Nouveauté : le module est purement combinatoire. Pas d'horloge : on pose les
# entrées, on laisse 1 ns au simulateur pour propager, on lit la sortie.

import random

import cocotb
from cocotb.triggers import Timer


# ---------------------------------------------------------------------------
# Modèle de référence : la spécification Q1 à Q5, en Python.
# En Python, >> sur un entier négatif est déjà un décalage arithmétique.
# ---------------------------------------------------------------------------
def requant_ref(acc, bias, m0, n, zp, relu):
    s = 31 + n
    r = ((acc + bias) * m0) >> s                    # Q1 à Q3 : tronqué vers -inf, comme AIfES
    y = r + zp                                      # Q4
    plancher = zp if relu else -128                 # Q5
    return max(plancher, min(127, y))


def multiplicateur(M):
    """M réel dans ]0, 1[ -> (m0, n) avec M ≈ m0 · 2^-(31+n) et m0 dans [2^30, 2^31).

    C'est le calcul « hors ligne » de Jacob et al. (§2.2) : M = M0 · 2^-n, M0 dans [0,5 ; 1[.
    """
    n = 0
    while M * 2 ** n < 0.5:
        n += 1
    m0 = round(M * 2 ** n * 2 ** 31)
    if m0 == 2 ** 31:  # l'arrondi a atteint 1 : on renormalise
        m0, n = m0 // 2, n - 1
    return m0, n


# ---------------------------------------------------------------------------
# Pilote : pose les entrées, attend la propagation, lit la sortie signée.
# ---------------------------------------------------------------------------
async def requantifier(dut, acc, bias, M, zp, relu=False):
    m0, n = multiplicateur(M)
    dut.acc_i.value = acc
    dut.bias_i.value = bias
    dut.m0_i.value = m0
    dut.shift_i.value = n
    dut.zp_i.value = zp
    dut.relu_i.value = int(relu)
    await Timer(1, "ns")
    return dut.q_o.value.to_signed(), requant_ref(acc, bias, m0, n, zp, relu)


# ---------------------------------------------------------------------------
# Tests résolus.
# Depuis le 2026-11-13, Q3 tronque sans arrondir (comme AIfES). Les valeurs
# attendues prennent M = 2^-7, une puissance de deux exacte, comme les échelles
# d'AIfES ; avec M = 0,005, m0 rend M un rien plus grand que 0,005, et
# -1 000 donnerait -5,0000000016, tronqué à -6.
# ---------------------------------------------------------------------------
@cocotb.test
async def test_exemple_de_la_lecon(dut):
    """M = 2^-7 : 640 donne 5, et 736 (soit 5,75) se tronque à 5, comme dans AIfES."""
    for acc, attendu in [(640, 5), (736, 5), (671, 5), (0, 0)]:
        obtenu, ref = await requantifier(dut, acc, 0, 2 ** -7, zp=0)
        assert ref == attendu, "le modèle de référence lui-même est faux"
        assert obtenu == attendu, f"acc = {acc} : q_o = {obtenu}, attendu {attendu}"


@cocotb.test
async def test_biais_et_point_zero(dut):
    """Le biais s'ajoute avant la multiplication, le point zéro après."""
    for acc, bias, zp in [(1000, 400, 3), (2000, 0, 10), (700, 300, -5)]:
        obtenu, attendu = await requantifier(dut, acc, bias, 0.005, zp)
        assert obtenu == attendu, f"acc={acc}, bias={bias}, zp={zp} : q_o = {obtenu}, attendu {attendu}"


# ---------------------------------------------------------------------------
# À toi. Enlève « skip=True », écris le corps, lance ./check.sh.
# Utilise le pilote requantifier(dut, acc, bias, M, zp, relu), qui te rend
# (valeur obtenue, valeur attendue).
# ---------------------------------------------------------------------------
@cocotb.test#(skip=True)
async def test_negatifs(dut):
    """TODO 2 : des sommes négatives (acc_i + bias_i < 0), sans saturation.

    Par exemple acc = -640 avec M = 2^-7 doit donner -5. Et la troncature va
    vers -inf : -736 (soit -5,75) donne -6.
    """
    for acc, attendu in [(-640, -5), (-736, -6), (-671, -6), (0, 0)]:
        obtenu, ref = await requantifier(dut, acc, 0, 2 ** -7, zp=0)
        assert ref == attendu, "le modèle de référence lui-même est faux"
        assert obtenu == attendu, f"acc = {acc} : q_o = {obtenu}, attendu {attendu}"
    


@cocotb.test#(skip=True)
async def test_saturation(dut):
    """TODO 3 : des sommes trop grandes pour un int8, dans les deux sens.

    Avec M = 2^-7, acc = 64 000 donnerait 500 : la sortie doit valoir 127.
    Et une somme très négative doit donner -128.
    """
    for acc, attendu in [(64000, 127), (-64000, -128)]:
        obtenu, ref = await requantifier(dut, acc, 0, 2 ** -7, zp=0)
        assert ref == attendu, "le modèle de référence lui-même est faux"
        assert obtenu == attendu, f"acc = {acc} : q_o = {obtenu}, attendu {attendu}"
    

@cocotb.test#(skip=True)
async def test_relu(dut):
    """TODO 4 : ReLU avec un point zéro NON nul.

    Avec relu=True, rien ne peut descendre sous zp : en int8, le réel 0 vaut zp.
    Prends par exemple zp = -20 et une somme négative.
    """
    for acc, attendu in [(64000, 127), (-64000, 0), (-640, 0), (-736, 0), (640, 5)]:
        obtenu, ref = await requantifier(dut, acc, 0, 2 ** -7, zp=0, relu=True)
        assert ref == attendu, "le modèle de référence lui-même est faux"
        assert obtenu == attendu, f"acc = {acc} : q_o = {obtenu}, attendu {attendu}"


    obtenu, ref = await requantifier(dut, -640, 0, 2 ** -7, zp=-20, relu=True)
    assert ref == -20, "le modèle de référence lui-même est faux"
    assert obtenu == -20, f"q_o = {obtenu}, attendu -20"