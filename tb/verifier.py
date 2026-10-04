#!/usr/bin/env python3
"""Vérificateur des bancs cocotb du dépôt : tests, puis mutants (fourni par le parcours).

Pour chaque suite demandée (cf. SUITES ci-dessous) :
  1. lance ses tests cocotb sur le RTL du dépôt, un ✅ / ❌ / ⏸ par test ;
  2. si tout passe et que la suite a des mutants, relance les MÊMES tests sur
     chaque mutant : une copie d'un fichier RTL avec un bug planté. Un bon banc
     « tue » chaque mutant, c'est-à-dire qu'au moins un test échoue dessus.

Usage (c'est ce que fait ./check.sh) :
    python3 verifier.py                 # toutes les suites
    python3 verifier.py v1              # le NPU v1, le moteur (v2 : le tableau)
    python3 verifier.py couche tableau  # seulement celles-là
    WAVES=1 python3 verifier.py couche  # + chronogramme dump.vcd dans tb/

Code de sortie : 0 si tout passe et que tous les mutants sont tués ; 1 si un
test actif échoue ou si le RTL ne compile pas ; 2 si les tests passent mais
qu'un mutant survit (un test reste à écrire). La CI accepte 0 et 2.
"""

import argparse
import concurrent.futures
import os
import re
import shutil
import subprocess
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

TB = Path(__file__).resolve().parent
RACINE = TB.parent
BUILD = TB / "sim_build"

# Une suite = un module de tête, son fichier de tests, ses sources, ses paramètres,
# et éventuellement des mutants qui remplacent l'un de ses fichiers.
MOTEUR = "rtl/moteur/"
TABLEAU = "rtl/tableau/"
SUITES = {
    # NPU v1 : le moteur matrice-vecteur, vérifié brique par brique (leçons 1 à 6).
    "mac": dict(
        top="mac", tests="test_mac",
        sources=[MOTEUR + "mac.sv"],
        mutants=(MOTEUR + "mac.sv", "tb/mutants/mac/mutant_*.sv"),
    ),
    "rangee": dict(
        top="mac_row", tests="test_mac_row",
        sources=[MOTEUR + "mac.sv", MOTEUR + "mac_row.sv"],
        mutants=(MOTEUR + "mac_row.sv", "tb/mutants/mac_row/mutant_*.sv"),
    ),
    "passe": dict(
        top="pass_engine", tests="test_pass_engine",
        sources=[MOTEUR + f for f in ("mac.sv", "mac_row.sv", "weight_buffer.sv", "pass_engine.sv")],
        mutants=(MOTEUR + "pass_engine.sv", "tb/mutants/pass_engine/mutant_*.sv"),
    ),
    "requant": dict(
        top="requant", tests="test_requant",
        sources=[MOTEUR + "requant.sv"],
        mutants=(MOTEUR + "requant.sv", "tb/mutants/requant/mutant_*.sv"),
    ),
    "couche": dict(
        top="layer_engine", tests="test_layer",
        sources=[MOTEUR + f for f in ("mac.sv", "mac_row.sv", "weight_buffer.sv", "pass_engine.sv",
                                      "requant.sv", "lut_ram.sv", "layer_seq.sv", "layer_engine.sv")],
        mutants=(MOTEUR + "layer_seq.sv", "tb/mutants/layer_seq/mutant_*.sv"),
    ),
    # NPU v2 : le tableau systolique 8 × 8 (leçon 8).
    "skew": dict(
        top="skew", tests="test_skew",
        sources=[TABLEAU + "skew.sv"],
        params="-Gn_g=8",
    ),
    "tableau": dict(
        top="systolic_array", tests="test_systolic_array",
        sources=[TABLEAU + "pe.sv", TABLEAU + "systolic_array.sv"],
        params="-Gn_g=8",
        mutants=(TABLEAU + "pe.sv", "tb/mutants/pe/mutant_*.sv"),
    ),
    "tuile": dict(
        top="systolic_tile", tests="test_systolic_tile",
        sources=[TABLEAU + f for f in ("pe.sv", "systolic_array.sv", "skew.sv", "systolic_tile.sv")],
        params="-Gn_g=8",
    ),
}

# Des groupes, pour lancer une version du NPU d'un coup : ./check.sh v1
GROUPES = {
    "v1": ["mac", "rangee", "passe", "requant", "couche"],
    "v2": ["skew", "tableau", "tuile"],
}


def lancer(suite, sources, tag):
    """Compile et simule la suite avec ces sources. Renvoie (résultats, log)."""
    ondes = os.environ.get("WAVES") == "1" and tag == "dut"
    # Un build avec chronogramme (--trace) ne se mélange jamais à un build sans.
    dossier = BUILD / suite["top"] / (tag + "_waves" if ondes else tag)
    resultats = dossier / "results.xml"
    srcs = " ".join(str((RACINE / s).resolve()) for s in sources)
    # make ne recompile que si un fichier a changé, pas si la LISTE des fichiers a
    # changé : dans ce cas, on repart d'un dossier de build vide.
    liste = dossier / "sources.txt"
    if dossier.exists() and (not liste.exists() or liste.read_text() != srcs):
        shutil.rmtree(dossier)
    dossier.mkdir(parents=True, exist_ok=True)
    liste.write_text(srcs)
    resultats.unlink(missing_ok=True)
    cmd = [
        "make", "--no-print-directory",
        f"VERILOG_SOURCES={srcs}",
        f"COCOTB_TOPLEVEL={suite['top']}",
        f"COCOTB_TEST_MODULES={suite['tests']}",
        f"PARAMS={suite.get('params', '')}",
        f"SIM_BUILD={dossier}",
        f"COCOTB_RESULTS_FILE={resultats}",
    ]
    if ondes:
        cmd.append("WAVES=1")
    proc = subprocess.run(cmd, cwd=TB, capture_output=True, text=True)
    log = proc.stdout + proc.stderr
    (dossier / "run.log").write_text(log)
    if not resultats.exists():
        return None, log
    tests = []
    for case in ET.parse(resultats).getroot().iter("testcase"):
        if case.find("skipped") is not None:
            statut = "skip"
        elif case.find("failure") is not None or case.find("error") is not None:
            statut = "fail"
        else:
            statut = "pass"
        tests.append((case.get("name"), statut))
    return tests, log


def lignes_d_echec(log, nom):
    """Extrait du log le message d'assertion (ou l'exception) d'un test en échec."""
    lignes = log.splitlines()
    out = []
    for i, ligne in enumerate(lignes):
        if f"{nom} failed" in ligne:
            for suite in lignes[i + 1:i + 40]:
                txt = suite.strip()
                if "AssertionError" in txt or txt.startswith("assert"):
                    out.append(txt)
                elif re.match(r"^[A-Za-z_.]*(Error|Exception): ", txt):
                    out.append(txt)
                if "passed" in txt or "running" in txt or "*****" in txt:
                    break
            break
    # Une comparaison de matrices entières tient sur une ligne immense : on la coupe.
    return [l if len(l) <= 160 else l[:157] + "..." for l in out]


def court(texte):
    """Chemins relatifs à la racine du dépôt : plus lisible."""
    return str(texte).replace(str(RACINE) + "/", "")


def messages_verilator(log):
    """Avertissements et erreurs Verilator, sans doublons (première ligne de chacun)."""
    vus, out = set(), []
    for ligne in log.splitlines():
        if ligne.startswith(("%Warning", "%Error")) and "Exiting due to" not in ligne:
            cle = re.sub(r":\d+:\d+:", ":", ligne)
            if cle not in vus:
                vus.add(cle)
                out.append(court(ligne.strip()))
    return out


def avertissements_python(log):
    """Coroutines appelées sans await : Python les signale, mais au fond du log."""
    out = []
    motif = r"([\w./-]+\.py):(\d+): RuntimeWarning: coroutine '(\w+)' was never awaited"
    for m in re.finditer(motif, log):
        msg = f"{Path(m.group(1)).name}:{m.group(2)} : {m.group(3)}() appelée sans await, elle ne s'est jamais exécutée"
        if msg not in out:
            out.append(msg)
    return out


def verifier(nom, suite):
    """Une suite : tests sur le RTL du dépôt, puis mutants. Renvoie 0, 1 ou 2."""
    print(f"\n━━ {nom} : {suite['tests']}.py sur {suite['top']} ━━\n")
    tests, log = lancer(suite, suite["sources"], "dut")
    msgs = messages_verilator(log)

    if tests is None:
        print("  ❌ La simulation n'a pas pu tourner. Ce que dit Verilator :\n")
        for m in msgs or log.splitlines()[-25:]:
            print("     " + m)
        print(f"\n     (log complet : {court(BUILD / suite['top'] / 'dut' / 'run.log')})")
        return 1

    icones = {"pass": "✅", "fail": "❌", "skip": "⏸ "}
    for t, statut in tests:
        suffixe = "  (pas encore écrit : skip=True)" if statut == "skip" else ""
        print(f"  {icones[statut]} {t}{suffixe}")
        if statut == "fail":
            for ligne in lignes_d_echec(log, t):
                print(f"       {ligne}")

    py = avertissements_python(log)
    if py:
        print("\n  ⚠  Python signale :")
        for m in py:
            print("     " + m)
    if msgs:
        print("\n  ⚠  Verilator signale (des indices, pas forcément des erreurs) :")
        for m in msgs:
            print("     " + m)

    actifs = [t for t in tests if t[1] != "skip"]
    if any(s == "fail" for _, s in actifs):
        print("\n  Les mutants attendront : le RTL doit d'abord passer tous les tests actifs.")
        print(f"  (log complet : {court(BUILD / suite['top'] / 'dut' / 'run.log')})")
        return 1

    if "mutants" not in suite:
        return 0

    cible, motif = suite["mutants"]
    mutants = sorted(RACINE.glob(motif))
    print(f"\n  Les mêmes tests contre {len(mutants)} mutants de {cible} :\n")
    with concurrent.futures.ThreadPoolExecutor() as pool:
        futurs = {
            m: pool.submit(lancer, suite,
                           [str(m) if s == cible else s for s in suite["sources"]], m.stem)
            for m in mutants
        }
        tues = 0
        for m, futur in futurs.items():
            res, _ = futur.result()
            if res is None:
                print(f"  ⚠  {m.name} : ne compile pas (log dans tb/sim_build/{suite['top']}/{m.stem}/)")
                continue
            tueurs = [t for t, s in res if s == "fail"]
            if tueurs:
                tues += 1
                print(f"  ✅ {m.name} tué par {', '.join(tueurs)}")
            else:
                print(f"  ❌ {m.name} survit : aucun test ne voit son bug")

    print(f"\n  Mutants tués : {tues}/{len(mutants)}")
    restants = [t for t, s in tests if s == "skip"]
    if tues == len(mutants) and restants:
        print("  🎯 Tous les mutants sont tués. Il reste des tests à écrire (⏸) :")
        print("     écris-les quand même, ils vérifient d'autres cas de la spécification.")
    elif tues == len(mutants):
        print("  🎯 Le banc attrape tous les bugs plantés.")
    else:
        print("  Un test manque : relis la spécification en tête du fichier testé.")
    return 0 if tues == len(mutants) else 2


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("suites", nargs="*",
                        help=f"des suites parmi {', '.join(SUITES)}, ou un groupe, {' ou '.join(GROUPES)} (défaut : tout)")
    args = parser.parse_args()
    noms = []
    for nom in args.suites or list(SUITES):
        noms += GROUPES.get(nom, [nom])
    inconnues = [n for n in noms if n not in SUITES]
    if inconnues:
        parser.error(f"suite inconnue : {', '.join(inconnues)} "
                     f"(suites : {', '.join(SUITES)} ; groupes : {', '.join(GROUPES)})")
    codes = [verifier(nom, SUITES[nom]) for nom in noms]
    print()
    # Un échec (1) l'emporte toujours sur un mutant qui survit (2).
    return 1 if 1 in codes else 2 if 2 in codes else 0


if __name__ == "__main__":
    sys.exit(main())
