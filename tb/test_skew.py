# test_skew.py : banc cocotb du décalage d'entrée (leçon 8, TODO 1 dans rtl/tableau/skew.sv).
# Fourni par le parcours.
#
# Les deux tests sont résolus : ils vérifient la spécification D1 à D3 de skew.sv.
# Le TODO, ici, c'est le matériel.

import random

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer

from modele_tableau import depaqueter, empaqueter


def nb_voies(dut):
    return len(dut.data_i) // 8


async def demarrer(dut):
    """Lance l'horloge (10 ns) et applique le reset asynchrone actif bas (D3)."""
    Clock(dut.clock_i, 10, "ns").start()
    dut.resetb_i.value = 0
    dut.data_i.value = 0
    for _ in range(2):
        await RisingEdge(dut.clock_i)
    dut.resetb_i.value = 1


async def lire_voies(dut):
    await Timer(1, "ns")
    return depaqueter(dut.data_o.value.to_unsigned(), nb_voies(dut))


@cocotb.test
async def test_impulsion(dut):
    """Un seul mot non nul : la voie r le montre exactement r cycles plus tard, et 0 sinon (D2)."""
    await demarrer(dut)
    n = nb_voies(dut)
    mot = [r + 1 for r in range(n)]   # la voie r porte r + 1 : on reconnaît chaque voie
    dut.data_i.value = empaqueter(mot)
    for t in range(n + 2):            # le mot est présenté au cycle 0 seulement
        voies = await lire_voies(dut)
        for r in range(n):
            attendu = mot[r] if t == r else 0
            assert voies[r] == attendu, \
                f"cycle {t}, voie {r} : {voies[r]}, attendu {attendu} (la voie r retarde de r cycles)"
        await RisingEdge(dut.clock_i)
        dut.data_i.value = 0


@cocotb.test
async def test_flot(dut):
    """Un mot aléatoire par cycle : la voie r de la sortie vaut la voie r de l'entrée r cycles plus tôt."""
    await demarrer(dut)
    n = nb_voies(dut)
    entrees = []                      # entrees[t] = les voies présentées au cycle t
    for t in range(4 * n):
        mot = [random.randint(-128, 127) for _ in range(n)]
        entrees.append(mot)
        dut.data_i.value = empaqueter(mot)
        voies = await lire_voies(dut)
        for r in range(n):
            if t >= r:
                attendu, origine = entrees[t - r][r], f"l'entrée de la voie {r} au cycle {t - r}"
            else:
                attendu, origine = 0, f"avant le cycle {r}, la voie {r} sort encore les zéros du reset"
            assert voies[r] == attendu, f"cycle {t}, voie {r} : {voies[r]}, attendu {attendu} ({origine})"
        await RisingEdge(dut.clock_i)
