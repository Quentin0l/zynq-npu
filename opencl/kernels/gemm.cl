// gemm.cl : le GEMM int8 -> int32 en OpenCL C (leçons 10 et 11 du parcours accélérateurs).
// Squelette fourni par le parcours ; les TODO 2 et 3 sont à écrire.
//
// Conventions, les mêmes que ref/gemm.h : matrices rangées par lignes.
//   A est M x K, int8 (char en OpenCL C, toujours signé) : A[i][k] est A[i*K + k]
//   B est K x N, int8                                     : B[k][j] est B[k*N + j]
//   C est M x N, int32 (int en OpenCL C)                  : C[i][j] est C[i*N + j]
//
// Ce fichier est relu et compilé à chaque exécution, par le pilote OpenCL :
// pas besoin de recompiler l'hôte après l'avoir modifié.


// ---------------------------------------------------------------------------
// Leçon 10. Un work-item par case de C : le work-item (j, i) calcule C[i][j].
//   get_global_id(0) = j, la colonne ; get_global_id(1) = i, la ligne.
// La grille compte exactement N x M work-items : aucun ne tombe hors de C.
// ---------------------------------------------------------------------------
__kernel void gemm_naif(const int M, const int N, const int K,
                        __global const char *A, __global const char *B,
                        __global int *C)
{
    const int j = get_global_id(0);
    const int i = get_global_id(1);

    // TODO 2 : la somme sur k de A[i][k] * B[k][j], accumulée dans un int, puis
    // écrite dans C[i][j]. Tant que ce TODO n'est pas écrit, C vaut 0 partout.
    C[i * N + j] = 0;
}


// ---------------------------------------------------------------------------
// Leçon 11. Un work-group de TILE x TILE work-items calcule une tuile TILE x TILE
// de C. La grille est arrondie au multiple de TILE supérieur : les work-items
// qui tombent hors de C ne doivent ni lire hors de A et B, ni écrire dans C.
// TILE est fixé à la compilation du programme (option -D TILE=16).
// ---------------------------------------------------------------------------
#ifndef TILE
#define TILE 16
#endif

__kernel void gemm_tuile(const int M, const int N, const int K,
                         __global const char *A, __global const char *B,
                         __global int *C)
{
    __local char As[TILE][TILE];   // la tuile de A en cours, partagée par le work-group
    __local char Bs[TILE][TILE];   // la tuile de B en cours

    const int lj = get_local_id(0), li = get_local_id(1);   // position dans le work-group
    const int j = get_global_id(0), i = get_global_id(1);   // position dans C

    int acc = 0;

    // TODO 3 : une boucle sur k0 = 0, TILE, 2*TILE, ... < K. À chaque tour :
    //   a) chaque work-item charge UNE case de chaque tuile :
    //        As[li][lj] = A[i][k0 + lj]   et   Bs[li][lj] = B[k0 + li][j],
    //      ou 0 si la case tombe hors de la matrice ;
    //   b) barrier(CLK_LOCAL_MEM_FENCE) : toute la tuile est chargée ;
    //   c) acc += As[li][t] * Bs[t][lj] pour t = 0 .. TILE-1 ;
    //   d) barrier(CLK_LOCAL_MEM_FENCE) : personne n'écrase la tuile trop tôt.

    if (i < M && j < N)
        C[i * N + j] = acc;
}
