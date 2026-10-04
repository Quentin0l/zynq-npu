/* ---------------------------------------------------------------------------
 * gemm.c : leçon 5 du parcours compilateurs, « séparer l'algorithme du schedule ».
 * Squelette fourni par le parcours : gemm_ref est résolu, gemm_tuile est à toi
 * (TODO 1 à 3).
 *
 * Vérifier ton travail :   ./check.sh
 * ------------------------------------------------------------------------- */
#include <string.h>

#include "gemm.h"

/* L'ALGORITHME : ce que vaut C. Aucune décision d'ordre, de tuile ou de mémoire. */
void gemm_ref(int M, int N, int K, const int8_t *A, const int8_t *B, int32_t *C) {
    for (int i = 0; i < M; i++)
        for (int j = 0; j < N; j++) {
            int32_t acc = 0;
            for (int k = 0; k < K; k++)
                acc += (int32_t)A[i*K + k] * (int32_t)B[k*N + j];
            C[i*N + j] = acc;
        }
}

/* LE SCHEDULE : le même C, calculé tuile par tuile, dans l'ordre que dit s.
 *
 * Structure attendue : C mis à zéro, puis trois boucles de TUILES (une par
 * dimension, dans l'ordre de s->ordre), et dans chaque tuile trois boucles
 * d'ÉLÉMENTS qui ajoutent les produits de la tuile à C. Chaque tuile est
 * visitée une fois : appelle visite(m0, n0, k0, ctx) juste avant de la
 * calculer (si visite n'est pas NULL).
 *
 * TODO 1 — ordre "mnk" seulement, et des tailles multiples des tuiles
 *          (M % tm == 0, N % tn == 0, K % tk == 0). Six boucles en tout.
 * TODO 2 — les bords : M, N ou K quelconques. La dernière tuile de chaque
 *          dimension est plus petite. Ne lis jamais hors des matrices :
 *          check.sh compile avec AddressSanitizer, qui le voit.
 * TODO 3 — n'importe quel ordre de s->ordre. Indice : trois compteurs de
 *          tuiles, et pour chaque position p de la chaîne ordre, la dimension
 *          qu'elle désigne ('m', 'n' ou 'k').
 */
void gemm_tuile(int M, int N, int K, const int8_t *A, const int8_t *B, int32_t *C,
                const schedule_t *s, visite_t visite, void *ctx) {
    memset(C, 0, (size_t)M * N * sizeof *C);

    /* TODO 1, puis 2, puis 3. Tant que rien n'est écrit, C reste à zéro. */
    (void)A; (void)B; (void)K; (void)s; (void)visite; (void)ctx;
}
