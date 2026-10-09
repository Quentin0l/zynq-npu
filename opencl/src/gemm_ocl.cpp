// gemm_ocl.cpp : l'hôte. Il prépare les données, lance les kernels de
// kernels/gemm.cl, puis relit le résultat. Fourni par le parcours ; les TODO 1
// (leçon 10) et 4 (leçon 11) sont à écrire.
#include "gemm_ocl.hpp"

#include <fstream>
#include <sstream>

namespace {

std::string lire_fichier(const std::string &chemin) {
    std::ifstream f(chemin);
    if (!f) throw std::runtime_error("impossible d'ouvrir " + chemin);
    std::stringstream s;
    s << f.rdbuf();
    return s.str();
}

}  // namespace

GemmOcl::GemmOcl(int tuile)
    : env_(ocl::choisir_device()),
      prog_(ocl::compiler(env_, lire_fichier(KERNELS_DIR "/gemm.cl"), "-D TILE=" + std::to_string(tuile))),
      tuile_(tuile) {}

std::vector<int32_t> GemmOcl::naif(int M, int N, int K, const int8_t *A, const int8_t *B, double *ms) {
    ocl::Noyau k = ocl::noyau(prog_, "gemm_naif");
    ocl::Tampon dA = ocl::tampon(env_, size_t(M) * K, A);      // copiés vers le device
    ocl::Tampon dB = ocl::tampon(env_, size_t(K) * N, B);
    ocl::Tampon dC = ocl::tampon(env_, size_t(M) * N * sizeof(int32_t));

    // TODO 1 : donner au kernel ses six arguments, dans l'ordre de sa signature
    // (M, N, K, puis les tampons dA, dB, dC) avec ocl::argument, puis le lancer
    // avec ocl::lancer sur une grille de N x M work-items : la dimension 0
    // parcourt les colonnes de C, la dimension 1 ses lignes. Range la durée
    // renvoyée dans *ms si ms n'est pas nul.
    throw PasEncoreEcrit("TODO 1, lancer gemm_naif (opencl/src/gemm_ocl.cpp)");

    std::vector<int32_t> C(size_t(M) * N);
    ocl::lire(env_, dC, C.data(), C.size() * sizeof(int32_t));
    return C;
}

std::vector<int32_t> GemmOcl::tuile(int M, int N, int K, const int8_t *A, const int8_t *B, double *ms) {
    ocl::Noyau k = ocl::noyau(prog_, "gemm_tuile");
    ocl::Tampon dA = ocl::tampon(env_, size_t(M) * K, A);
    ocl::Tampon dB = ocl::tampon(env_, size_t(K) * N, B);
    ocl::Tampon dC = ocl::tampon(env_, size_t(M) * N * sizeof(int32_t));

    // TODO 4 (leçon 11) : les mêmes six arguments, puis un lancement avec des
    // work-groups de tuile_ x tuile_ work-items. En OpenCL 1.2, la taille globale
    // doit être un multiple de la taille locale : arrondis N et M au multiple de
    // tuile_ supérieur.
    throw PasEncoreEcrit("TODO 4, lancer gemm_tuile (opencl/src/gemm_ocl.cpp)");

    std::vector<int32_t> C(size_t(M) * N);
    ocl::lire(env_, dC, C.data(), C.size() * sizeof(int32_t));
    return C;
}
