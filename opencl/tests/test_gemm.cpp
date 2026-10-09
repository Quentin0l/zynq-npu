// test_gemm.cpp : les tests des kernels GEMM OpenCL (fourni par le parcours).
//
// Chaque cas compare le C calculé sur le device à gemm_ref, la référence dorée
// de ref/gemm.c, au bit près : en int8 -> int32, l'ordre des additions ne
// change rien au résultat.
//
//   ./build/test_gemm          tous les cas
//   ./build/test_gemm naif     les cas de la leçon 10
//   ./build/test_gemm tuile    les cas de la leçon 11
#include <cstdio>
#include <cstring>
#include <random>
#include <string>
#include <vector>

#include "gemm_ocl.hpp"

extern "C" {
#include "gemm.h"
}

namespace {

struct Cas {
    const char *groupe;   // "naif" ou "tuile"
    int M, N, K;
    bool extremes;        // A et B remplis de -128 : le pire cas de l'accumulateur
    const char *pourquoi;
};

const Cas CAS[] = {
    {"naif", 1, 1, 1, false, "le plus petit GEMM"},
    {"naif", 8, 8, 8, false, ""},
    {"naif", 16, 16, 16, false, ""},
    {"naif", 17, 9, 33, false, "des tailles qui ne sont multiples de rien"},
    {"naif", 1, 256, 512, false, "ta couche 1 du MLP, une entrée (M = 1)"},
    {"naif", 64, 64, 64, true, "-128 partout : chaque case vaut 16 384 x 64"},
    {"naif", 100, 37, 129, false, ""},
    {"tuile", 16, 16, 16, false, "une seule tuile"},
    {"tuile", 64, 64, 64, false, "des tuiles entières"},
    {"tuile", 17, 9, 33, false, "des bords partout : la grille déborde de C"},
    {"tuile", 1, 256, 512, false, "M = 1 : une seule ligne de work-items utile"},
    {"tuile", 100, 37, 129, false, ""},
    {"tuile", 64, 64, 64, true, "-128 partout"},
    {"tuile", 256, 256, 256, false, "assez grand pour que l'ordre des work-groups compte"},
};

std::vector<int8_t> remplir(size_t n, bool extremes, std::mt19937 &gen) {
    std::uniform_int_distribution<int> d(-128, 127);
    std::vector<int8_t> v(n);
    for (auto &x : v) x = extremes ? int8_t(-128) : int8_t(d(gen));
    return v;
}

std::string comparer(const std::vector<int32_t> &C, const std::vector<int32_t> &ref, int N) {
    size_t faux = 0, premier = 0;
    for (size_t t = 0; t < ref.size(); t++)
        if (C[t] != ref[t]) { if (!faux) premier = t; faux++; }
    if (!faux) return "";
    char msg[200];
    std::snprintf(msg, sizeof msg, "C[%zu][%zu] = %d, attendu %d (%zu case(s) fausse(s) sur %zu)",
                  premier / N, premier % N, C[premier], ref[premier], faux, ref.size());
    return msg;
}

}  // namespace

int main(int argc, char **argv) {
    const char *filtre = argc > 1 ? argv[1] : nullptr;
    std::unique_ptr<GemmOcl> g;
    try {
        g = std::make_unique<GemmOcl>();
    } catch (const std::exception &e) {
        std::printf("❌ %s\n", e.what());
        return 1;
    }
    std::printf("device : %s\n\n", g->device().c_str());

    int ok = 0, total = 0;
    for (size_t c = 0; c < sizeof CAS / sizeof CAS[0]; c++) {
        const Cas &cas = CAS[c];
        if (filtre && std::strcmp(filtre, cas.groupe) != 0) continue;
        total++;
        std::mt19937 gen(1000 + unsigned(c));
        auto A = remplir(size_t(cas.M) * cas.K, cas.extremes, gen);
        auto B = remplir(size_t(cas.K) * cas.N, cas.extremes, gen);
        std::vector<int32_t> ref(size_t(cas.M) * cas.N);
        gemm_ref(cas.M, cas.N, cas.K, A.data(), B.data(), ref.data());

        std::string nom = std::string(std::strcmp(cas.groupe, "naif") == 0 ? "naïf " : "tuilé") + " · " +
                          std::to_string(cas.M) + " x " + std::to_string(cas.N) + " x " + std::to_string(cas.K);
        std::string erreur;
        try {
            auto C = std::strcmp(cas.groupe, "naif") == 0 ? g->naif(cas.M, cas.N, cas.K, A.data(), B.data())
                                                         : g->tuile(cas.M, cas.N, cas.K, A.data(), B.data());
            erreur = comparer(C, ref, cas.N);
        } catch (const PasEncoreEcrit &e) {
            erreur = std::string("pas encore écrit : ") + e.what();
        } catch (const std::exception &e) {
            erreur = e.what();
        }
        if (erreur.empty()) {
            ok++;
            std::printf("  ✅  %s\n", nom.c_str());
        } else {
            std::printf("  ❌  %s\n       %s\n", nom.c_str(), erreur.c_str());
            if (*cas.pourquoi) std::printf("       (ce cas : %s)\n", cas.pourquoi);
        }
    }
    std::printf("\n%s  %d/%d\n", ok == total ? "✅" : "❌", ok, total);
    return ok == total ? 0 : 1;
}
