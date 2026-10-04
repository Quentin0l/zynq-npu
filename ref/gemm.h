/* ---------------------------------------------------------------------------
 * gemm.h : les GEMM de référence, en C, au bit près.
 *
 * gemm_ref   : la référence dorée, trois boucles naïves. C'est aussi le premier
 *              kernel mesuré sur le Cortex-A9 (S2).
 * gemm_tuile : le même calcul, parcouru selon un schedule (tailles de tuile et
 *              ordre des boucles). C'est ce que voudra dire un schedule de ton
 *              DSL, et ce que ton compilateur produira en nids de boucles.
 *
 * Conventions : matrices rangées par lignes (row-major).
 *   A est M x K : A[i][k] est A[i*K + k]      (int8)
 *   B est K x N : B[k][j] est B[k*N + j]      (int8)
 *   C est M x N : C[i][j] est C[i*N + j]      (int32, écrasée par l'appel)
 * ------------------------------------------------------------------------- */
#ifndef GEMM_H
#define GEMM_H

#include <stdint.h>

void gemm_ref(int M, int N, int K, const int8_t *A, const int8_t *B, int32_t *C);

/* Un schedule : la taille des tuiles, et l'ordre des trois boucles de tuiles.
 * ordre est une permutation de "mnk", de la boucle la plus extérieure à la plus
 * intérieure : "mnk" parcourt les tuiles de C ligne par ligne, et pour chacune
 * toutes les tuiles de K ; "kmn" fait tourner k à l'extérieur. */
typedef struct {
    int  tm, tn, tk;   /* tailles de tuile, >= 1 */
    char ordre[4];     /* "mnk", "nmk", "kmn", ... + '\0' */
} schedule_t;

/* Appelée une fois par tuile, juste avant de la calculer. (m0, n0, k0) est le
 * coin de la tuile, en éléments : m0 est un multiple de tm, n0 de tn, k0 de tk.
 * Les tests s'en servent pour vérifier l'ordre de parcours ; plus tard, ton
 * modèle de coût s'en servira pour compter les octets déplacés. Peut être NULL. */
typedef void (*visite_t)(int m0, int n0, int k0, void *ctx);

void gemm_tuile(int M, int N, int K, const int8_t *A, const int8_t *B, int32_t *C,
                const schedule_t *s, visite_t visite, void *ctx);

#endif
