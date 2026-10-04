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
    r = ((acc + bias) * m0 + (1 << (s - 1))) >> s   # Q1 à Q3
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
# ---------------------------------------------------------------------------
@cocotb.test
async def test_exemple_de_la_lecon(dut):
    """M = 0,005 : 1 000 donne 5, et 1 150 (soit 5,75) s'arrondit à 6."""
    for acc, attendu in [(1000, 5), (1150, 6), (1049, 5), (0, 0)]:
        obtenu, ref = await requantifier(dut, acc, 0, 0.005, zp=0)
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

    Par exemple acc = -1000 avec M = 0,005 doit donner -5. Essaie aussi un cas
    où l'arrondi compte, comme -1 150.
    """
    for acc, attendu in [(-1000, -5), (-1150, -6), (-1049, -5), (0, 0)]:
        obtenu, ref = await requantifier(dut, acc, 0, 0.005, zp=0)
        assert ref == attendu, "le modèle de référence lui-même est faux"
        assert obtenu == attendu, f"acc = {acc} : q_o = {obtenu}, attendu {attendu}"
    


@cocotb.test#(skip=True)
async def test_saturation(dut):
    """TODO 3 : des sommes trop grandes pour un int8, dans les deux sens.

    Avec M = 0,005, acc = 100 000 donnerait 500 : la sortie doit valoir 127.
    Et une somme très négative doit donner -128.
    """
    for acc, attendu in [(100000, 127), (-331150, -128)]:
        obtenu, ref = await requantifier(dut, acc, 0, 0.005, zp=0)
        assert ref == attendu, "le modèle de référence lui-même est faux"
        assert obtenu == attendu, f"acc = {acc} : q_o = {obtenu}, attendu {attendu}"
    

@cocotb.test#(skip=True)
async def test_relu(dut):
    """TODO 4 : ReLU avec un point zéro NON nul.

    Avec relu=True, rien ne peut descendre sous zp : en int8, le réel 0 vaut zp.
    Prends par exemple zp = -20 et une somme négative.
    """
    for acc, attendu in [(100000, 127), (-331150, 0),(-1000, 0), (-1150, 0), (1000, 5)]:
        obtenu, ref = await requantifier(dut, acc, 0, 0.005, zp=0, relu=True)
        assert ref == attendu, "le modèle de référence lui-même est faux"
        assert obtenu == attendu, f"acc = {acc} : q_o = {obtenu}, attendu {attendu}"


    obtenu, ref = await requantifier(dut, -1000, 0, 0.005, zp=-20, relu=True)
    assert ref == -20, "le modèle de référence lui-même est faux"
    assert obtenu == -20, f"q_o = {obtenu}, attendu -20"