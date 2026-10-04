#!/usr/bin/env bash
# Lance les bancs cocotb du dépôt, puis les mutants (fourni par le parcours).
# Usage : ./check.sh                 toutes les suites
#         ./check.sh v1              le NPU v1, le moteur : mac, rangee, passe, requant, couche
#         ./check.sh v2              le NPU v2, le tableau : skew, tableau, tuile
#         ./check.sh couche          une seule suite
#         WAVES=1 ./check.sh couche  + chronogramme tb/dump.vcd
set -e
cd "$(dirname "$0")"
if [ -f ../.venv/bin/activate ]; then
    source ../.venv/bin/activate
fi
export PYTHONDONTWRITEBYTECODE=1
exec python3 verifier.py "$@"
