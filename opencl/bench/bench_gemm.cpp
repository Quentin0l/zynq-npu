// bench_gemm.cpp : combien d'opérations par seconde ? (fourni par le parcours, leçon 11)
//
// Mesure la durée des kernels, du lancement à la fin, sans les copies entre
// l'hôte et le device ; garde la meilleure de 5 exécutions, et vérifie au
// passage que le kernel tuilé donne le même C que le naïf.
//   ./build/bench_gemm
#include <cstdio>
#include <random>
#include <vector>

#include "gemm_ocl.hpp"

int main() {
    GemmOcl g;
    std::printf("device : %s, tuiles de %d x %d\n\n", g.device().c_str(), g.taille_tuile(), g.taille_tuile());
    std::printf("  taille      naïf (ms)   naïf (Gop/s)   tuilé (ms)   tuilé (Gop/s)\n");
    std::mt19937 gen(42);
    std::uniform_int_distribution<int> d(-128, 127);
    for (int n : {128, 256, 512, 1024, 2048}) {
        std::vector<int8_t> A(size_t(n) * n), B(size_t(n) * n);
        for (auto &x : A) x = int8_t(d(gen));
        for (auto &x : B) x = int8_t(d(gen));
        const double ops = 2.0 * n * n * n;   // une multiplication + une addition par MAC
        double best_n = 1e30, best_t = 1e30;
        std::vector<int32_t> Cn, Ct;
        bool tuile_ok = true;
        for (int r = 0; r < 5; r++) {
            double ms;
            try { Cn = g.naif(n, n, n, A.data(), B.data(), &ms); best_n = std::min(best_n, ms); }
            catch (const PasEncoreEcrit &) { best_n = -1; }
            try { Ct = g.tuile(n, n, n, A.data(), B.data(), &ms); best_t = std::min(best_t, ms); }
            catch (const PasEncoreEcrit &) { best_t = -1; }
        }
        if (best_n > 0 && best_t > 0 && Cn != Ct) tuile_ok = false;
        std::printf("  %4d³   ", n);
        if (best_n > 0) std::printf("  %9.3f   %10.1f", best_n, ops / best_n * 1e-6);
        else std::printf("  %9s   %10s", "—", "—");
        if (best_t > 0) std::printf("   %10.3f   %12.1f%s\n", best_t, ops / best_t * 1e-6, tuile_ok ? "" : "   ≠ naïf !");
        else std::printf("   %10s   %12s\n", "—", "—");
    }
    return 0;
}
