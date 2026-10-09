#!/bin/sh
# Boucle de feedback des leçons 10 et 11 du parcours accélérateurs (fourni par le parcours).
# Compile l'hôte avec CMake, puis lance les tests sur le device OpenCL :
# le GPU de ton Mac en local, PoCL sur le CPU en CI.
# Usage : ./check.sh          tous les cas
#         ./check.sh naif     les cas de la leçon 10
#         ./check.sh tuile    les cas de la leçon 11
#         ./check.sh bench    les mesures (leçon 11)
# OCL_DEVICE=cpu ou gpu force le type de device.
cd "$(dirname "$0")"
if ! { cmake -S . -B build -DCMAKE_BUILD_TYPE=Release && cmake --build build -j; } > build.log 2>&1; then
    echo "❌ La compilation de l'hôte a échoué. Ce que dit le compilateur :"
    grep -E "error|erreur" build.log | head -20
    echo "   (journal complet : opencl/build.log)"
    exit 1
fi
if [ "$1" = "bench" ]; then
    exec ./build/bench_gemm
fi
exec ./build/test_gemm "$@"
