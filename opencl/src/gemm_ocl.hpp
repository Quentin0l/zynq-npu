// gemm_ocl.hpp : le GEMM int8 -> int32 sur un device OpenCL, vu de l'hôte.
// Fourni par le parcours ; les TODO 1 et 4 sont dans gemm_ocl.cpp.
#pragma once

#include <cstdint>
#include <string>
#include <vector>

#include "ocl.hpp"

class GemmOcl {
public:
    // Choisit le device (variable OCL_DEVICE : gpu ou cpu), puis compile
    // kernels/gemm.cl pour lui, avec des tuiles de taille `tuile`.
    explicit GemmOcl(int tuile = 16);

    const std::string &device() const { return env_.description; }
    int taille_tuile() const { return tuile_; }

    // C (M x N, int32) = A (M x K, int8) x B (K x N, int8), matrices rangées par lignes.
    // Si `ms` n'est pas nul, il reçoit la durée du kernel, en millisecondes (sans les copies).
    std::vector<int32_t> naif(int M, int N, int K, const int8_t *A, const int8_t *B, double *ms = nullptr);
    std::vector<int32_t> tuile(int M, int N, int K, const int8_t *A, const int8_t *B, double *ms = nullptr);

private:
    ocl::Environnement env_;
    ocl::Programme prog_;
    int tuile_;
};

// Levée tant qu'un TODO de l'hôte n'est pas écrit.
struct PasEncoreEcrit : std::logic_error {
    using std::logic_error::logic_error;
};
