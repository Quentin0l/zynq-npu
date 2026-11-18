// main.c : le DMA à travers la boucle de retour de la coquille (leçon 5).
// Provenance : leçon 5 du parcours « NPU sur ZedBoard » (squelette ; TODO 1 à 4
// à écrire par l'auteur du dépôt).
#include <stdio.h>
#include <string.h>
#include "xparameters.h"   // XPAR_XAXIDMA_0_BASEADDR : le DMA a un pilote, donc une macro
#include "xaxidma.h"       // le pilote du DMA
#include "xil_cache.h"     // Xil_DCacheFlushRange, Xil_DCacheInvalidateRange
#include "xiltimer.h"      // XTime_GetTime, COUNTS_PER_SECOND

#define NB_OCTETS 401408u  // la taille des poids de la couche 1 : un multiple de 32

// Les tampons, en DDR, alignés sur une ligne de cache (32 octets).
static u8 tx[NB_OCTETS] __attribute__((aligned(32)));
static u8 rx[NB_OCTETS] __attribute__((aligned(32)));
static XAxiDma dma;        // l'état du pilote

int main(void)
{
    setvbuf(stdout, NULL, _IONBF, 0);
    printf("\r\n=== DMA a travers la coquille ===\r\n");

    // TODO 1 : initialise le pilote (XAxiDma_LookupConfig, XAxiDma_CfgInitialize),
    //          vérifie qu'il n'est pas en scatter-gather (XAxiDma_HasSg), puis
    //          coupe ses interruptions dans les deux sens (XAxiDma_IntrDisable).
    XAxiDma_Config *cfg = XAxiDma_LookupConfig(XPAR_XAXIDMA_0_BASEADDR);
    
    if (cfg == NULL || XAxiDma_CfgInitialize(&dma, cfg) != XST_SUCCESS) {
        printf("DMA introuvable\r\n");
        return 1;
    }
    if (XAxiDma_HasSg(&dma)) {
        printf("DMA en scatter-gather : ce n'est pas le bon bitstream\r\n");
        return 1;
    }
    // On scrute XAxiDma_Busy : pas d'interruption, dans aucun des deux sens.
    XAxiDma_IntrDisable(&dma, XAXIDMA_IRQ_ALL_MASK, XAXIDMA_DMA_TO_DEVICE);
    XAxiDma_IntrDisable(&dma, XAXIDMA_IRQ_ALL_MASK, XAXIDMA_DEVICE_TO_DMA);

    // TODO 2 : remplis tx avec un motif qui varie (par exemple i * 7 + 3), mets rx
    //          à zéro, puis vide le cache sur les deux tampons.

    u32 *mots = (u32 *)tx;
    for (u32 i = 0; i < NB_OCTETS / 4; i++) mots[i] = i;
    memset(rx, 0, NB_OCTETS);
    Xil_DCacheFlushRange((UINTPTR)tx, NB_OCTETS);
    Xil_DCacheFlushRange((UINTPTR)rx, NB_OCTETS);
    
    // TODO 3 : lance S2MM (rx) PUIS MM2S (tx) avec XAxiDma_SimpleTransfer, et
    //          attends que les deux canaux soient libres (XAxiDma_Busy). Encadre
    //          le tout par deux XTime_GetTime.
    XTime t0, t1;
    XTime_GetTime(&t0);
    // Un transfert refusé laisserait Busy à 0 : on afficherait un débit absurde.
    if (XAxiDma_SimpleTransfer(&dma, (UINTPTR)rx, NB_OCTETS, XAXIDMA_DEVICE_TO_DMA) != XST_SUCCESS) {  // S2MM
        printf("S2MM refuse\r\n");
        return 1;
    }
    if (XAxiDma_SimpleTransfer(&dma, (UINTPTR)tx, NB_OCTETS, XAXIDMA_DMA_TO_DEVICE) != XST_SUCCESS) {  // MM2S
        printf("MM2S refuse\r\n");
        return 1;
    }
    while (XAxiDma_Busy(&dma, XAXIDMA_DMA_TO_DEVICE) || XAxiDma_Busy(&dma, XAXIDMA_DEVICE_TO_DMA)) { }
    XTime_GetTime(&t1);
    // TODO 4 : invalide le cache sur rx, compte les octets différents de tx, pis
    //          affiche la durée en µs et le débit en Mo/s (octets par µs).

    Xil_DCacheInvalidateRange((UINTPTR)rx, NB_OCTETS);
    u32 faux = 0;
    for (u32 i = 0; i < NB_OCTETS; i++) 
        if (rx[i] != tx[i]) faux++;
    const XTime cps = COUNTS_PER_SECOND;
    u64 us = (t1 - t0) * 1000000ull / cps;
    printf("%lu octets en %llu us : %llu Mo/s\r\n", (unsigned long)NB_OCTETS, us, (u64)NB_OCTETS / us);
    printf("Octets faux : %lu\r\n", (unsigned long)faux);

    return 0;
}