# test_reseau.py : ton vrai réseau (AIfES Q7, MNIST), de bout en bout sur le NPU v1.
# Provenance : ajouté le 2026-11-13 par le parcours.
#
# Le réseau : 784 -> 512 -> 256 -> 128 -> 64 -> 10, entraîné en Keras et quantifié
# par AIfES-Converter. La couche 1 (401 408 poids) ne tient pas dans les BRAM :
# ses poids arrivent en flux, comme ils viendront de la DDR par DMA. Les couches
# 2 à 5 sont chargées une fois dans le tampon de poids. Entre deux couches, le
# banc ne touche à rien. La référence : les logits du vrai AIfES, calculés en C
# par tb/reseau/aifes_logits.c sur les mêmes images.

import math
from pathlib import Path

import cocotb

from aifes_q7 import decoder, descripteurs_npu, inference_aifes, quantifier_entree
from modele_npu import couche_en_mots
from test_layer import (ZONE_A, ZONE_B, Couche, demarrer, ecrire, ecrire_activations,
                        executer, lire_activations, nb_mac, pousser_flux)

DONNEES = Path(__file__).resolve().parent / "reseau"


def donnees():
    """Les couches décodées, les images (pixels 0 à 255), les étiquettes et les logits d'AIfES."""
    couches = decoder((DONNEES / "mnist_q7_params.bin").read_bytes())
    brut = (DONNEES / "mnist_test_images.bin").read_bytes()
    images = [list(brut[i:i + 784]) for i in range(0, len(brut), 784)]
    etiquettes = list((DONNEES / "mnist_test_labels.bin").read_bytes())
    logits = {}
    for ligne in (DONNEES / "aifes_logits.txt").read_text().splitlines():
        if ligne and not ligne.startswith("#"):
            champs = [int(v) for v in ligne.split()]
            logits[champs[0]] = champs[2:]
    assert len(images) == len(etiquettes) == len(logits), "régénère les données : tb/reseau/README.md"
    return couches, images, etiquettes, [logits[i] for i in range(len(images))]


@cocotb.test
async def test_modele_python_egale_aifes(dut):
    """aifes_q7.py redonne, au bit près, les logits du vrai AIfES en C : le décodeur et le
    port Python sont justes, et peuvent servir de référence."""
    couches, images, _, logits = donnees()
    for i, image in enumerate(images):
        y = inference_aifes(couches, quantifier_entree(image))
        assert y == logits[i], f"image {i} : Python {y}, AIfES en C {logits[i]}"


@cocotb.test
async def test_reseau_reel(dut):
    """Le réseau entier sur le NPU : les 10 logits de chaque image égaux, au bit près,
    à ceux d'AIfES, avec la couche 1 en flux (un peu irrégulier) et les couches 2 à 5
    dans le tampon."""
    await demarrer(dut)
    P = nb_mac(dut)
    couches_q7, images, etiquettes, logits = donnees()

    # Le placement, comme le fera ton compilateur : couche 1 en flux, couches 2 à 5
    # l'une après l'autre dans le tampon, les biais à la suite, les zones qui alternent.
    couches, w_base, bias_base = [], 0, 0
    for l, (c, d) in enumerate(zip(couches_q7, descripteurs_npu(couches_q7))):
        en_flux = (l == 0)
        zone_in, zone_out = (ZONE_A, ZONE_B) if l % 2 == 0 else (ZONE_B, ZONE_A)
        couches.append(Couche(c.W, d["b"], M=2.0 ** -c.k, zp=d["zp"], relu=d["relu"],
                              w_base=0 if en_flux else w_base, bias_base=bias_base,
                              in_base=zone_in, out_base=zone_out, flux=en_flux))
        if not en_flux:
            w_base += math.ceil(len(c.W) / P) * len(c.W[0])
        bias_base += len(c.W)

    # Chargés une fois, comme au démarrage de la carte : les poids des couches 2 à 5
    # et les biais corrigés des 5 couches.
    for c in couches:
        if not c.flux:
            await ecrire(dut, dut.w_we_i, dut.w_waddr_i, dut.w_wdata_i, couche_en_mots(c.W, P), c.w_base)
        await ecrire(dut, dut.bias_we_i, dut.bias_waddr_i, dut.bias_wdata_i, c.b, c.bias_base)
    mots_couche_1 = couche_en_mots(couches[0].W, P)

    for i, image in enumerate(images):
        await ecrire_activations(dut, quantifier_entree(image), ZONE_A)
        for c in couches:
            if c.flux:
                cocotb.start_soon(pousser_flux(dut, mots_couche_1, trou=0.05))
            await executer(dut, c)
        y = await lire_activations(dut, couches[-1].out_base, 10)
        assert y == logits[i], f"image {i} : NPU {y}, AIfES {logits[i]}"
        classe = max(range(10), key=lambda j: y[j])
        dut._log.info(f"image {i} : prédit {classe}, attendu {etiquettes[i]}")
