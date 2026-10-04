#!/usr/bin/env bash
# Lance les bancs cocotb du dépôt, puis les mutants (fourni par le parcours).
# Usage : ./check.sh              toutes les suites
#         ./check.sh tableau      une suite (skew, tableau, tuile)
#         WAVES=1 ./check.sh tuile    + chronogramme tb/dump.vcd
set -e
cd "$(dirname "$0")"
if [ -f ../.venv/bin/activate ]; then
    source ../.venv/bin/activate
fi
export PYTHONDONTWRITEBYTECODE=1
exec python3 verifier.py "$@"
