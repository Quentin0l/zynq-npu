#!/usr/bin/env bash
# Provenance : leçon 6 du parcours « NPU sur ZedBoard » (fourni).
# Simule l'IP npu_axi 2.0 (enveloppe, registres, aiguillage, moteur) avec xsim.
# Usage : hw/sim/run_v2.sh   (Vivado dans le PATH : source .../Vivado/settings64.sh)
set -e
# Une erreur de compilation s'affiche, au lieu d'arrêter le script en silence.
erreur() { grep -E "ERROR" "$1"; exit 1; }
cd "$(dirname "$0")"
mkdir -p build/v2
cd build/v2
AXI=../../../../rtl/axi
MOT=../../../../rtl/moteur
xvlog "$AXI/npu_axi.v" > xvlog.log || erreur xvlog.log
xvlog -sv "$MOT/mac.sv" "$MOT/mac_row.sv" "$MOT/weight_buffer.sv" "$MOT/pass_engine.sv" \
    "$MOT/requant.sv" "$MOT/lut_ram.sv" "$MOT/weight_fifo.sv" "$MOT/layer_seq.sv" \
    "$MOT/layer_engine.sv" "$AXI/npu_regs.sv" "$AXI/npu_flux.sv" ../../tb_npu_v2.sv >> xvlog.log || erreur xvlog.log
xelab -debug off tb_npu_v2 -s tb_v2 > xelab.log || erreur xelab.log
xsim tb_v2 -R | grep -E "^(ok|ECHEC|TOUT|[0-9]+ ECHEC|       )"
