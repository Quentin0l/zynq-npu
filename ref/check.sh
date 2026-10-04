#!/bin/sh
# Boucle de feedback de gemm_tuile (leçon 5 du parcours compilateurs).
# Compile avec AddressSanitizer et UBSan, puis lance chaque cas dans son propre
# processus : un cas qui lit hors d'une matrice n'empêche pas les autres de tourner.
cd "$(dirname "$0")"
cc -std=c11 -O1 -g -Wall -Wextra -fsanitize=address,undefined -fno-sanitize-recover=undefined \
   -fno-omit-frame-pointer -o test_gemm test_gemm.c gemm.c || exit 1
echo ""
nb=$(./test_gemm --nombre)
ok=0
i=0
while [ "$i" -lt "$nb" ]; do
    if sortie=$(./test_gemm "$i" 2>&1); then
        ok=$((ok + 1))
        echo "  ✅  $(echo "$sortie" | head -1)"
    elif echo "$sortie" | grep -q "AddressSanitizer"; then
        echo "  ❌  $(echo "$sortie" | head -1 | sed 's/==.*//')"
        echo "       accès hors d'une matrice (AddressSanitizer) : un bord oublié ?"
        echo "$sortie" | grep -m1 "in gemm_tuile" | sed 's/^ *#[0-9]* 0x[0-9a-f]* in /       ici : /'
    elif echo "$sortie" | grep -q "runtime error"; then
        echo "  ❌  $(echo "$sortie" | head -1 | sed 's/[^ ]*: runtime error.*//')"
        echo "       $(echo "$sortie" | grep -m1 "runtime error" | sed 's/^.*runtime error/comportement indéfini (UBSan)/')"
    else
        echo "  ❌  $sortie"
    fi
    i=$((i + 1))
done
echo ""
if [ "$ok" -eq "$nb" ]; then
    echo "✅  $ok/$nb — ton gemm_tuile suit n'importe quel schedule, bords compris."
    ./test_gemm --trafic
else
    echo "❌  $ok/$nb"
    exit 1
fi
