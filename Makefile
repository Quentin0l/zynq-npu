# make test : ce qui est fini et doit rester vert (ce que bloque la CI).
#   make test-c     le lexeur
#   make test-rtl   le NPU v1, le moteur : bancs cocotb et mutants
# Les travaux en cours, à lancer à la main :
#   make test-ref   les GEMM de référence en C (exercice de la S1)
#   make test-v2    le NPU v2, le tableau 8 × 8

.PHONY: test test-c test-rtl test-ref test-v2

test: test-c test-rtl

test-c:
	compiler/lexer/check.sh

# Code 2 : tous les tests passent, mais un mutant survit (un test reste à écrire).
test-rtl:
	tb/check.sh v1 || [ $$? -eq 2 ]

test-ref:
	ref/check.sh

test-v2:
	tb/check.sh v2 || [ $$? -eq 2 ]
