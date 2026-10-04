/* ---------------------------------------------------------------------------
 * test_gemm.c : les tests de gemm_tuile (fourni par le parcours, leçon 5).
 *
 * Un cas = des tailles M, N, K et un schedule. Pour chaque cas, on vérifie :
 *   1. les valeurs : C identique à gemm_ref, au bit près ;
 *   2. le parcours : les tuiles visitées, une fois chacune, dans l'ordre du
 *      schedule. Les valeurs seules ne suffisent pas : en entiers, tous les
 *      ordres donnent le même C. C'est tout le propos d'un schedule.
 *
 *   ./test_gemm --nombre     nombre de cas
 *   ./test_gemm <i>          lance le cas i (code 0 si juste)
 *   ./test_gemm --trafic     les octets déplacés selon l'ordre (M = N = K = 64)
 * ------------------------------------------------------------------------- */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "gemm.h"

typedef struct { int M, N, K; schedule_t s; int todo; } cas_t;

static const cas_t CAS[] = {
    /* TODO 1 : tailles multiples des tuiles, ordre "mnk" */
    {  8,   8,   8, { 8,  8,  8, "mnk"}, 1},
    { 16,  16,  16, { 8,  8,  8, "mnk"}, 1},
    { 32,  16,  64, { 8,  8, 16, "mnk"}, 1},
    { 64,  64,  64, { 8,  8,  8, "mnk"}, 1},
    /* TODO 2 : les bords */
    { 10,  13,   7, { 8,  8,  8, "mnk"}, 2},
    {  1,   1,   1, { 8,  8,  8, "mnk"}, 2},
    { 17,   9,  33, { 8,  4, 16, "mnk"}, 2},
    {  5,   3,   2, {16, 16, 16, "mnk"}, 2},
    {  1, 256, 512, { 8,  8, 64, "mnk"}, 2},   /* ta couche 1 du MLP, une entrée : M = 1 */
    /* TODO 3 : l'ordre des boucles de tuiles */
    { 24,  16,  40, { 8,  8,  8, "nmk"}, 3},
    { 24,  16,  40, { 8,  8,  8, "kmn"}, 3},
    { 24,  16,  40, { 8,  8,  8, "knm"}, 3},
    { 19,  23,  29, { 8,  8,  8, "mkn"}, 3},
    { 19,  23,  29, { 8,  4, 16, "nkm"}, 3},
};
#define NB_CAS ((int)(sizeof CAS / sizeof CAS[0]))

/* ------------------------------------------------------------------------- */
/* Les visites                                                               */
/* ------------------------------------------------------------------------- */
typedef struct { int m0, n0, k0; } tuile_t;
typedef struct { tuile_t *t; int nb, cap; } trace_t;

static void enregistrer(int m0, int n0, int k0, void *ctx) {
    trace_t *tr = ctx;
    if (tr->nb < tr->cap)
        tr->t[tr->nb] = (tuile_t){m0, n0, k0};
    tr->nb++;
}

static int plafond(int a, int b) { return (a + b - 1) / b; }

/* Le parcours attendu : ordre[0] est la boucle extérieure, ordre[2] l'intérieure,
 * et chaque boucle va de la tuile 0 à la dernière. */
static int parcours_attendu(const cas_t *c, tuile_t *out) {
    const schedule_t *s = &c->s;
    int nb[3], taille[3];
    for (int p = 0; p < 3; p++) {
        char d = s->ordre[p];
        nb[p]     = d == 'm' ? plafond(c->M, s->tm) : d == 'n' ? plafond(c->N, s->tn) : plafond(c->K, s->tk);
        taille[p] = d == 'm' ? s->tm : d == 'n' ? s->tn : s->tk;
    }
    int n = 0;
    for (int i0 = 0; i0 < nb[0]; i0++)
        for (int i1 = 0; i1 < nb[1]; i1++)
            for (int i2 = 0; i2 < nb[2]; i2++) {
                int idx[3] = {i0, i1, i2}, coin[3] = {0, 0, 0};   /* coin[0] = m0, [1] = n0, [2] = k0 */
                for (int p = 0; p < 3; p++) {
                    int d = s->ordre[p] == 'm' ? 0 : s->ordre[p] == 'n' ? 1 : 2;
                    coin[d] = idx[p] * taille[p];
                }
                out[n++] = (tuile_t){coin[0], coin[1], coin[2]};
            }
    return n;
}

/* ------------------------------------------------------------------------- */
/* Un cas                                                                    */
/* ------------------------------------------------------------------------- */
static void decrire(const cas_t *c) {
    printf("TODO %d · %d x %d x %d, tuiles %d x %d x %d, ordre %s",
           c->todo, c->M, c->N, c->K, c->s.tm, c->s.tn, c->s.tk, c->s.ordre);
}

static int8_t *aleatoire(int n) {
    int8_t *v = malloc((size_t)n);   /* taille exacte : AddressSanitizer voit tout débordement */
    for (int i = 0; i < n; i++)
        v[i] = (int8_t)(rand() % 256 - 128);
    return v;
}

static int lancer_cas(int i) {
    const cas_t *c = &CAS[i];
    decrire(c);
    fflush(stdout);
    srand(1000 + i);
    int M = c->M, N = c->N, K = c->K;
    int8_t *A = aleatoire(M * K), *B = aleatoire(K * N);
    int32_t *Cref = malloc(sizeof(int32_t) * M * N), *C = malloc(sizeof(int32_t) * M * N);
    int nb_attendu = plafond(M, c->s.tm) * plafond(N, c->s.tn) * plafond(K, c->s.tk);
    tuile_t *attendu = malloc(sizeof(tuile_t) * nb_attendu);
    parcours_attendu(c, attendu);
    trace_t tr = { malloc(sizeof(tuile_t) * (nb_attendu + 1)), 0, nb_attendu + 1 };

    gemm_ref(M, N, K, A, B, Cref);
    for (int j = 0; j < M * N; j++)
        C[j] = 0x5A5A5A5A;            /* des déchets : gemm_tuile doit tout écraser */
    gemm_tuile(M, N, K, A, B, C, &c->s, enregistrer, &tr);

    int faux = 0, premier = -1;
    for (int j = 0; j < M * N; j++)
        if (C[j] != Cref[j]) { faux++; if (premier < 0) premier = j; }
    if (faux) {
        printf("\n       C[%d][%d] = %d, attendu %d (%d case(s) fausse(s) sur %d)\n",
               premier / N, premier % N, C[premier], Cref[premier], faux, M * N);
        return 1;
    }
    if (tr.nb != nb_attendu) {
        printf("\n       valeurs justes, mais visite() appelée %d fois au lieu de %d (une fois par tuile)\n",
               tr.nb, nb_attendu);
        return 1;
    }
    for (int j = 0; j < nb_attendu; j++) {
        tuile_t v = tr.t[j], a = attendu[j];
        if (v.m0 != a.m0 || v.n0 != a.n0 || v.k0 != a.k0) {
            printf("\n       valeurs justes, mais la visite n°%d est la tuile (m0, n0, k0) = (%d, %d, %d), "
                   "attendu (%d, %d, %d) : ordre « %s », la boucle extérieure parcourt %c\n",
                   j, v.m0, v.n0, v.k0, a.m0, a.n0, a.k0, c->s.ordre, c->s.ordre[0]);
            return 1;
        }
    }
    printf("\n");
    return 0;
}

/* ------------------------------------------------------------------------- */
/* Le trafic : ce que l'ordre change                                         */
/* ------------------------------------------------------------------------- */
/* Modèle volontairement simple : sur puce, une seule tuile de A, une seule de B,
 * et la tuile de C en cours, qui reste dans les accumulateurs du tableau. Une
 * tuile de A ou de B se charge quand elle change. Quand la tuile de C change,
 * l'ancienne sort (int32) ; si la nouvelle a déjà été commencée, ses sommes
 * partielles doivent revenir. */
typedef struct {
    int tm, tn, tk, nt_n;
    int am, ak, bk, bn, cm, cn;      /* les tuiles présentes sur puce (-1 : aucune) */
    long a, b, c_sortie, c_retour;
    char *commencee;
} trafic_t;

static void compter(int m0, int n0, int k0, void *ctx) {
    trafic_t *t = ctx;
    if (m0 != t->am || k0 != t->ak) { t->a += (long)t->tm * t->tk; t->am = m0; t->ak = k0; }
    if (k0 != t->bk || n0 != t->bn) { t->b += (long)t->tk * t->tn; t->bk = k0; t->bn = n0; }
    if (m0 != t->cm || n0 != t->cn) {
        if (t->cm >= 0) t->c_sortie += 4L * t->tm * t->tn;
        char *deja = &t->commencee[(m0 / t->tm) * t->nt_n + n0 / t->tn];
        if (*deja) t->c_retour += 4L * t->tm * t->tn;
        *deja = 1;
        t->cm = m0; t->cn = n0;
    }
}

static void trafic(void) {
    const char *ordres[] = {"mnk", "nmk", "mkn", "nkm", "kmn", "knm"};
    int M = 64, N = 64, K = 64;
    int8_t *A = aleatoire(M * K), *B = aleatoire(K * N);
    int32_t *C = malloc(sizeof(int32_t) * M * N);
    printf("\nCe que l'ordre change, d'après TES visites : M = N = K = 64, tuiles 8 x 8 x 8,\n");
    printf("une tuile de A, une de B et la tuile de C en cours sur puce. Octets déplacés :\n\n");
    printf("  ordre      A        B     C sortie   C retour (sommes partielles)\n");
    for (int o = 0; o < 6; o++) {
        schedule_t s = {8, 8, 8, ""};
        strcpy(s.ordre, ordres[o]);
        trafic_t t = {8, 8, 8, N / 8, -1, -1, -1, -1, -1, -1, 0, 0, 0, 0, calloc(64, 1)};
        gemm_tuile(M, N, K, A, B, C, &s, compter, &t);
        if (t.cm >= 0) t.c_sortie += 4L * t.tm * t.tn;   /* la dernière tuile de C sort */
        printf("  %s   %7ld  %7ld  %9ld  %9ld\n", ordres[o], t.a, t.b, t.c_sortie, t.c_retour);
        free(t.commencee);
    }
    printf("\nUn tableau output-stationary ne sait pas recharger une somme partielle :\n");
    printf("un ordre qui en demande est-il permis sur TON NPU ? C'est une question pour ton contrat.\n");
}

int main(int argc, char **argv) {
    if (argc == 2 && strcmp(argv[1], "--nombre") == 0) { printf("%d\n", NB_CAS); return 0; }
    if (argc == 2 && strcmp(argv[1], "--trafic") == 0) { trafic(); return 0; }
    if (argc == 2) {
        int i = atoi(argv[1]);
        if (i >= 0 && i < NB_CAS) return lancer_cas(i);
    }
    fprintf(stderr, "usage : %s --nombre | <cas> | --trafic\n", argv[0]);
    return 2;
}
