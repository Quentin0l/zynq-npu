#!/bin/sh
# Boucle de feedback de la leçon 2 : compile, exécute, compare.
set -e
cd "$(dirname "$0")"
cc -O1 -Wall -o lex lex.c
./lex < input.c > got.txt
if diff -u expected.txt got.txt; then
    echo ""
    echo "✅  84 tokens, tous corrects. Ton lexer marche."
else
    echo ""
    echo "❌  Diff ci-dessus : '-' = ce qui était attendu, '+' = ce que ton lexer a produit."
    exit 1
fi
