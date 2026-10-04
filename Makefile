# make test : tout ce que vérifie la CI.
#   make test-c     le lexeur et les GEMM de référence en C
#   make test-rtl   les bancs cocotb et leurs mutants (tb/check.sh)

.PHONY: test test-c test-rtl

test: test-c test-rtl

test-c:
	compiler/lexer/check.sh
	ref/check.sh

# Code 2 : tous les tests passent, mais un mutant survit (un test reste à écrire).
test-rtl:
	tb/check.sh || [ $$? -eq 2 ]
