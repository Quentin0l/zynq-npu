#!/bin/sh
# Boucle de feedback du lexeur : un ✅ ou ❌ par fichier de tests/, puis le diff
# du premier échec. Un test = un fichier source (tests/nom.ext) et ce que le
# lexeur doit écrire, erreurs comprises (tests/nom.expected).
cd "$(dirname "$0")"
cc -O1 -Wall -o lex lex.c || exit 1
echo ""
ok=0; total=0; premier=""
for t in tests/*; do
    case "$t" in *.expected) continue ;; esac
    total=$((total + 1))
    attendu="${t%.*}.expected"
    if ./lex < "$t" 2>&1 | diff -q "$attendu" - > /dev/null 2>&1; then
        ok=$((ok + 1)); echo "  ✅  $(basename "$t")"
    else
        echo "  ❌  $(basename "$t")"
        [ -z "$premier" ] && premier="$t"
    fi
done
echo ""
if [ -n "$premier" ]; then
    echo "Premier échec : $premier"
    echo "--- diff ('-' attendu, '+' obtenu) ---"
    ./lex < "$premier" 2>&1 | diff -u "${premier%.*}.expected" - | tail -n +3
    echo ""
    echo "❌  $ok/$total"
    exit 1
fi
echo "✅  $ok/$total"
