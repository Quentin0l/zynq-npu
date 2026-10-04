# Makefile cocotb générique du dépôt (fourni par le parcours).
# D'habitude, ne l'appelle pas directement : passe par ./check.sh, qui choisit
# la suite, résume les résultats et teste les mutants.
#
# Appel direct, pour une suite (cf. SUITES dans verifier.py) :
#   make TOP=systolic_array TESTS=test_systolic_array \
#        SRCS="../rtl/pe.sv ../rtl/systolic_array.sv" PARAMS=-Gn_g=8
# Avec WAVES=1, le chronogramme est écrit dans dump.vcd, dans ce dossier.

SIM             ?= verilator
TOPLEVEL_LANG    = verilog
VERILOG_SOURCES ?= $(abspath $(SRCS))
COCOTB_TOPLEVEL     ?= $(TOP)
COCOTB_TEST_MODULES ?= $(TESTS)

# Les bancs importent modele.py, qui est dans ce dossier.
export PYTHONPATH := $(CURDIR):$(PYTHONPATH)

# Verilator : tous les avertissements (-Wall), mais non bloquants (-Wno-fatal).
# PARAMS fixe les paramètres du module de tête (ex. -Gn_g=8).
COMPILE_ARGS += -Wall -Wno-fatal $(PARAMS)

# Chaque build a son propre sous-dossier de sim_build/, jamais sim_build/ lui-même
# (Verilator cherche aussi ses objets dans le dossier parent : VPATH += ..).
ifeq ($(WAVES),1)
SIM_BUILD   ?= sim_build/waves
EXTRA_ARGS  += --trace --trace-structs
else
SIM_BUILD   ?= sim_build/plain
endif

include $(shell cocotb-config --makefiles)/Makefile.sim
