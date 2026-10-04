# test_layer.py : banc de test cocotb d'une couche complète (exercice 0006).
# Provenance : exercice 0006 du parcours : pilotes et test résolu fournis, TODO 2 et 3 écrits par l'auteur du dépôt, TODO 4 par le parcours.
#
# Nouveauté : le banc ne pilote plus les passes. Il charge les mémoires, pose le
# descripteur de la couche, envoie start_i, puis attend done_o. Tout le reste,
# cycle après cycle, c'est ton séquenceur qui le fait.

import math
import random
from dataclasses import dataclass

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer

# Le modèle de référence partagé : tb/modele_npu.py
from modele_npu import (couche_aleatoire, couche_en_mots, couche_ref,
                        echelle_type, multiplicateur)

ZONE_A, ZONE_B = 0, 512  # les deux zones du tampon d'activations


# ---------------------------------------------------------------------------
# Une couche et sa place dans les mémoires du NPU.
# ---------------------------------------------------------------------------
@dataclass
class Couche:
    """Une couche dense, ses constantes, et sa place dans les mémoires du NPU."""
    W: list          # m lignes de n poids int8
    b: list          # m biais corrigés int32 (le b' de la leçon 5)
    M: float         # le multiplicateur RÉEL ; executer() en tire les entiers m0 et n
    zp: int          # point zéro de la sortie
    relu: bool
    w_base: int      # adresse de sa première tuile dans le tampon de poids
    bias_base: int   # adresse de son premier biais
    in_base: int     # zone de ses entrées dans le tampon d'activations
    out_base: int    # zone de ses sorties

    @property
    def n(self):
        return len(self.W[0])

    @property
    def m(self):
        return len(self.W)

    def ref(self, x):
        """Ce que la couche doit écrire, d'après le modèle de référence."""
        return couche_ref(self.W, self.b, x, self.M, self.zp, self.relu)


def duree(c, P):
    """Durée de la spécification : T·(n + 2) + m cycles, de CLEAR à DONE (exclu)."""
    return math.ceil(c.m / P) * (c.n + 2) + c.m


# ---------------------------------------------------------------------------
# Pilotes.
# ---------------------------------------------------------------------------
def nb_mac(dut):
    return len(dut.w_wdata_i) // 8


async def demarrer(dut):
    Clock(dut.clock_i, 10, "ns").start()
    for sig in (dut.resetb_i, dut.w_we_i, dut.w_waddr_i, dut.w_wdata_i,
                dut.bias_we_i, dut.bias_waddr_i, dut.bias_wdata_i,
                dut.act_we_i, dut.act_waddr_i, dut.act_wdata_i, dut.act_raddr_i,
                dut.n_i, dut.m_i, dut.w_base_i, dut.bias_base_i, dut.in_base_i,
                dut.out_base_i, dut.m0_i, dut.shift_i, dut.zp_i, dut.relu_i,
                dut.start_i):
        sig.value = 0
    for _ in range(2):
        await RisingEdge(dut.clock_i)
    dut.resetb_i.value = 1


async def ecrire(dut, we, waddr, wdata, valeurs, base):
    """Écrit valeurs[i] à l'adresse base + i, une valeur par cycle."""
    for i, v in enumerate(valeurs):
        we.value = 1
        waddr.value = base + i
        wdata.value = v
        await RisingEdge(dut.clock_i)
    we.value = 0


async def charger_couche(dut, c):
    """Les poids de c (toutes ses tuiles) à partir de c.w_base, ses biais à partir de c.bias_base."""
    mots = couche_en_mots(c.W, nb_mac(dut))
    await ecrire(dut, dut.w_we_i, dut.w_waddr_i, dut.w_wdata_i, mots, c.w_base)
    await ecrire(dut, dut.bias_we_i, dut.bias_waddr_i, dut.bias_wdata_i, c.b, c.bias_base)


async def ecrire_activations(dut, x, base):
    """Écrit les octets x dans le tampon d'activations, à partir de l'adresse base."""
    await ecrire(dut, dut.act_we_i, dut.act_waddr_i, dut.act_wdata_i, x, base)


async def lire_activations(dut, base, nb):
    """Lit nb octets signés à partir de base. Lecture asynchrone : pas de front à attendre."""
    y = []
    for i in range(nb):
        dut.act_raddr_i.value = base + i
        await Timer(1, "ns")
        y.append(dut.act_rdata_o.value.to_signed())
    return y


async def executer(dut, c):
    """Pose le descripteur de c, envoie start_i, attend done_o, puis le retour en IDLE.

    Renvoie le nombre de cycles de travail, de CLEAR (inclus) à DONE (exclu).
    """
    m0, n = multiplicateur(c.M)
    dut.n_i.value, dut.m_i.value = c.n, c.m
    dut.w_base_i.value, dut.bias_base_i.value = c.w_base, c.bias_base
    dut.in_base_i.value, dut.out_base_i.value = c.in_base, c.out_base
    dut.m0_i.value, dut.shift_i.value = m0, n
    dut.zp_i.value, dut.relu_i.value = c.zp, int(c.relu)
    dut.start_i.value = 1
    await RisingEdge(dut.clock_i)          # ce front voit start_i = 1 : IDLE -> CLEAR
    dut.start_i.value = 0
    limite = 4 * duree(c, nb_mac(dut)) + 100
    cycles = 0
    await Timer(1, "ns")
    while dut.done_o.value == 0:
        assert cycles < limite, f"done_o n'est jamais monté en {limite} cycles : ta FSM est bloquée"
        await RisingEdge(dut.clock_i)
        await Timer(1, "ns")
        cycles += 1
    await RisingEdge(dut.clock_i)          # le cycle DONE se termine : retour en IDLE
    await Timer(1, "ns")
    return cycles


# ---------------------------------------------------------------------------
# Test résolu.
# ---------------------------------------------------------------------------
@cocotb.test
async def test_une_passe(dut):
    """Une couche de 16 entrées et P sorties : une seule passe."""
    await demarrer(dut)
    P = nb_mac(dut)
    W, b = couche_aleatoire(16, P)
    # Sans ReLU : son plancher rendrait égales la moitié des sorties, justes ou
    # fausses. Même piège que zp = 0 à l'exercice 0005.
    c = Couche(W, b, M=echelle_type(16), zp=-3, relu=False,
               w_base=0, bias_base=0, in_base=ZONE_A, out_base=ZONE_B)
    x = [random.randint(-128, 127) for _ in range(c.n)]

    await charger_couche(dut, c)
    await ecrire_activations(dut, x, c.in_base)
    cycles = await executer(dut, c)
    y = await lire_activations(dut, c.out_base, c.m)

    assert y == c.ref(x), f"sorties {y}, attendu {c.ref(x)}"
    assert cycles == duree(c, P), \
        f"sorties justes, mais {cycles} cycles au lieu de {duree(c, P)} : relis le chronogramme"


# ---------------------------------------------------------------------------
# À toi. Enlève « skip=True », écris le corps, lance ./check.sh.
# ---------------------------------------------------------------------------
@cocotb.test#(skip=True)
async def test_plusieurs_passes(dut):
    """TODO 2 : une couche de 3 x P sorties, donc trois passes.

    Même structure que test_une_passe, avec m = 3 * P. Chaque passe doit lire
    SA tuile : la tuile t commence à l'adresse w_base + t·n du tampon de poids.
    """
    await demarrer(dut)
    P = nb_mac(dut) 
    W, b = couche_aleatoire(16, P*3)
    c = Couche(W, b, M=echelle_type(16), zp=-3, relu=False,
                   w_base=0, bias_base=0, in_base=ZONE_A, out_base=ZONE_B)
    x = [random.randint(-128, 127) for _ in range(c.n)]
    
    await charger_couche(dut, c)
    await ecrire_activations(dut, x, c.in_base)
    cycles = await executer(dut, c)
    y = await lire_activations(dut, c.out_base, c.m)
    
    assert y == c.ref(x), f"sorties {y}, attendu {c.ref(x)}"
    assert cycles == duree(c, P), \
            f"sorties justes, mais {cycles} cycles au lieu de {duree(c, P)} : relis le chronogramme"
    
    


@cocotb.test#(skip=True)
async def test_derniere_passe_partielle(dut):
    """TODO 3 : m = P + 2 sorties. Avec P = 8, c'est ta dernière couche : 10 sorties.

    Deux passes, la seconde avec 2 sorties utiles seulement. Vérifie les m
    sorties et la durée. Vérifie aussi que l'octet qui suit la zone de sortie
    (adresse out_base + m) n'a pas été écrit : places-y d'abord une valeur
    témoin avec ecrire_activations, et relis-la à la fin.
    """
    await demarrer(dut)
    P = nb_mac(dut) 
    W, b = couche_aleatoire(16, P +2)
    c = Couche(W, b, M=echelle_type(16), zp=-3, relu=False,
                       w_base=0, bias_base=0, in_base=ZONE_A, out_base=ZONE_B)
    x = [random.randint(-128, 127) for _ in range(c.n)]
        
    await charger_couche(dut, c)
    await ecrire_activations(dut, x, c.in_base)
    cycles = await executer(dut, c)
    y = await lire_activations(dut, c.out_base, c.m)
        
    assert y == c.ref(x), f"sorties {y}, attendu {c.ref(x)}"
    assert cycles == duree(c, P), \
                f"sorties justes, mais {cycles} cycles au lieu de {duree(c, P)} : relis le chronogramme"
        
        

@cocotb.test#(skip=True)
async def test_mlp_complet(dut):
    """TODO 4 : ton MLP 512 -> 256 -> 128 -> 64 -> 10, couche après couche.

    - Les poids des couches se suivent dans le tampon de poids, sans trou : la
      couche suivante commence juste après le dernier mot de la précédente.
      Combien de mots occupe une couche ? Relis la leçon 4.
    - Les biais aussi se suivent : un par sortie.
    - Les zones alternent : la couche 1 lit ZONE_A et écrit ZONE_B, la couche 2
      lit ZONE_B et écrit ZONE_A, et ainsi de suite.
    - ReLU sur les trois premières couches, pas sur la dernière.
    Charge tout, écris x dans ZONE_A, puis executer() les 4 couches dans
    l'ordre. Compare les 10 sorties finales à celles du modèle, appliqué couche
    après couche avec c.ref().
    """
    await demarrer(dut)
    P = nb_mac(dut)
    tailles = [512, 256, 128, 64, 10]

    # 1. Ranger les 4 couches en mémoire, l'une après l'autre (c'est le travail
    #    que fera un jour ton compilateur).
    couches = []
    w_base, bias_base = 0, 0
    for l in range(4):
        n, m = tailles[l], tailles[l + 1]
        W, b = couche_aleatoire(n, m)
        if l % 2 == 0:
            zone_in, zone_out = ZONE_A, ZONE_B   # couches 1 et 3 : A -> B
        else:
            zone_in, zone_out = ZONE_B, ZONE_A   # couches 2 et 4 : B -> A
        c = Couche(W, b, M=echelle_type(n), zp=-3, relu=(l < 3),
                   w_base=w_base, bias_base=bias_base, in_base=zone_in, out_base=zone_out)
        couches.append(c)
        w_base += math.ceil(m / P) * n   # T tuiles de n mots : la couche suivante commence juste après
        bias_base += m                   # un biais par sortie

    # 2. Tout charger UNE seule fois, comme au démarrage de la carte :
    #    les poids et les biais des 4 couches, puis l'entrée x.
    for c in couches:
        await charger_couche(dut, c)
    x = [random.randint(-128, 127) for _ in range(512)]
    await ecrire_activations(dut, x, ZONE_A)

    # 3. Enchaîner les 4 couches. Entre deux couches, le banc n'ÉCRIT plus rien :
    #    les sorties d'une couche restent dans le tampon, où la suivante les lit.
    #    Il se contente de relire chaque couche pour la comparer au modèle.
    attendu = x
    for numero, c in enumerate(couches, start=1):
        cycles = await executer(dut, c)
        attendu = c.ref(attendu)                            # le modèle, couche après couche
        y = await lire_activations(dut, c.out_base, c.m)    # relire ne modifie rien
        assert y == attendu, f"couche {numero} : sorties {y[:8]}..., attendu {attendu[:8]}..."
        assert cycles == duree(c, P), f"couche {numero} : {cycles} cycles au lieu de {duree(c, P)}"
