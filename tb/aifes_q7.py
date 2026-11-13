"""aifes_q7.py : ton réseau réel tel qu'AIfES le calcule en Q7 (int8), en Python pur.

Provenance : ajouté le 2026-11-13 par le parcours. Trois usages :
  - décoder la mémoire de paramètres qu'AIfES-Converter écrit dans
    aifes_q7_weights.h (lire_entete, decoder) ;
  - calculer une inférence exactement comme AIfES (inference_aifes), pour avoir
    une référence au bit près ;
  - traduire chaque couche en descripteur pour le NPU v1 (descripteurs_npu).

Tout vient du code d'AIfES for Arduino (Fraunhofer IMS) :
  aimath_q7.h                         r = 2^-s · (q - z), et FLOAT_TO_Q7
  aialgo_distribute_parameter_memory  la disposition de la mémoire de paramètres
  ailayer_dense_set_paramem           ... et celle de chaque couche dense
  aimath_q7_default_linear32_bt       somme int32, points zéro, biais int32,
                                      décalage SANS arrondi, conversion int8 qui replie
  aimath_q7_default_relu              max(q, z)
Ce port donne les mêmes logits que le code C d'AIfES (voir tb/reseau/aifes_logits.c).
"""

import operator
import re
import struct
from dataclasses import dataclass

TAILLES = [784, 512, 256, 128, 64, 10]   # le réseau réel : 5 couches denses
DECALAGE_ENTREE = 7                      # l'entrée est en Q7 : décalage 7, point zéro 0
M0_NPU = 1 << 30                         # avec m0 = 2^30, l'échelle du NPU vaut 2^-(shift + 1)


@dataclass
class CoucheQ7:
    """Une couche dense d'AIfES, avec la quantification de son entrée et de sa sortie."""
    W: list      # m lignes de n poids int8 : AIfES range les poids par neurone
    b: list      # m biais int32, de décalage s_in + s_w et de point zéro 0
    s_in: int    # décalage de l'entrée (son échelle vaut 2^-s_in)
    z_in: int    # point zéro de l'entrée
    s_w: int     # décalage des poids (point zéro nul : poids symétriques)
    s_out: int   # décalage de la sortie
    z_out: int   # point zéro de la sortie
    relu: bool

    @property
    def k(self):
        """Le décalage de sortie : M = S_in · S_w / S_out = 2^-k."""
        return self.s_in + self.s_w - self.s_out


def lire_entete(chemin):
    """aifes_q7_weights.h -> les octets de sa mémoire de paramètres (petit-boutiste)."""
    src = open(chemin, encoding="utf-8").read()
    taille = int(re.search(r"parameter_memory_size\s*=\s*(\d+)", src).group(1))
    mots = re.findall(r"0x([0-9A-Fa-f]{8})", src)
    mem = b"".join(struct.pack("<I", int(m, 16)) for m in mots)[:taille]
    assert len(mem) == taille, f"{len(mem)} octets lus pour {taille} annoncés"
    return mem


def _q7_params(mem, off):
    """struct aimath_q7_params { uint16_t shift ; int8_t zero_point ; } : 4 octets alignés."""
    return struct.unpack_from("<Hb", mem, off)


def decoder(mem, tailles=TAILLES):
    """La mémoire de paramètres -> les couches denses, dans la disposition d'AIfES.

    D'abord les paramètres de résultat de l'entrée puis de chaque couche dense
    (les ReLU et le softmax n'en stockent pas), puis, couche après couche : les
    paramètres des poids, les poids [neurone][entrée], les paramètres du biais
    (aimath_q31_params : 8 octets) et les biais int32, alignés sur 4 octets.
    """
    nb = len(tailles) - 1
    off, res = 0, []
    for _ in range(nb + 1):
        res.append(_q7_params(mem, off))
        off += 4
    couches = []
    for l in range(nb):
        n, m = tailles[l], tailles[l + 1]
        s_w, z_w = _q7_params(mem, off)
        off += 4
        assert z_w == 0, f"couche {l + 1} : poids non symétriques (z_w = {z_w}), le NPU suppose z_w = 0"
        plat = struct.unpack_from(f"<{n * m}b", mem, off)
        off = (off + n * m + 3) // 4 * 4
        s_b, z_b = struct.unpack_from("<Hi", mem, off)
        off += 8
        b = list(struct.unpack_from(f"<{m}i", mem, off))
        off += 4 * m
        (s_in, z_in), (s_out, z_out) = res[l], res[l + 1]
        assert s_b == s_in + s_w and z_b == 0, f"couche {l + 1} : biais inattendu ({s_b}, {z_b})"
        couches.append(CoucheQ7(W=[list(plat[j * n:(j + 1) * n]) for j in range(m)], b=b,
                                s_in=s_in, z_in=z_in, s_w=s_w, s_out=s_out, z_out=z_out,
                                relu=(l < nb - 1)))
    assert off == len(mem), f"{off} octets décodés sur {len(mem)}"
    assert res[0] == (DECALAGE_ENTREE, 0), f"entrée inattendue : {res[0]}"
    return couches


def quantifier_entree(pixels):
    """Pixels MNIST (0 à 255) -> int8, comme à l'entraînement puis dans AIfES.

    Le modèle a appris sur f = p/255 - 0,5, et AIfES fait q = FLOAT_TO_Q7(f, 7, 0),
    c'est-à-dire f·128 arrondi à l'opposé de zéro. f·128 = 128p/255 - 64 ne tombe
    jamais sur un demi, d'où cette forme entière exacte, entre -64 et 64.
    """
    return [(256 * p - 32385) // 510 for p in pixels]


def inference_aifes(couches, q):
    """Une inférence, exactement comme aimath_q7_default_linear32_bt puis ReLU."""
    for c in couches:
        sortie = []
        for ligne, bj in zip(c.W, c.b):
            s = sum(map(operator.mul, ligne, q))
            if c.z_in != 0:
                s -= c.z_in * sum(ligne)          # correction du point zéro d'entrée
            s += bj
            v = (s >> c.k) + c.z_out              # décalage arithmétique, sans arrondi
            v = (v + 128) % 256 - 128             # (int8_t) : la conversion replie
            sortie.append(max(v, c.z_out) if c.relu else v)
        q = sortie
    return q


def descripteurs_npu(couches):
    """Chaque couche -> ce que reçoit le NPU v1 : m0, shift, point zéro, ReLU, et le biais
    corrigé b' = b - z_in · ΣW, qui replie hors ligne la correction du point zéro."""
    desc = []
    for l, c in enumerate(couches, start=1):
        assert 1 <= c.k <= 32, f"couche {l} : décalage {c.k} hors de portée du NPU"
        desc.append(dict(m0=M0_NPU, shift=c.k - 1, zp=c.z_out, relu=c.relu,
                         b=[bj - c.z_in * sum(ligne) for ligne, bj in zip(c.W, c.b)]))
    return desc
