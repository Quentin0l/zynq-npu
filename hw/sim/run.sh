#!/usr/bin/env bash
# Provenance : leçon 2 du parcours « NPU sur ZedBoard » (fourni).
# Simule l'IP npu_axi avec xsim, le simulateur de Vivado, sur ce PC (sans Verilator).
# Usage : hw/sim/run.sh   (Vivado doit être dans le PATH : source .../Vivado/settings64.sh)
set -e
# Une erreur de compilation s'affiche, au lieu d'arrêter le script en silence.
erreur() { grep -E "ERROR" "$1"; exit 1; }
cd "$(dirname "$0")"
mkdir -p build
cd build
RTL=../../../rtl/axi
xvlog "$RTL/npu_axi.v" > xvlog.log || erreur xvlog.log
xvlog -sv "$RTL/npu_regs.sv" ../tb_npu_axi.sv >> xvlog.log || erreur xvlog.log
xelab -debug off tb_npu_axi -s tb_snap > xelab.log || erreur xelab.log
xsim tb_snap -R | grep -E "^(ok|ECHEC|TOUT|[0-9]+ ECHEC)"
